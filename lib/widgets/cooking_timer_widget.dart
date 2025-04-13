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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: timerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: timerColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer label and remaining time
          Row(
            children: [
              Icon(
                Icons.timer,
                color: timerColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  timer.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                timeString,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Progress bar
          LinearProgressIndicator(
            value: timer.progress,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              timerColor,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          
          const SizedBox(height: 8),
          
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Pause/Resume button
              if (timer.isPaused)
                IconButton(
                  icon: Icon(Icons.play_arrow),
                  onPressed: () => timerService.resumeTimer(timer.id),
                  tooltip: 'Resume',
                  iconSize: 20,
                  constraints: BoxConstraints.tight(Size(32, 32)),
                  padding: EdgeInsets.zero,
                )
              else
                IconButton(
                  icon: Icon(Icons.pause),
                  onPressed: () => timerService.pauseTimer(timer.id),
                  tooltip: 'Pause',
                  iconSize: 20,
                  constraints: BoxConstraints.tight(Size(32, 32)),
                  padding: EdgeInsets.zero,
                ),
                
              // Cancel button
              IconButton(
                icon: Icon(Icons.cancel_outlined),
                onPressed: () => timerService.cancelTimer(timer.id),
                tooltip: 'Cancel',
                iconSize: 20,
                constraints: BoxConstraints.tight(Size(32, 32)),
                padding: EdgeInsets.zero,
              ),
            ],
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
          return SizedBox.shrink();  // No timers, no display
        }
        
        // Calculate available width
        final screenWidth = MediaQuery.of(context).size.width;
        
        return Container(
          constraints: BoxConstraints(
            maxHeight: 120, // Limit height
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