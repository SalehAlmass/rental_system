import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final String? trend;
  final VoidCallback? onTap;
  final double? width;
  final bool compact;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.trend,
    this.onTap,
    this.width,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: width ?? 176,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tone.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tone.withOpacity(0.18), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tone.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: tone, size: compact ? 20 : 24),
                    ),
                    const Spacer(),
                    if (trend != null && trend!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          trend!,
                          style: TextStyle(
                            color: tone,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 18),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: tone,
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: tone,
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        color: tone.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
