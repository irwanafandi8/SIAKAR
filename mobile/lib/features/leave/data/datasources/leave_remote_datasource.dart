import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/leave_request_model.dart';

class LeaveRemoteDataSource {
  final ApiClient apiClient;

  const LeaveRemoteDataSource({required this.apiClient});

  Future<List<LeaveRequestModel>> getMyLeaves({String? status}) async {
    final response = await apiClient.dio.get(
      '/leaves',
      queryParameters: (status != null && status.isNotEmpty) ? {'status': status} : null,
    );
    final rawList = response.data['data'] as List<dynamic>? ?? const [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(LeaveRequestModel.fromJson)
        .toList();
  }

  Future<LeaveRequestModel> submitLeave({
    required String jenis,
    required String tanggalMulai,
    required String tanggalSelesai,
    required String alasan,
    String? attachmentPath,
  }) async {
    final fields = <String, dynamic>{
      'jenis': jenis,
      'tanggal_mulai': tanggalMulai,
      'tanggal_selesai': tanggalSelesai,
      'alasan': alasan,
    };

    if (attachmentPath != null && attachmentPath.trim().isNotEmpty) {
      fields['lampiran'] = await MultipartFile.fromFile(attachmentPath.trim());
    }

    final formData = FormData.fromMap(fields);
    final response = await apiClient.dio.post('/leaves', data: formData);
    final data = response.data['data'] as Map<String, dynamic>;
    return LeaveRequestModel.fromJson(data);
  }
}
