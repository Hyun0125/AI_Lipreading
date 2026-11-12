//PC의 IPv4 주소에 맞게 변경

class AppConfig {
  // 개발 PC가 바뀌어도 소스를 수정하지 않도록 실행 시 URL 재정의 가능.
  // 예: flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'http://172.30.1.95:8000',
  );

  // 로그인 전에는 null
  // 나중에 카카오 로그인 붙이면 실제 userId로 바꿈
  static const int? currentUserId = null;
}