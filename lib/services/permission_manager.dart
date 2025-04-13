import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Central service to manage permissions throughout the app
class PermissionManager {
  // Singleton instance
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  // Cache permission status to avoid frequent checks
  final Map<Permission, PermissionStatus> _permissionCache = {};

  /// Check if a specific permission is granted
  Future<bool> isPermissionGranted(Permission permission) async {
    if (_permissionCache.containsKey(permission)) {
      return _permissionCache[permission]!.isGranted;
    }
    
    final status = await permission.status;
    _permissionCache[permission] = status;
    return status.isGranted;
  }

  /// Request a specific permission
  Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    _permissionCache[permission] = status;
    return status.isGranted;
  }

  /// Request multiple permissions at once
  Future<Map<Permission, bool>> requestPermissions(List<Permission> permissions) async {
    final result = <Permission, bool>{};
    
    for (final permission in permissions) {
      final granted = await requestPermission(permission);
      result[permission] = granted;
    }
    
    return result;
  }

  /// Check if storage permissions are granted based on Android version
  Future<bool> isStoragePermissionGranted() async {
    if (await _isAndroid13OrHigher()) {
      final photos = await isPermissionGranted(Permission.photos);
      final videos = await isPermissionGranted(Permission.videos);
      return photos && videos;
    } else {
      return await isPermissionGranted(Permission.storage);
    }
  }

  /// Request storage permissions based on Android version
  Future<bool> requestStoragePermission() async {
    if (await _isAndroid13OrHigher()) {
      final results = await requestPermissions([Permission.photos, Permission.videos]);
      return results.values.every((granted) => granted);
    } else {
      return await requestPermission(Permission.storage);
    }
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    return await requestPermission(Permission.camera);
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    return await requestPermission(Permission.microphone);
  }

  /// Check if device is running Android 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    return await Permission.photos.status.isGranted != await Permission.storage.status.isGranted ||
           await Permission.videos.status.isGranted != await Permission.storage.status.isGranted;
  }

  /// Show a permission request dialog with explanation
  Future<bool> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required Future<bool> Function() onRequestPermission,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(await onRequestPermission());
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Clear the permission cache to force re-checking
  void clearCache() {
    _permissionCache.clear();
  }
}