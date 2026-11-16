import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class TaskService {
  // Chia sẻ công việc với người dùng khác qua Email
  Future<Map<String, dynamic>> shareTask(String taskId, String email, String role) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'message': 'Chưa đăng nhập'};

      final response = await ApiClient.dio.post(
        '/tasks/$taskId/share',
        data: {'email': email, 'role': role},
        options: _getOptions(token),
      );

      return {
        'success': response.statusCode == 200,
        'message': response.data['message'] ?? 'Thành công'
      };
    } catch (e) {
      print("🔴 LỖI SHARE TASK: $e");
      String errorMsg = 'Có lỗi xảy ra';
      if (e is DioException && e.response != null) {
        errorMsg = e.response?.data['message'] ?? errorMsg;
      }
      return {'success': false, 'message': errorMsg};
    }
  }
  // Lấy danh sách công việc (Read All)
  Future<List<dynamic>> getTasks() async {
    try {
      final token = await _getToken();
      if (token == null) return [];

      final response = await ApiClient.dio.get(
        '/tasks',
        options: _getOptions(token),
      );
      return response.data as List<dynamic>;
    } catch (e) {
      print("🔴 LỖI GET TASKS: $e");
      return [];
    }
  }
  // Thêm lại dấu ? vì SharedPreferences có thể trả về null nếu chưa lưu token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Dùng nội suy chuỗi $token để hết cảnh báo vàng
  Options _getOptions(String token) {
    return Options(headers: {'Authorization': 'Bearer $token'});
  }


  // 1. Thêm công việc mới (Create)

  Future<bool> createTask(Map<String, dynamic> taskData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        print("🔴 LỖI CREATE TASK: Chưa lấy được Token đăng nhập");
        return false;
      }

      final response = await ApiClient.dio.post(
        '/tasks',
        data: taskData,
        options: _getOptions(token),
      );

      // Chấp nhận cả 200 (OK) và 201 (Created)
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("🔴 LỖI CREATE TASK: $e");
      if (e is DioException && e.response != null) {
        print("🔴 Backend trả về lỗi: ${e.response?.data}");
      }
      return false;
    }
  }

  // 2. Xem chi tiết công việc (Read)
  Future<dynamic> getTaskById(String taskId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await ApiClient.dio.get(
        '/tasks/$taskId',
        options: _getOptions(token),
      );
      return response.data;
    } catch (e) {
      print("🔴 LỖI GET TASK DETAIL: $e");
      return null;
    }
  }

  // 3. Cập nhật công việc / Chia sẻ (Update)
  Future<bool> updateTask(String taskId, Map<String, dynamic> updateData) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await ApiClient.dio.put(
        '/tasks/$taskId',
        data: updateData,
        options: _getOptions(token),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("🔴 LỖI UPDATE TASK: $e");
      return false;
    }
  }

  // 4. Xóa công việc (Delete)
  Future<bool> deleteTask(String taskId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await ApiClient.dio.delete(
        '/tasks/$taskId',
        options: _getOptions(token),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("🔴 LỖI DELETE TASK: $e");
      return false;
    }
  }
  // --- HÀM LẤY DANH SÁCH THÔNG BÁO ---
  Future<List<dynamic>> getNotifications() async {

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      // 1. Khai báo thêm 2 dòng này (nhớ chỉnh port nếu Backend không phải 3000)
      final dio = Dio();
      final String baseUrl = 'http://10.0.2.2:3000/api';

      final response = await dio.get(
        '$baseUrl/notifications',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['notifications'] ?? [];
      }
      return [];
    } catch (e) {
      print("🔴 Lỗi tải thông báo: $e");
      return [];
    }
  }
  // --- HÀM ĐÁNH DẤU THÔNG BÁO ĐÃ ĐỌC (XÓA CHẤM ĐỎ) ---
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final token = await _getToken();
      if (token == null) return false;

      final response = await ApiClient.dio.put(
        '/notifications/$notificationId/read',
        options: _getOptions(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("🔴 LỖI MARK NOTIFICATION AS READ: $e");
      return false;
    }
  }
}
