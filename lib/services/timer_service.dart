// lib/services/timer_service.dart
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Model class for timer data
class CookingTimer {
  final String id;
  final String label;
  final Duration duration;
  final DateTime startTime;
  late final DateTime endTime;
  bool isActive;
  bool isPaused;
  Duration? remainingTime;
  Timer? timer;

  CookingTimer({
    required this.label,
    required this.duration,
    String? id,
  }) : 
    id = id ?? const Uuid().v4(),
    startTime = DateTime.now(),
    endTime = DateTime.now().add(duration),
    isActive = true,
    isPaused = false;

  /// Calculate remaining time
  Duration get remaining {
    if (!isActive) return Duration.zero;
    if (isPaused && remainingTime != null) return remainingTime!;
    
    final now = DateTime.now();
    if (now.isAfter(endTime)) return Duration.zero;
    return endTime.difference(now);
  }

  /// Calculate progress percentage (0.0 to 1.0)
  double get progress {
    if (!isActive) return 1.0;
    if (duration.inSeconds == 0) return 1.0;
    
    final remainingSecs = remaining.inSeconds;
    final totalSecs = duration.inSeconds;
    
    return 1.0 - (remainingSecs / totalSecs).clamp(0.0, 1.0);
  }

  /// Update end time when pausing/resuming
  void updateEndTime() {
    if (remainingTime != null) {
      endTime = DateTime.now().add(remainingTime!);
    }
  }
}

/// Service to manage cooking timers
class TimerService {
  // Singleton instance
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  // Notifications
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final BehaviorSubject<String?> _selectNotificationSubject = BehaviorSubject<String?>();
  bool _isInitialized = false;
  
  // Active timers
  final Map<String, CookingTimer> _activeTimers = {};
  final _timerController = BehaviorSubject<List<CookingTimer>>.seeded([]);
  
  // Background port for receiving completion notifications
  final ReceivePort _port = ReceivePort();
  
  // Getters
  Stream<List<CookingTimer>> get timers => _timerController.stream;
  List<CookingTimer> get activeTimers => _activeTimers.values.toList();
  bool get hasActiveTimers => _activeTimers.isNotEmpty;
  
