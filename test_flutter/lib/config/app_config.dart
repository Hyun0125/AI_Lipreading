//PC의 IPv4 주소에 맞게 변경

class AppConfig {
  static const String baseUrl = 'http://172.30.1.71:8000';

  // 로그인 전에는 null
  // 나중에 카카오 로그인 붙이면 실제 userId로 바꿈
  static const int? currentUserId = null;
}