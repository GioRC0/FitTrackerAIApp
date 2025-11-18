import 'package:flutter/material.dart';
import 'package:fitracker_app/models/user_profile.dart';
import 'package:fitracker_app/services/user_profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserProfileService _profileService = UserProfileService();

  late TextEditingController _nameController;
  late TextEditingController _lastNameController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _lastNameController = TextEditingController(text: widget.profile.lastName);
    _weightController = TextEditingController(text: widget.profile.weight.toStringAsFixed(1));
    _heightController = TextEditingController(text: widget.profile.height.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = UpdateProfileRequest(
        name: _nameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        weight: double.parse(_weightController.text.trim()),
        height: int.parse(_heightController.text.trim()),
      );

      final updatedProfile = await _profileService.updateUserProfile(request);

      if (mounted) {
        if (updatedProfile != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Perfil actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, updatedProfile);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al actualizar el perfil'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  child: Text(
                    widget.profile.initials,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Nombre
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Apellido
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Apellido',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El apellido es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email (no editable)
              TextFormField(
                initialValue: widget.profile.email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                  enabled: false,
                ),
              ),
              const SizedBox(height: 16),

              // Peso
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                  suffixText: 'kg',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El peso es requerido';
                  }
                  final weight = double.tryParse(value.trim());
                  if (weight == null || weight <= 0) {
                    return 'Ingresa un peso válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Altura
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Altura (cm)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.height),
                  suffixText: 'cm',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La altura es requerida';
                  }
                  final height = int.tryParse(value.trim());
                  if (height == null || height <= 0) {
                    return 'Ingresa una altura válida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Guardar Cambios',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
