import 'package:flutter/material.dart';
import 'package:fitracker_app/config/app_colors.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:fitracker_app/api/api_service.dart';
import 'package:fitracker_app/data/auth_storage_service.dart';
import 'package:fitracker_app/screens/main_screen.dart';
import 'package:fitracker_app/screens/auth/verify_code_screen.dart'; // Para la navegación exitosa


// Definición de las funciones de navegación (simulando los props de React)
typedef AuthCallback = void Function();
typedef LoginCallback = void Function(BuildContext context, String email, String password);

class LoginScreen extends StatefulWidget {
  final AuthCallback onRegister;
  final AuthCallback onForgotPassword;
  final LoginCallback onLogin; // Función para manejar el login

  const LoginScreen({
    super.key,
    required this.onRegister,
    required this.onForgotPassword,
    required this.onLogin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  final AuthStorageService _storageService = AuthStorageService();
  bool _isLoading = false;
  // Manejo de estado: equivalente a useState en React
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final tokenData = await _apiService.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        
        await _storageService.saveTokens(tokenData);

        // ----------------------------------------------------
        // LÓGICA CLAVE: VERIFICACIÓN CONDICIONAL
        // ----------------------------------------------------
        if (!tokenData.isVerified) {
          // 1. SI NO ESTÁ VERIFICADO: Redirigir a la pantalla de verificación
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login exitoso. Por favor, verifica tu cuenta.')),
          );
          
          // Navegar a VerifyCodeScreen (usando el email ingresado)
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => VerifyCodeScreen(email: _emailController.text),
            ),
            (Route<dynamic> route) => false,
          );
          
        } else {
          // 2. SI SÍ ESTÁ VERIFICADO: Redirigir a MainScreen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Bienvenido!')),
          );
          
          // Navegar a MainScreen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainScreen()),
            (Route<dynamic> route) => false,
          );
        }

      } on ApiException catch (e) {
        // --- FALLO: Mostrar error al usuario ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: AppColors.alertError,
          ),
        );
      } catch (e) {
        // --- FALLO: Error inesperado ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: ${e.toString()}'),
            backgroundColor: AppColors.alertError,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold proporciona la estructura básica (similar a min-h-screen flex...)
    return Scaffold(
      body: Center(
        // Padding es el p-4 de Tailwind
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          // El ConstrainedBox limita el ancho, similar a max-w-md
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              // Usamos el color de fondo definido en el tema
              elevation: 4, 
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  // Columna para organizar los elementos verticalmente (similar a space-y-4)
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- CardHeader (Título y Descripción) ---
                      _buildHeader(context),
                      const SizedBox(height: 20),

                      // --- Input de Correo Electrónico ---
                      _buildEmailField(),
                      const SizedBox(height: 16),

                      // --- Input de Contraseña ---
                      _buildPasswordField(),
                      const SizedBox(height: 24),

                      // --- Botón de Iniciar Sesión ---
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin, // Deshabilita si está cargando
                        child: _isLoading 
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ) 
                            : const Text('Iniciar Sesión'),
                      ),
                      const SizedBox(height: 16),

                      // --- Enlaces de Navegación ---
                      _buildFooterLinks(context),
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

  // --- Helper Widgets para mantener el código limpio ---

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Ícono Activity (usamos Icons.directions_run o similar)
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor, // Verde Turquesa
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.directions_run, // Ícono similar a Activity
            size: 32,
            color: Theme.of(context).colorScheme.onPrimary, // Letra blanca
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'FitTracker AI',
          // Usa el estilo de título grande definido globalmente
          style: Theme.of(context).textTheme.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Monitorea tus rutinas con inteligencia artificial',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey, // text-muted-foreground
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: Text('Correo electrónico'),
        ),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'tu@email.com',
            // Usa el estilo de borde de input global
          ),
          validator: (value) {
            if (value == null || value.isEmpty || !value.contains('@')) {
              return 'Ingresa un correo válido.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: Text('Contraseña'),
        ),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: '••••••••',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La contraseña es obligatoria.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFooterLinks(BuildContext context) {
    return Column(
      children: [
        // ¿Olvidaste tu contraseña? (Enlace/Botón "Link")
        TextButton(
          onPressed: widget.onForgotPassword,
          child: const Text('¿Olvidaste tu contraseña?'),
        ),
        
        // ¿No tienes cuenta? Regístrate
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '¿No tienes cuenta? ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // Botón de Registrarse (simulando variant="link")
            GestureDetector(
              onTap: widget.onRegister,
              child: Text(
                'Regístrate',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryAction, // Usa el color de acción
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}