package com.example.fitracker_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

class MediaPipePosePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var poseLandmarker: PoseLandmarker? = null
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    
    companion object {
        private const val TAG = "MediaPipePosePlugin"
        private const val CHANNEL_NAME = "mediapipe_pose_channel"
        // 🔥 MODELO FULL - Balance perfecto entre precisión y velocidad
        private const val MODEL_URL = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task"
        private const val MODEL_FILE_NAME = "pose_landmarker_full.task"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        Log.d(TAG, "Plugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        poseLandmarker?.close()
        scope.cancel()
        Log.d(TAG, "Plugin detached from engine")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val minDetectionConfidence = call.argument<Double>("minDetectionConfidence") ?: 0.5
                val minTrackingConfidence = call.argument<Double>("minTrackingConfidence") ?: 0.5
                initializePoseLandmarker(minDetectionConfidence.toFloat(), minTrackingConfidence.toFloat(), result)
            }
            "processImage" -> {
                val imageData = call.argument<ByteArray>("imageData")
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")
                val rotation = call.argument<Int>("rotation") ?: 0
                
                if (imageData == null || width == null || height == null) {
                    result.error("INVALID_ARGS", "Missing image data, width, or height", null)
                    return
                }
                
                processImage(imageData, width, height, rotation, result)
            }
            "dispose" -> {
                dispose(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializePoseLandmarker(
        minDetectionConfidence: Float,
        minTrackingConfidence: Float,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                // Descargar o verificar modelo
                val modelFile = getModelFile()
                
                if (!modelFile.exists()) {
                    Log.d(TAG, "Downloading model from $MODEL_URL")
                    downloadModel(modelFile)
                }
                
                Log.d(TAG, "Model file exists: ${modelFile.absolutePath}")
                
                // Configurar opciones
                val baseOptions = BaseOptions.builder()
                    .setModelAssetPath(modelFile.absolutePath)
                    .build()
                
                val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setRunningMode(RunningMode.IMAGE)
                    .setMinPoseDetectionConfidence(minDetectionConfidence)
                    .setMinTrackingConfidence(minTrackingConfidence)
                    .setNumPoses(1)  // Solo detectar 1 persona
                    .build()
                
                // Crear PoseLandmarker
                poseLandmarker = PoseLandmarker.createFromOptions(context, options)
                
                withContext(Dispatchers.Main) {
                    result.success(true)
                    Log.d(TAG, "PoseLandmarker initialized successfully")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing PoseLandmarker", e)
                withContext(Dispatchers.Main) {
                    result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
                }
            }
        }
    }

    private fun getModelFile(): File {
        return File(context.filesDir, MODEL_FILE_NAME)
    }

    private suspend fun downloadModel(destFile: File) = withContext(Dispatchers.IO) {
        try {
            val url = URL(MODEL_URL)
            val connection = url.openConnection() as HttpURLConnection
            connection.connect()
            
            connection.inputStream.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }
            Log.d(TAG, "Model downloaded successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error downloading model", e)
            throw e
        }
    }

    private fun processImage(
        imageData: ByteArray,
        width: Int,
        height: Int,
        rotation: Int,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                if (poseLandmarker == null) {
                    withContext(Dispatchers.Main) {
                        result.error("NOT_INITIALIZED", "PoseLandmarker not initialized", null)
                    }
                    return@launch
                }
                
                // Convertir YUV420 a Bitmap
                val bitmap = yuv420ToBitmap(imageData, width, height)
                
                // Convertir a MPImage
                val mpImage = BitmapImageBuilder(bitmap).build()
                
                // Detectar pose
                val detectionResult = poseLandmarker!!.detect(mpImage)
                
                // Convertir resultado a Map
                val resultMap = convertResultToMap(detectionResult, width, height)
                
                withContext(Dispatchers.Main) {
                    result.success(resultMap)
                }
                
                bitmap.recycle()
            } catch (e: Exception) {
                Log.e(TAG, "Error processing image", e)
                withContext(Dispatchers.Main) {
                    result.error("PROCESS_ERROR", "Failed to process: ${e.message}", null)
                }
            }
        }
    }

    private fun yuv420ToBitmap(data: ByteArray, width: Int, height: Int): Bitmap {
        val yuvImage = YuvImage(data, ImageFormat.NV21, width, height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 100, out)
        val imageBytes = out.toByteArray()
        return BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
    }

    private fun convertResultToMap(
        result: PoseLandmarkerResult,
        imageWidth: Int,
        imageHeight: Int
    ): Map<String, Any> {
        val poses = mutableListOf<Map<String, Any>>()
        
        result.landmarks().forEachIndexed { poseIndex, landmarks ->
            val landmarksMap = mutableMapOf<String, Map<String, Any>>()
            
            landmarks.forEachIndexed { index, landmark ->
                // MediaPipe usa visibility() y presence() para confianza
                val visibility = landmark.visibility().orElse(1.0f)
                
                landmarksMap[index.toString()] = mapOf(
                    "x" to landmark.x() * imageWidth,
                    "y" to landmark.y() * imageHeight,
                    "z" to landmark.z(),
                    "likelihood" to visibility.toDouble()
                )
            }
            
            poses.add(mapOf("landmarks" to landmarksMap))
        }
        
        return mapOf("poses" to poses)
    }

    private fun dispose(result: MethodChannel.Result) {
        poseLandmarker?.close()
        poseLandmarker = null
        result.success(true)
        Log.d(TAG, "PoseLandmarker disposed")
    }
}
