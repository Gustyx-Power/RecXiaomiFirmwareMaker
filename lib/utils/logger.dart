class Logger {
  static final Logger _instance = Logger._internal();

  factory Logger() {
    return _instance;
  }

  Logger._internal();

  void info(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('[$timestamp] ℹ️  $message');
  }

  void success(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('[$timestamp] ✅ $message');
  }

  void warning(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('[$timestamp] ⚠️  $message');
  }

  void error(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('[$timestamp] ❌ $message');
  }

  void debug(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('[$timestamp] 🐛 $message');
  }
}
