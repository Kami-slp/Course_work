import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ServerCard extends StatelessWidget {
  const ServerCard({
    super.key,
    required this.name,
    required this.protocol,
    this.pingMs,
    this.onTap,
    this.onPing,
    this.pingLoading = false,
  });

  final String name;
  final String protocol;
  final int? pingMs;
  final VoidCallback? onTap;
  final VoidCallback? onPing;
  final bool pingLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      protocol,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (onPing != null)
                IconButton(
                  onPressed: pingLoading ? null : onPing,
                  icon: pingLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.speed_rounded, size: 22),
                  tooltip: 'Ping',
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              if (pingMs != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${pingMs}ms',
                    style: TextStyle(
                      color: _pingColor(pingMs!),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _pingColor(int ms) {
    if (ms < 100) return AppColors.connected;
    if (ms < 250) return AppColors.connecting;
    return AppColors.error;
  }
}
