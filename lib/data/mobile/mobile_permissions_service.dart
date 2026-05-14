import 'package:flutter/services.dart';

enum MediaPermissionStatus { granted, denied, limited }

abstract class MobilePermissionsService {
  Future<MediaPermissionStatus> requestMediaReadPermission();
}

class MethodChannelMobilePermissionsService
    implements MobilePermissionsService {
  static const MethodChannel channel = MethodChannel(
    'rephoto/mobile_permissions',
  );

  @override
  Future<MediaPermissionStatus> requestMediaReadPermission() async {
    final status = await channel.invokeMethod<String>(
      'requestMediaReadPermission',
    );
    switch (status) {
      case 'granted':
        return MediaPermissionStatus.granted;
      case 'limited':
        return MediaPermissionStatus.limited;
      default:
        return MediaPermissionStatus.denied;
    }
  }
}
