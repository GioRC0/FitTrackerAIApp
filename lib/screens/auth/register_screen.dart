import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para Numeric Input
import 'package:fitracker_app/api/api_service.dart';
import 'package:fitracker_app/data/auth_storage_service.dart';
import 'package:fitracker_app/models/user_dtos.dart';
import 'package:fitracker_app/config/app_colors.dart';
import 'package:fitracker_app/screens/auth/verify_code_screen.dart'; // Para la navegación exitosa

typedef AuthCallback = void Function();

class RegisterScreen extends StatefulWidget {
  final AuthCallback onBack;
  
  const RegisterScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final AuthStorageService _storageService = AuthStorageService();
  bool _isLoading = false;

  // Controladores de Texto
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  // --- Lógica de Envío ---
  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      // 1. Validar coincidencia de contraseñas (lógica custom)
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las contraseñas no coinciden.'), backgroundColor: AppColors.alertError),
        );
        return;
      }
      
      setState(() { _isLoading = true; });

      try {
        final dto = RegisterDto(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          email: _emailController.text,
          phoneNumber: _phoneController.text,
          password: _passwordController.text,
          // Convertir texto a double para el DTO
          weight: double.parse(_weightController.text),
          height: double.parse(_heightController.text),
        );

        final tokenData = await _apiService.register(registerDto: dto);

        // CRÍTICO: Guardar los tokens después del registro
        await _storageService.saveTokens(tokenData);

        // --- ÉXITO: Registro Exitoso y Envío de Email ---
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Registro exitoso! Se envió un código a ${dto.email}.'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
        
        // Navegación (Temporal: va a MainScreen. Real: Ir a VerifyCodeScreen)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VerifyCodeScreen(email: dto.email),
          ),
        );

      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}'), backgroundColor: AppColors.alertError),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado: ${e.toString()}'), backgroundColor: AppColors.alertError),
        );
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Al igual que Login, usa Scaffold y Center para la Card
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
                      // --- CardHeader con botón de regreso ---
                      _buildHeader(context),
                      const SizedBox(height: 20),

                      // --- FORMULARIO (Espaciado similar a space-y-4) ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Nombre y Apellido (grid grid-cols-2 gap-2)
                          Row(
                            children: [
                              Expanded(child: _buildInputField('firstName', 'Nombre', 'Juan', _firstNameController)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildInputField('lastName', 'Apellido', 'Pérez', _lastNameController)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 2. Correo y Teléfono
                          _buildInputField('email', 'Correo electrónico', 'tu@email.com', _emailController, TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _buildInputField('phone', 'Número telefónico', '+1234567890', _phoneController, TextInputType.phone),
                          const SizedBox(height: 16),

                          // 3. Contraseñas
                          _buildPasswordField('password', 'Contraseña', _passwordController),
                          const SizedBox(height: 16),
                          _buildPasswordField('confirmPassword', 'Confirmar contraseña', _confirmPasswordController),
                          const SizedBox(height: 16),

                          // 4. Peso y Altura (grid grid-cols-2 gap-2)
                          Row(
                            children: [
                              Expanded(child: _buildNumericField('weight', 'Peso (kg)', '70.5', _weightController)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildNumericField('height', 'Altura (cm)', '175.5', _heightController)),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                      

                      // --- Botón Crear Cuenta ---
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Crear Cuenta'),
                      ),
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

  // --- Helper Widgets ---

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Botón de regreso (ArrowLeft)
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
            // variant="ghost" size="icon"
            splashRadius: 24, 
          ),
        ),
        
        // Contenido centrado
        Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0), // p-2
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_run, // Ícono similar a Activity
                  size: 24, // h-6 w-6
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crear Cuenta',
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Completa tus datos para comenzar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String id, String label, String hint, TextEditingController controller, [TextInputType keyboardType = TextInputType.text]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(label),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El campo $label es obligatorio.';
            }
            if (id == 'email' && !value.contains('@')) {
              return 'Ingresa un correo válido.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField(String id, String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(label),
        ),
        TextFormField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '••••••••',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La contraseña es obligatoria.';
            }
            if (id == 'confirmPassword' && value != _passwordController.text) {
              return 'Las contraseñas no coinciden.';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNumericField(String id, String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(label),
        ),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
          ),
          inputFormatters: [
            // Permite solo números y opcionalmente un punto/coma
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'El campo $label es obligatorio.';
            }
            // Asegura que sea un número válido
            if (double.tryParse(value) == null) {
              return 'Debe ser un valor numérico.';
            }
            return null;
          },
        ),
      ],
    );
  }
}