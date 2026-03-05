class AppConfig {
  static const String appName = 'Fleet Dispatch AI Assistant';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String apiBaseUrlDev = 'http://localhost:8000'; // Web & desktop
  static const String apiBaseUrlAndroid = 'http://10.0.2.2:8000'; // Android emulator
  static const String apiBaseUrlLocal = 'http://<server-ip>:8000'; // Real device on same WiFi
  static const String apiBaseUrlServer = 'http://<server-ip>:8000'; // Company server direct
  static const String apiBaseUrlStaging = 'https://staging-api.example.com';
  static const String apiBaseUrlProd = 'https://api.example.com';

  static String get apiBaseUrl {
    const env = String.fromEnvironment('ENV', defaultValue: 'dev');
    switch (env) {
      case 'dev':
        return apiBaseUrlDev;
      case 'android':
        return apiBaseUrlAndroid;
      case 'local':
        return apiBaseUrlLocal;
      case 'server':
        return apiBaseUrlServer;
      case 'staging':
        return apiBaseUrlStaging;
      case 'prod':
        return apiBaseUrlProd;
      default:
        return apiBaseUrlDev;
    }
  }

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(minutes: 3);
  static const Duration sendTimeout = Duration(seconds: 10);

  // Session
  static const Duration sessionTimeout = Duration(hours: 1);
  static const int maxMessagesPerSession = 200;

  // Retry
  static const int maxRetryAttempts = 3;
  static const Duration retryBaseDelay = Duration(seconds: 1);
}
