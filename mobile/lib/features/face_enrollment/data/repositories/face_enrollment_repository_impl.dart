import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/face_enrollment_entities.dart';
import '../../domain/repositories/face_enrollment_repository.dart';
import '../datasources/face_enrollment_remote_datasource.dart';

class FaceEnrollmentRepositoryImpl implements FaceEnrollmentRepository {
  final FaceEnrollmentRemoteDataSource remoteDataSource;

  const FaceEnrollmentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<FaceStatusEntity> getFaceStatus() async {
    try {
      return await remoteDataSource.getFaceStatus();
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal memuat status registrasi wajah.',
        code: 'SERVER_ERROR',
      );
    }
  }

  @override
  Future<FaceEnrollResult> enrollFace({
    required List<List<double>> embeddings,
    required Uint8List referencePhotoBytes,
    String referenceFileName = 'face_reference.jpg',
    required bool replace,
  }) async {
    try {
      return await remoteDataSource.enrollFace(
        embeddings: embeddings,
        referencePhotoBytes: referencePhotoBytes,
        referenceFileName: referenceFileName,
        replace: replace,
      );
    } on DioException catch (e) {
      if (e.error is Failure) {
        throw e.error!;
      }
      throw ServerFailure(
        message: e.message ?? 'Gagal menyimpan registrasi wajah ke server.',
        code: 'SERVER_ERROR',
      );
    }
  }
}
