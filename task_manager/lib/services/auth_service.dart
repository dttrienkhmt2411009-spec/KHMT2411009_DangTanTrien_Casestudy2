import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  // Hàm xử lý Đăng nhập (Có log gỡ lỗi)
  Future<bool> login(String email, String password) async {
    try {
      print("🔵 Đang gửi request login với email: $email");

      final response = await ApiClient.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      print("🟢 API trả về HTTP Status: ${response.statusCode}");
      print("🟢 Dữ liệu Backend trả về: ${response.data}");

      if (response.statusCode == 200) {
        // NẾU BACKEND DÙNG TÊN KHÁC, HÃY SỬA CHỮ 'token' Ở DÒNG DƯỚI
        final token = response.data['token'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          return true;
        } else {
          print("🔴 LỖI: Không tìm thấy chữ 'token' trong JSON!");
        }
      }
      return false;
    } catch (e) {
      print("🔴 LỖI GỌI API LOGIN: $e");
      return false;
    }
  }

  // Hàm xử lý Đăng ký (Đã khôi phục lại)
  Future<bool> register(String fullName, String email, String password) async {
    try {
      final response = await ApiClient.dio.post(
        '/auth/register',
        data: {
          'fullName': fullName,
          'email': email,
          'password': password,
        },
      );
      return response.statusCode == 201;
    } catch (e) {
      print("🔴 LỖI GỌI API REGISTER: $e");
      return false;
    }
  }
}