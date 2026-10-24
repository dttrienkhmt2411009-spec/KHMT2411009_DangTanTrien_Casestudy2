import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  // Hàm xử lý Đăng nhập
  Future<bool> login(String email, String password) async {
    try {
      final response = await ApiClient.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Hàm xử lý Đăng ký
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
      // HTTP 201 (Created) khi tạo thành công
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}