  /// Initialize timer service and notifications
  Future<void> init() async {
    if (_isInitialized) return;
    
    // Initialize timezone data
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York')); // Default to New York timezone, adjust as needed
    
    // Setup receive port for background notifications
    IsolateNameServer.registerPortWithName(_port.sendPort, 'cooking_timer_port');
    _port.listen((dynamic data) {
      // Handle message from background
      final String? timerId = data as String?;
      if (timerId != null) {
        _handleTimerCompletion(timerId);
      }
    });
    
    // Initialize notifications
    final initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _selectNotificationSubject.add(response.payload);
      }
    );
    
    _isInitialized = true;
  }
  
  /// Create a new timer
  Future<CookingTimer> createTimer({
    required String label, 
    required int minutes,
  }) async {
    await init();
    
    // Create timer object
    final duration = Duration(minutes: minutes);
    final timer = CookingTimer(
      label: label,
      duration: duration,
    );
    
    // Add to active timers
    _activeTimers[timer.id] = timer;
    
    // Start timer logic
    _startTimer(timer);
    
    // Schedule notification as backup
    _scheduleNotification(timer);
    
    // Notify listeners
    _timerController.add(activeTimers);
    
    return timer;
  }
  
  /// Start a timer (internal)
  void _startTimer(CookingTimer timerObj) {
    // Cancel any existing timer first
    timerObj.timer?.cancel();
    
    // Create a periodic timer that ticks every second
    timerObj.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!timerObj.isActive || timerObj.isPaused) {
        // Do nothing if inactive or paused
        return;
      }
      
      final now = DateTime.now();
      
      // Check if timer is complete
      if (now.isAfter(timerObj.endTime)) {
        _handleTimerCompletion(timerObj.id);
        timer.cancel();
        return;
      }
      
      // Update remaining time
      timerObj.remainingTime = timerObj.endTime.difference(now);
      
      // Notify listeners periodically (once per second)
      _timerController.add(activeTimers);
    });
  }
  
  /// Schedule a local notification for timer completion
  Future<void> _scheduleNotification(CookingTimer timer) async {
    final androidDetails = AndroidNotificationDetails(
      'cooking_timer_channel',
      'Cooking Timers',
      channelDescription: 'Notifications for cooking timers',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('timer_complete'),
      playSound: true,
      enableVibration: true,
    );
    
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'timer_complete.aiff',
    );
    
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    
    // Convert DateTime to TZDateTime for notifications
    final tzEndTime = tz.TZDateTime.from(timer.endTime, tz.local);
    
    // Schedule notification for the timer end time
    await _notifications.zonedSchedule(
      timer.id.hashCode,
      'Timer Complete',
      '${timer.label} timer is complete!',
      tzEndTime,
      details,
      payload: timer.id,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }
  
  /// Handle timer completion
  void _handleTimerCompletion(String timerId) {
    if (_activeTimers.containsKey(timerId)) {
      final timer = _activeTimers[timerId]!;
      timer.isActive = false;
      timer.timer?.cancel();
      
      // Remove from active timers
      _activeTimers.remove(timerId);
      
      // Notify listeners
      _timerController.add(activeTimers);
    }
  }
  
  /// Pause a timer
  void pauseTimer(String timerId) {
    if (_activeTimers.containsKey(timerId)) {
      final timer = _activeTimers[timerId]!;
      timer.isPaused = true;
      timer.remainingTime = timer.remaining;
      
      // Cancel notification and reschedule with new end time
      _notifications.cancel(timer.id.hashCode);
      
      // Notify listeners
      _timerController.add(activeTimers);
    }
  }
  
  /// Resume a paused timer
  void resumeTimer(String timerId) {
    if (_activeTimers.containsKey(timerId)) {
      final timer = _activeTimers[timerId]!;
      if (timer.isPaused) {
        timer.isPaused = false;
        timer.updateEndTime();
        
        // Reschedule notification
        _scheduleNotification(timer);
        
        // Notify listeners
        _timerController.add(activeTimers);
      }
    }
  }
  
  /// Cancel a timer
  void cancelTimer(String timerId) {
    if (_activeTimers.containsKey(timerId)) {
      final timer = _activeTimers[timerId]!;
      timer.isActive = false;
      timer.timer?.cancel();
      
      // Cancel notification
      _notifications.cancel(timer.id.hashCode);
      
      // Remove from active timers
      _activeTimers.remove(timerId);
      
      // Notify listeners
      _timerController.add(activeTimers);
    }
  }
  
  /// Cancel all timers
  void cancelAllTimers() {
    // Cancel all individual timers
    for (final timerId in _activeTimers.keys.toList()) {
      cancelTimer(timerId);
    }
  }
  
  /// Extract timer duration from AI response
  static int? extractTimerDuration(String message) {
    // Normalize the message - convert to lowercase and remove extra spaces
    final normalizedMessage = message.toLowerCase().trim();
    
    // Define regex pattern to match time in the format
    // "alright let me set up a timer for X minutes"
    final primaryPattern = RegExp(r'set up a timer for (\d+) minute');
    final primaryMatch = primaryPattern.firstMatch(normalizedMessage);
    
    if (primaryMatch != null && primaryMatch.groupCount >= 1) {
      final minutes = int.tryParse(primaryMatch.group(1) ?? '');
      debugPrint('🕒 TIMER SERVICE: Detected timer duration using primary pattern: $minutes minutes');
      return minutes;
    }
    
    // Try variations of the primary pattern
    final patternVariations = [
      RegExp(r'set a timer for (\d+) minute'),
      RegExp(r'start a timer for (\d+) minute'),
      RegExp(r'let me set up a timer for (\d+) minute'),
      RegExp(r'alright let me set up a timer for (\d+) minute'),
      RegExp(r'ok let me set up a timer for (\d+) minute'),
      RegExp(r"i'll set a timer for (\d+) minute")
    ];
    
    for (final pattern in patternVariations) {
      final match = pattern.firstMatch(normalizedMessage);
      if (match != null && match.groupCount >= 1) {
        final minutes = int.tryParse(match.group(1) ?? '');
        debugPrint('🕒 TIMER SERVICE: Detected timer duration using pattern variation: $minutes minutes');
        return minutes;
      }
    }
    
    // Try a more general pattern if the specific ones don't match
    final generalPattern = RegExp(r'timer.+?(\d+).+?minute');
    final generalMatch = generalPattern.firstMatch(normalizedMessage);
    
    if (generalMatch != null && generalMatch.groupCount >= 1) {
      final minutes = int.tryParse(generalMatch.group(1) ?? '');
      debugPrint('🕒 TIMER SERVICE: Detected timer duration using general pattern: $minutes minutes');
      return minutes;
    }
    
    // Last resort - look for any number followed by "minutes" or "minute"
    final lastResortPattern = RegExp(r'(\d+)\s*minutes?');
    final lastResortMatch = lastResortPattern.firstMatch(normalizedMessage);
    
    if (lastResortMatch != null && lastResortMatch.groupCount >= 1) {
      final minutes = int.tryParse(lastResortMatch.group(1) ?? '');
      debugPrint('🕒 TIMER SERVICE: Detected timer duration using last resort pattern: $minutes minutes');
      return minutes;
    }
    
    debugPrint('🕒 TIMER SERVICE: No timer duration detected in message: "${message.substring(0, Math.min(50, message.length))}..."');
    return null;
  }
  
  /// Dispose resources
  void dispose() {
    _selectNotificationSubject.close();
    _timerController.close();
    IsolateNameServer.removePortNameMapping('cooking_timer_port');
    cancelAllTimers();
  }
}