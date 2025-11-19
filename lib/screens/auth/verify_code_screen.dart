import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart'; // Paquete OTP
import 'package:fitracker_app/api/api_service.dart';
import 'package:fitracker_app/data/auth_storage_service.dart';
import 'package:fitracker_app/config/app_colors.dart';
import 'package:fitracker_app/screens/main_screen.dart'; 
import 'dart:async'; // Necesario para el temporizador de reenvío

class VerifyCodeScreen extends StatefulWidget {
  final String email;
  
  const VerifyCodeScreen({super.key, required this.email});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final ApiService _apiService = ApiService();
  final AuthStorageService _storageService = AuthStorageService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  String _currentCode = '';
  bool _isLoading = false;
  
  // Lógica del Temporizador para Reenvío
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  // --- Manejo de Acciones ---

  void _handleVerify() async {
    if (_formKey.currentState!.validate() && _currentCode.length == 6) {
      setState(() { _isLoading = true; });

      try {
        final tokenData = await _apiService.verifyCode(
          email: widget.email,
          code: _currentCode,
        );
        
        // CRÍTICO: Guardar los nuevos tokens después de verificar
        await _storageService.saveTokens(tokenData);
        
        if (!mounted) return;
        
        // ÉXITO: Usuario verificado. Guardar nuevos tokens y navegar.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta verificada exitosamente!'), backgroundColor: AppColors.primaryAction),
        );
        
        // Navegar a MainScreen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (Route<dynamic> route) => false,
        );

      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}'), backgroundColor: AppColors.alertError),
        );
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }
  
  void _handleResendCode() async {
    if (_secondsRemaining > 0) return;
    
    setState(() { _secondsRemaining = 60; _isLoading = true; });

    try {
      await _apiService.sendVerificationCode(email: widget.email);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuevo código enviado. Revisa tu buzón.')),
      );
      _startTimer(); // Reiniciar el temporizador

    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al reenviar: ${e.message}'), backgroundColor: AppColors.alertError),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Icono y Descripción ---
                      Icon(Icons.email, size: 60, color: Theme.of(context).primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Ingresa el código de 6 dígitos',
                        style: Theme.of(context).textTheme.displayLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enviamos un código a ${widget.email}. Revisa tu carpeta de spam.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),

                      // --- 1. OTP Input Field ---
                      _buildOtpInput(context),
                      const SizedBox(height: 32),

                      // --- 2. Botón Verificar ---
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerify,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Verificar Cuenta'),
                      ),
                      const SizedBox(height: 16),

                      // --- 3. Enlace para Reenviar Código ---
                      _buildResendLink(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildOtpInput(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: PinCodeTextField(
        appContext: context,
        length: 6, // 6 dígitos
        animationType: AnimationType.fade,
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(5),
          fieldHeight: 50,
          fieldWidth: 40,
          activeFillColor: Colors.transparent,
          inactiveFillColor: AppColors.neutralSecondary.withOpacity(0.5),
          selectedFillColor: Colors.transparent,
          activeColor: Theme.of(context).primaryColor,
          inactiveColor: AppColors.neutralSecondary,
          selectedColor: Theme.of(context).primaryColor.withOpacity(0.5),
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          setState(() {
            _currentCode = value;
          });
        },
        validator: (value) {
          if (value == null || value.length < 6) {
            return ""; // Solo para forzar el borde rojo si no está completo
          }
          return null;
        },
      ),
    );
  }

  Widget _buildResendLink(BuildContext context) {
    final bool canResend = _secondsRemaining == 0;
    
    return Column(
      children: [
        if (!canResend)
          Text(
            'Puedes reenviar el código en $_secondsRemaining segundos.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
        TextButton(
          onPressed: canResend ? _handleResendCode : null,
          child: Text(
            'Reenviar Código',
            style: TextStyle(
              color: canResend ? Theme.of(context).primaryColor : Theme.of(context).iconTheme.color?.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }
}