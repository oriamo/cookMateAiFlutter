// lib/providers/timer_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/timer_service.dart';

// Provider for the TimerService singleton
final timerServiceProvider = Provider<TimerService>((ref) {
  final service = TimerService();
  ref.onDispose(() {
    // No need to dispose TimerService as it's a singleton
  });
  return service;
});

// Stream provider for active timers
final activeTimersProvider = StreamProvider<List<CookingTimer>>((ref) {
  final timerService = ref.watch(timerServiceProvider);
  return timerService.timers;
});

// Provider for checking if there are any active timers
final hasActiveTimersProvider = Provider<bool>((ref) {
  final timersAsyncValue = ref.watch(activeTimersProvider);
  return timersAsyncValue.when(
    data: (timers) => timers.isNotEmpty,
    loading: () => false,
    error: (_, __) => false,
  );
});