import 'package:flutter/material.dart';
import 'config/app_colors.dart';
//import 'screens/main_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTracker Tesis',
      
      // Tema CLARO (Modo por defecto)
      theme: _lightTheme, 
      
      // Tema OSCURO
      darkTheme: _darkTheme, 
      
      // La aplicación inicia en modo CLARO por defecto (tal como lo especificaste)
      themeMode: ThemeMode.light, 
      
      home: Builder(
        builder: (BuildContext navigatorContext) {
          return LoginScreen(
            onLogin: (context, email, password) {
              // La lógica de login ahora está dentro de LoginScreen.
              // Esta función de onLogin ya no se usa aquí.
              // Dejar el onLogin con un cuerpo vacío o modificar la estructura. 
              // Por simplicidad, por ahora, usaremos push para simular la navegación.
            },
            onRegister: () {
              Navigator.of(navigatorContext).push(
                MaterialPageRoute(
                  builder: (context) => RegisterScreen(
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
        onForgotPassword: () {
          // TODO: Mostrar diálogo o navegar a la pantalla de Olvidé Contraseña
          ScaffoldMessenger.of(navigatorContext).showSnackBar(
            const SnackBar(content: Text('Funcionalidad de Olvidé Contraseña pendiente')),
          );
        },
      );
      })  // Reemplaza con tu widget inicial
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