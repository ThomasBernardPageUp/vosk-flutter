import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestMicrophonePermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.microphone.status;
      if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true;
  }
}
