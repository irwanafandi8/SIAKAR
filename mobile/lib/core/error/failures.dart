import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String code;

  const Failure({required this.message, required this.code});

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, required super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Koneksi jaringan terputus. Pastikan internet Anda aktif.',
    super.code = 'NETWORK_ERROR',
  });
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, required super.code});
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? errors;

  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.errors,
  });

  @override
  List<Object?> get props => [message, code, errors];
}

class FaceMismatchFailure extends Failure {
  final double? similarity;

  const FaceMismatchFailure({
    super.message = 'Wajah tidak cocok dengan data terdaftar.',
    super.code = 'FACE_MISMATCH',
    this.similarity,
  });

  @override
  List<Object?> get props => [message, code, similarity];
}

class OutOfRadiusFailure extends Failure {
  final double? distanceMeter;

  const OutOfRadiusFailure({
    super.message = 'Anda berada di luar radius kantor.',
    super.code = 'OUT_OF_RADIUS',
    this.distanceMeter,
  });

  @override
  List<Object?> get props => [message, code, distanceMeter];
}
