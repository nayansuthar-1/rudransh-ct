import 'package:flutter/material.dart';

import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';
import 'primitives.dart';

/// Headline metric tile used on the dashboard.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.delta,
    this.tone = PillTone.brand,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;

  /// Percentage change; positive renders green, negative red.
  final double? delta;
  final PillTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fg, bg) = switch (tone) {
      PillTone.success => (c.success, c.successSoft),
      PillTone.warning => (c.warning, c.warningSoft),
      PillTone.danger => (c.danger, c.dangerSoft),
      PillTone.info => (c.info, c.infoSoft),
      PillTone.brand => (c.brand, c.brandSoft),
      PillTone.neutral => (c.textSecondary, c.surfaceMuted),
    };

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.responsive(mobile: 14.0, tablet: 18.0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                      height: 1.05,
                    ),
                  ),
                ),
                if (caption != null || delta != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (delta != null) ...[
                        _DeltaChip(delta: delta!),
                        const SizedBox(width: 8),
                      ],
                      if (caption != null)
                        Flexible(
                          child: Text(
                            caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: c.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final up = delta >= 0;
    final color = up ? c.success : c.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          '${up ? '+' : ''}${delta.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Responsive grid that keeps stat cards a sensible width at every size.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children, this.minTileWidth = 250});

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    const gap = 14.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = (width / minTileWidth).floor();
        columns = columns.clamp(1, children.length.clamp(1, 4));
        final tile = (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: tile, child: child),
          ],
        );
      },
    );
  }
}
