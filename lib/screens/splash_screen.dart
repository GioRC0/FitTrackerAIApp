import 'package:flutter/material.dart';
import 'package:fitracker_app/services/auth_service.dart';
import 'package:fitracker_app/screens/auth/login_screen.dart';
import 'package:fitracker_app/screens/auth/register_screen.dart';
import 'package:fitracker_app/screens/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Pequeño delay para mostrar splash
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final sessionStatus = await _authService.checkSession();

    if (!mounted) return;

    switch (sessionStatus) {
      case SessionStatus.valid:
        // Usuario autenticado y verificado -> Main Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
        break;

      case SessionStatus.notVerified:
        // Usuario registrado pero no verificado -> Login con mensaje
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (newContext) => LoginScreen(
              onLogin: (context, email, password) {},
              onRegister: () {
                Navigator.of(newContext).push(
                  MaterialPageRoute(
                    builder: (registerContext) => RegisterScreen(
                      onBack: () {
                        if (Navigator.of(registerContext).canPop()) {
                          Navigator.of(registerContext).pop();
                        }
                      },
                    ),
                  ),
                );
              },
              onForgotPassword: () {
                ScaffoldMessenger.of(newContext).showSnackBar(
                  const SnackBar(content: Text('Funcionalidad de Olvidé Contraseña pendiente')),
                );
              },
            ),
          ),
        );
        break;

      case SessionStatus.expired:
      case SessionStatus.noSession:
        // No hay sesión o expiró -> Login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (newContext) => LoginScreen(
              onLogin: (context, email, password) {},
              onRegister: () {
                Navigator.of(newContext).push(
                  MaterialPageRoute(
                    builder: (registerContext) => RegisterScreen(
                      onBack: () {
                        if (Navigator.of(registerContext).canPop()) {
                          Navigator.of(registerContext).pop();
                        }
                      },
                    ),
                  ),
                );
              },
              onForgotPassword: () {
                ScaffoldMessenger.of(newContext).showSnackBar(
                  const SnackBar(content: Text('Funcionalidad de Olvidé Contraseña pendiente')),
                );
              },
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo o icono de la app
            Icon(
              Icons.fitness_center,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            // Nombre de la app
            const Text(
              'FitTracker',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
