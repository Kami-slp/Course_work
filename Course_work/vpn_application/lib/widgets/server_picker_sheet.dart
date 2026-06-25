import 'package:flutter/material.dart';
import 'package:v2ray_box/v2ray_box.dart';

import '../theme/app_theme.dart';

class ServerPickerSheet extends StatelessWidget {
  const ServerPickerSheet({
    super.key,
    required this.configs,
    required this.selected,
    required this.onSelect,
  });

  final List<VpnConfig> configs;
  final VpnConfig? selected;
  final ValueChanged<VpnConfig> onSelect;

  static Future<void> show(
    BuildContext context, {
    required List<VpnConfig> configs,
    required VpnConfig? selected,
    required ValueChanged<VpnConfig> onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ServerPickerSheet(
        configs: configs,
        selected: selected,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Выбор сервера',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: configs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final config = configs[index];
                final isSelected = config == selected;
                return Material(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () {
                      onSelect(config);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  config.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  config.protocolDisplayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.accent,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
