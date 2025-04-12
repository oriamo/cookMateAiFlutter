// lib/screens/permissions_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionsScreen({Key? key, required this.onPermissionsGranted}) : super(key: key);

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class PermissionStatus {
  final bool isGranted;
  final bool isPermanentlyDenied;

  PermissionStatus({required this.isGranted, required this.isPermanentlyDenied});
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  PermissionStatus _microphonePermission = PermissionStatus(isGranted: false, isPermanentlyDenied: false);
  PermissionStatus _cameraPermission = PermissionStatus(isGranted: false, isPermanentlyDenied: false);
  PermissionStatus _storagePermission = PermissionStatus(isGranted: false, isPermanentlyDenied: false);
  bool _isLoading = true;
  bool _hasPermanentlyDeniedPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final micStatus = await Permission.microphone.status;
    final camStatus = await Permission.camera.status;
    
    // Check for appropriate storage permissions based on Android version
    final storageStatus = await _getStoragePermissionStatus();

    setState(() {
      _microphonePermission = PermissionStatus(
        isGranted: micStatus.isGranted, 
        isPermanentlyDenied: micStatus.isPermanentlyDenied
      );
      
      _cameraPermission = PermissionStatus(
        isGranted: camStatus.isGranted, 
        isPermanentlyDenied: camStatus.isPermanentlyDenied
      );
      
      _storagePermission = PermissionStatus(
        isGranted: storageStatus.isGranted, 
        isPermanentlyDenied: storageStatus.isPermanentlyDenied
      );
      
      _hasPermanentlyDeniedPermissions = 
          _microphonePermission.isPermanentlyDenied ||
          _cameraPermission.isPermanentlyDenied ||
          _storagePermission.isPermanentlyDenied;
      
      _isLoading = false;
    });

    // If all permissions are already granted, move on
    if (_allPermissionsGranted()) {
      widget.onPermissionsGranted();
    }
  }

  // Helper method to check appropriate storage permissions
  Future<PermissionStatus> _getStoragePermissionStatus() async {
    // For Android 13+ (API 33+), we need to use photos and video permissions
    if (await _isAndroid13OrHigher()) {
      final photos = await Permission.photos.status;
      final videos = await Permission.videos.status;
      
      // Consider granted if both permissions are granted
      return PermissionStatus(
        isGranted: photos.isGranted && videos.isGranted,
        isPermanentlyDenied: photos.isPermanentlyDenied || videos.isPermanentlyDenied
      );
    } 
    // For Android 10-12, we can use the legacy storage permission
    else {
      final storage = await Permission.storage.status;
      return PermissionStatus(
        isGranted: storage.isGranted,
        isPermanentlyDenied: storage.isPermanentlyDenied
      );
    }
  }

  // Check if device is running Android 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    // Using permission_handler's helper methods
    return await Permission.photos.status.isGranted != await Permission.storage.status.isGranted ||
           await Permission.videos.status.isGranted != await Permission.storage.status.isGranted;
  }

  bool _allPermissionsGranted() {
    return _microphonePermission.isGranted && 
           _cameraPermission.isGranted && 
           _storagePermission.isGranted;
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);

    // If any permissions are permanently denied, we need to direct user to settings
    if (_hasPermanentlyDeniedPermissions) {
      await openAppSettings();
      // After returning from settings, check permissions again
      await _checkPermissions();
      setState(() => _isLoading = false);
      return;
    }

    // Request microphone permission
    if (!_microphonePermission.isGranted) {
      final status = await Permission.microphone.request();
      setState(() {
        _microphonePermission = PermissionStatus(
          isGranted: status.isGranted,
          isPermanentlyDenied: status.isPermanentlyDenied
        );
      });
    }

    // Request camera permission
    if (!_cameraPermission.isGranted) {
      final status = await Permission.camera.request();
      setState(() {
        _cameraPermission = PermissionStatus(
          isGranted: status.isGranted,
          isPermanentlyDenied: status.isPermanentlyDenied
        );
      });
    }

    // Request appropriate storage permissions
    if (!_storagePermission.isGranted) {
      final storageStatus = await _requestStoragePermissions();
      setState(() {
        _storagePermission = storageStatus;
      });
    }

    // Update the permanently denied flag
    setState(() {
      _hasPermanentlyDeniedPermissions = 
          _microphonePermission.isPermanentlyDenied ||
          _cameraPermission.isPermanentlyDenied ||
          _storagePermission.isPermanentlyDenied;
      _isLoading = false;
    });

    // If all permissions granted, call callback
    if (_allPermissionsGranted()) {
      widget.onPermissionsGranted();
    }
  }

  // Request the appropriate storage permissions based on Android version
  Future<PermissionStatus> _requestStoragePermissions() async {
    if (await _isAndroid13OrHigher()) {
      // For Android 13+, request photos and videos permissions
      final photosStatus = await Permission.photos.request();
      final videosStatus = await Permission.videos.request();
      
      return PermissionStatus(
        isGranted: photosStatus.isGranted && videosStatus.isGranted,
        isPermanentlyDenied: photosStatus.isPermanentlyDenied || videosStatus.isPermanentlyDenied
      );
    } else {
      // For older Android versions, use the legacy storage permission
      final storageStatus = await Permission.storage.request();
      print("Status for storage permissions is: $storageStatus");
      
      return PermissionStatus(
        isGranted: storageStatus.isGranted,
        isPermanentlyDenied: storageStatus.isPermanentlyDenied
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content area
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      const Text(
                        'App Permissions',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'CookMate AI needs the following permissions to provide you with the best cooking experience:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Microphone permission
                      _buildPermissionItem(
                        icon: Icons.mic,
                        title: 'Microphone',
                        description: 'To allow you to use voice commands and speak to the AI assistant',
                        status: _microphonePermission,
                      ),
                      
                      // Camera permission
                      _buildPermissionItem(
                        icon: Icons.camera_alt,
                        title: 'Camera',
                        description: 'To take photos of ingredients and dishes for recipes',
                        status: _cameraPermission,
                      ),
                      
                      // Storage permission
                      _buildPermissionItem(
                        icon: Icons.storage,
                        title: 'Storage',
                        description: 'To save recipes and photos to your device',
                        status: _storagePermission,
                      ),
                      
                      if (_hasPermanentlyDeniedPermissions)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text(
                                      'Permission Required',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Some permissions have been permanently denied. You need to enable them manually in your device settings for the app to work properly.',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Extra padding at the bottom for better scrolling
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            
            // Fixed button at the bottom
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: !_allPermissionsGranted()
                ? ElevatedButton(
                    onPressed: _requestPermissions,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: _hasPermanentlyDeniedPermissions 
                          ? Colors.amber 
                          : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      _hasPermanentlyDeniedPermissions
                          ? 'Open App Settings'
                          : 'Grant Permissions'
                    ),
                  )
                : ElevatedButton(
                    onPressed: widget.onPermissionsGranted,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue to App'),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon, 
    required String title, 
    required String description, 
    required PermissionStatus status,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.deepPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (status.isPermanentlyDenied)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Permanently denied - enable in settings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            status.isGranted 
              ? Icons.check_circle 
              : (status.isPermanentlyDenied ? Icons.settings : Icons.circle_outlined),
            color: status.isGranted 
              ? Colors.green 
              : (status.isPermanentlyDenied ? Colors.amber : Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}