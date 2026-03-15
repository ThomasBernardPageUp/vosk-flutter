/// Stub for dart:io
library;

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isLinux => false;
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static String get operatingSystem => 'web';
  static Map<String, String> get environment => {};
}

class Directory {
  final String path;
  Directory(this.path);
  bool existsSync() => false;
}

class File {
  final String path;
  File(this.path);
  bool existsSync() => false;
}
