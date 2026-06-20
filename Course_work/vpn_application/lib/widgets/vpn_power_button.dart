import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class VpnPowerButton extends StatelessWidget {
  const VpnPowerButton({
    super.key,
    required this.status,
    required this.onTap,
    this.enabled = true,
  });

  final VpnUiStatus status;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = vpnStatusColor(status);
    final isConnecting = status == VpnUiStatus.connecting;
    final isConnected = status == VpnUiStatus.connected;

    return GestureDetector(
      onTap: enabled && !isConnecting ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(
            color: color.withValues(alpha: isConnected ? 0.8 : 0.4),
            width: 3,
          ),
          boxShadow: isConnected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: isConnecting
              ? SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: color,
                  ),
                )
              : Icon(
                  Icons.power_settings_new_rounded,
                  size: 72,
                  color: enabled
                      ? color
                      : AppColors.disconnected.withValues(alpha: 0.4),
                ),
        ),
      ),
    );
  }
}
