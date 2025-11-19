import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_colors.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_screen.dart';
import 'services/theme_service.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'FitTracker Tesis',
          
          // Tema CLARO (Modo por defecto)
          theme: _lightTheme, 
          
          // Tema OSCURO
          darkTheme: _darkTheme, 
          
          // Tema dinámico controlado por ThemeService
          themeMode: themeService.themeMode, 
          
          // Inicia con SplashScreen que verificará la sesión
          home: const SplashScreen(),

          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// --------------------------------------------------------------------------
// DEFINICIÓN DE TEMAS GLOBALES
// --------------------------------------------------------------------------

final ThemeData _lightTheme = ThemeData(
  // 1. PALETA DE COLORES
  brightness: Brightness.light,
  // Color Primario para botones y resaltados (Verde Turquesa)
  primaryColor: AppColors.primaryAction, 
  scaffoldBackgroundColor: AppColors.lightBackground, // Fondo de la pantalla

  // 2. TIPOGRAFÍA (Roboto es sans-serif y está disponible por defecto)
  fontFamily: 'Roboto', 
  textTheme: const TextTheme(
    // Títulos (mínimo 20-22 px) alineados a la izquierda
    displayLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: AppColors.lightText),
    // Cuerpo de texto (mínimo 16 px)
    bodyMedium: TextStyle(fontSize: 16.0, color: AppColors.lightText), 
  ),

  // 3. ESTILOS DE BOTÓN (Mismo color, forma)
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryAction, // Color de acción
      foregroundColor: AppColors.darkText, // Texto blanco en el botón
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      minimumSize: const Size(double.infinity, 50), // Ancho completo para coherencia
    ),
  ),
  
  // 4. Input Fields (para las vistas de Login/Registro)
  inputDecorationTheme: const InputDecorationTheme(
    labelStyle: TextStyle(color: AppColors.lightText),
    hintStyle: TextStyle(color: Colors.grey),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.neutralSecondary),
    ),
  ),
  
  // 5. Color de los íconos (lineal negro)
  iconTheme: const IconThemeData(color: AppColors.lightText, size: 24.0),
);


final ThemeData _darkTheme = ThemeData(
  // 1. PALETA DE COLORES
  brightness: Brightness.dark,
  primaryColor: AppColors.primaryAction,
  scaffoldBackgroundColor: AppColors.darkBackground, // Fondo gris oscuro

  // 2. TIPOGRAFÍA
  fontFamily: 'Roboto',
  textTheme: TextTheme(
    // Títulos (letras blancas)
    displayLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: AppColors.darkText),
    // Cuerpo de texto (letras blancas)
    bodyMedium: TextStyle(fontSize: 16.0, color: AppColors.darkText),
  ),

  // 3. ESTILOS DE BOTÓN (Mantiene el mismo color de acción)
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryAction, 
      foregroundColor: AppColors.darkText,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      minimumSize: const Size(double.infinity, 50),
    ),
  ),
  
  // 4. Input Fields (para las vistas de Login/Registro)
  inputDecorationTheme: InputDecorationTheme(
    labelStyle: const TextStyle(color: AppColors.darkText),
    hintStyle: const TextStyle(color: Colors.white70),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.neutralSecondary),
    ),
  ),
  
  // 5. Color de los íconos (lineal blanco)
  iconTheme: const IconThemeData(color: AppColors.darkText, size: 24.0),
);