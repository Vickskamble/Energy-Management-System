import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppErrorBoundary extends StatelessWidget {
  final Widget child;

  const AppErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return _ErrorBoundaryState(child: child);
  }
}

class _ErrorBoundaryState extends StatefulWidget {
  final Widget child;
  const _ErrorBoundaryState({required this.child});

  @override
  State<_ErrorBoundaryState> createState() => _ErrorBoundaryStateState();
}

class _ErrorBoundaryStateState extends State<_ErrorBoundaryState> {
  FlutterErrorDetails? _error;
  int _retryKey = 0;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      final details = _error!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              const Text(
                'Rendering Error',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                details.stack?.toString().split('\n').take(5).join('\n') ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _error = null;
                  _retryKey++;
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return KeyedSubtree(key: ValueKey(_retryKey), child: widget.child);
  }
}
