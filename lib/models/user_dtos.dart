// DTOs para la comunicación con el API de .NET

// Petición de Login
class LoginDto {
  final String email;
  final String password;

  LoginDto({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

// Petición de Registro
class RegisterDto {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final double weight; // Usamos double en Flutter para decimales
  final double height;

  RegisterDto({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.weight,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'weight': weight,
        'height': height,
      };
}

// Respuesta de Token (Usado por Login, Register, y Refresh)
class TokenDto {
  final String accessToken;
  final DateTime accessTokenExpiration;
  final String refreshToken;
  final bool isVerified;

  TokenDto({
    required this.accessToken,
    required this.accessTokenExpiration,
    required this.refreshToken,
    required this.isVerified,
  });

  factory TokenDto.fromJson(Map<String, dynamic> json) {
    return TokenDto(
      accessToken: json['accessToken'] as String,
      // Los endpoints de .NET típicamente devuelven fechas en formato ISO 8601
      accessTokenExpiration: DateTime.parse(json['accessTokenExpiration'] as String).toUtc(),
      refreshToken: json['refreshToken'] as String,
      isVerified: json['isVerified'] as bool,
    );
  }
}

class VerifyCodeDto {
  final String email;
  final String code;

  VerifyCodeDto({required this.email, required this.code});

  Map<String, dynamic> toJson() => {
        'email': email,
        'code': code,
      };
}