// lib/widgets/cooking_timer_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/timer_provider.dart';
import '../services/timer_service.dart';

/// Widget that displays a single timer
class CookingTimerItem extends ConsumerWidget {
  final CookingTimer timer;

  const CookingTimerItem({
    Key? key,
    required this.timer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerService = ref.watch(timerServiceProvider);

    // Format remaining time
    final remaining = timer.remaining;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';

    // Determine color based on remaining time
    final progress = timer.progress;
    Color timerColor;

    if (progress < 0.5) {
      // More than half time remaining - use normal purple
      timerColor = Colors.deepPurple;
    } else if (progress < 0.75) {
      // Less than half but more than quarter - use orange
      timerColor = Colors.orange;
    } else {
      // Last quarter - use red for urgency
      timerColor = Colors.red;
    }

    return Container(
      height: 48, // Slim pill height
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24), // Pill shape
        border: Border.all(color: timerColor.withOpacity(0.3), width: 1),
      ),
      child: Stack(
        children: [
          // Background progress bar
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.grey.withOpacity(0.1),
              ),
            ),
          ),
          // Progress fill
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: timer.progress,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: timerColor.withOpacity(0.2),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Timer icon
                Icon(
                  Icons.timer,
                  color: timerColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                // Timer label
                Expanded(
                  child: Text(
                    timer.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Time remaining
                Text(
                  timeString,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: timerColor,
                  ),
                ),
                const SizedBox(width: 8),
                // Pause/Resume button
                InkWell(
                  onTap: timer.isPaused 
                      ? () => timerService.resumeTimer(timer.id)
                      : () => timerService.pauseTimer(timer.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: timerColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      timer.isPaused ? Icons.play_arrow : Icons.pause,
                      size: 16,
                      color: timerColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Cancel button
                InkWell(
                  onTap: () => timerService.cancelTimer(timer.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget that displays all active timers
class ActiveTimersPanel extends ConsumerWidget {
  const ActiveTimersPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timersAsync = ref.watch(activeTimersProvider);

    return timersAsync.when(
      data: (timers) {
        if (timers.isEmpty) {
          return SizedBox.shrink(); // No timers, no display
        }

        // Calculate available width
        final screenWidth = MediaQuery.of(context).size.width;

        return Container(
          constraints: BoxConstraints(
            maxHeight: 140, // Increased height to accommodate timer content
          ),
          width: screenWidth,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: timers.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final timer = timers[index];
              return SizedBox(
                width: screenWidth * 0.8,
                child: CookingTimerItem(timer: timer),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
