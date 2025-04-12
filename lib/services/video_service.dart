
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

/// Service that handles video capture and processing
class VideoService {
  // Camera controller
  CameraController? _cameraController;

  // Available cameras
  List<CameraDescription> _cameras = [];

  // Current camera info
  CameraDescription? _currentCamera;
  ResolutionPreset _currentResolution = ResolutionPreset.medium;

  // Initialization state
  bool _isInitialized = false;

  // Controllers for streams
  final _frameController = StreamController<CameraImage>.broadcast();
  final _processedFrameController = StreamController<Uint8List>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Expose streams
  Stream<CameraImage> get onFrame => _frameController.stream;
  Stream<Uint8List> get onProcessedFrame => _processedFrameController.stream;
  Stream<String> get onError => _errorController.stream;

  // Status getters
  bool get isInitialized => _isInitialized;
  CameraController? get cameraController => _cameraController;
  List<CameraDescription> get availableCameras => _cameras;
  CameraDescription? get currentCamera => _currentCamera;

  // Latest processed frame
  Uint8List? _latestFrame;
  Uint8List? get latestFrame => _latestFrame;

  // Frame processing settings
  bool _autoProcess = false;

  /// Initialize the video service
  Future<bool> initialize({
    CameraLensDirection preferredLensDirection = CameraLensDirection.back,
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        _errorController.add('Camera permission denied');
        return false;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _errorController.add('No cameras available');
        return false;
      }

      // Select camera based on preferred direction
      _currentCamera = _cameras.firstWhere(
            (camera) => camera.lensDirection == preferredLensDirection,
        orElse: () => _cameras.first,
      );

      // Store resolution setting
      _currentResolution = resolution;

      // Initialize camera
      await _initializeCamera();

      return _isInitialized;
    } catch (e) {
      _errorController.add('Failed to initialize video service: $e');
      return false;
    }
  }

  /// Initialize the camera with current settings
  Future<void> _initializeCamera() async {
    if (_currentCamera == null) return;

    // Dispose of previous controller if it exists
    await _disposeCurrentController();

    // Create new camera controller
    _cameraController = CameraController(
      _currentCamera!,
      _currentResolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    // Initialize the controller
    try {
      await _cameraController!.initialize();
      _isInitialized = true;

      // Start image stream if auto-processing is enabled
      if (_autoProcess) {
        await startImageStream();
      }
    } catch (e) {
      _errorController.add('Failed to initialize camera: $e');
      _isInitialized = false;
    }
  }

  /// Dispose of the current camera controller
  Future<void> _disposeCurrentController() async {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }

  /// Switch to a different camera
  Future<bool> switchCamera() async {
    if (_cameras.length <= 1) return false;

    try {
      // Find the next camera in the list
      final currentIndex = _cameras.indexOf(_currentCamera!);
      final nextIndex = (currentIndex + 1) % _cameras.length;
      _currentCamera = _cameras[nextIndex];

      // Re-initialize with the new camera
      await _initializeCamera();

      return true;
    } catch (e) {
      _errorController.add('Failed to switch camera: $e');
      return false;
    }
  }

  /// Set the camera resolution
  Future<bool> setResolution(ResolutionPreset resolution) async {
    if (_currentResolution == resolution) return true;

    try {
      _currentResolution = resolution;

      // Re-initialize with the new resolution
      if (_isInitialized) {
        await _initializeCamera();
      }

      return true;
    } catch (e) {
      _errorController.add('Failed to set resolution: $e');
      return false;
    }
  }

  /// Start the image stream for continuous frame processing
  Future<bool> startImageStream() async {
    if (!_isInitialized) return false;

    try {
      if (_cameraController!.value.isStreamingImages) {
        return true;
      }

      await _cameraController!.startImageStream((image) {
        // Send the raw frame to the stream
        _frameController.add(image);

        // Process the frame if auto-processing is enabled
        if (_autoProcess) {
          _processFrame(image);
        }
      });

      return true;
    } catch (e) {
      _errorController.add('Failed to start image stream: $e');
      return false;
    }
  }

  /// Stop the image stream
  Future<bool> stopImageStream() async {
    if (!_isInitialized || !_cameraController!.value.isStreamingImages) {
      return false;
    }

    try {
      await _cameraController!.stopImageStream();
      return true;
    } catch (e) {
      _errorController.add('Failed to stop image stream: $e');
      return false;
    }
  }

  /// Set whether frames should be automatically processed
  void setAutoProcess(bool enabled) {
    _autoProcess = enabled;
  }

  /// Process a single camera frame
  Future<void> _processFrame(CameraImage image) async {
    try {
      // Convert the frame to a format that can be used by the LLM
      final processedImage = await compute(_convertYUV420toRGBA8888, image);

      // Store the latest processed frame
      _latestFrame = processedImage;

      // Send the processed frame to the stream
      _processedFrameController.add(processedImage);
    } catch (e) {
      debugPrint('Failed to process frame: $e');
    }
  }

  /// Capture a single frame
  Future<Uint8List?> captureFrame() async {
    if (!_isInitialized) return null;

    try {
      // Capture a picture
      final file = await _cameraController!.takePicture();

      // Read the file as bytes
      final bytes = await file.readAsBytes();

      // Update latest frame
      _latestFrame = bytes;

      return bytes;
    } catch (e) {
      _errorController.add('Failed to capture frame: $e');
      return null;
    }
  }

  /// Clean up resources
  void dispose() async {
    await _disposeCurrentController();

    _frameController.close();
    _processedFrameController.close();
    _errorController.close();
  }
}

/// Convert a YUV420 image to RGBA8888 format
/// This function runs on a separate isolate
Uint8List _convertYUV420toRGBA8888(CameraImage image) {
  try {
    // Get image dimensions
    final width = image.width;
    final height = image.height;

    // Convert YUV to RGB
    // This is a simplified implementation that might not be optimal for all devices
    // A more robust solution would handle different YUV formats

    // Create a buffer for the RGBA8888 image
    final rgbaImage = img.Image(width: width, height: height);

    // Extract Y, U, and V planes
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel!;

    // Convert YUV to RGB
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        // YUV to RGB conversion
        int Y = yPlane[yIndex];
        int U = uPlane[uvIndex] - 128;
        int V = vPlane[uvIndex] - 128;

        // RGB conversion
        int r = (Y + 1.402 * V).round().clamp(0, 255);
        int g = (Y - 0.344 * U - 0.714 * V).round().clamp(0, 255);
        int b = (Y + 1.772 * U).round().clamp(0, 255);

        // Set the pixel in the RGBA image
        rgbaImage.setPixelRgb(x, y, r, g, b);
      }
    }

    // Encode as PNG
    return Uint8List.fromList(img.encodePng(rgbaImage));
  } catch (e) {
    debugPrint('Error converting image: $e');
    return Uint8List(0);
  }
}