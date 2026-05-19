import 'stubs/io_stub.dart' if (dart.library.io) 'dart:io';
import 'stubs/permission_handler_stub.dart'
    if (dart.library.io) 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestMicrophonePermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return (await Permission.microphone.request()).isGranted;
    }
    return true;
  }
}
