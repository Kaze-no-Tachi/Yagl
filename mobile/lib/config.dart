/// App-wide configuration.
///
/// Override the API base URL at build/run time without editing code:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
///   flutter build web --dart-define=API_BASE_URL=https://yagl.example.com
///
/// Defaults target a local backend. Note: when running the Android emulator,
/// the host machine is reachable at 10.0.2.2 (not localhost).
class Config {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
