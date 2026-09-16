import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Colour family of a KPI tile. Each metric on a page gets its own, so the
/// strip can be read at a glance.
enum StatAccent {
  blue(Color(0xFF1A73E8), Color(0xFFE8F0FE)),
  green(Color(0xFF1E8E3E), Color(0xFFE6F4EA)),
  amber(Color(0xFFE37400), Color(0xFFFEF3E0)),
  red(Color(0xFFD93025), Color(0xFFFCE8E6)),
  purple(Color(0xFF8430CE), Color(0xFFF3E8FD)),
  teal(Color(0xFF12848F), Color(0xFFE0F4F5));

  const StatAccent(this.color, this.tint);

  /// Icon circle colour.
  final Color color;

  /// Tile background in light mode.
  final Color tint;
}

/// One headline metric inside a [StatGrid].
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = StatAccent.blue,
    this.caption,
    this.delta,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatAccent accent;
  final String? caption;

  /// Percentage change; positive renders green, negative red.
  final double? delta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? Color.alphaBlend(accent.color.withValues(alpha: 0.16), c.surface)
        : accent.tint;

    final content = Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
                height: 1.15,
              ),
            ),
          ),
          if (caption != null || delta != null) ...[
            const SizedBox(height: Space.xs),
            Row(
              children: [
                if (delta != null) ...[
                  _Delta(delta: delta!),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    caption ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(Radii.dialog),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: accent.color.withValues(alpha: 0.06),
        child: content,
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.delta});

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
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          '${delta.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: kTabular,
          ),
        ),
      ],
    );
  }
}

/// KPI tiles in rows of equal height: all in one row on wide screens, two per
/// row on phones. A lone last tile spans the full width.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final n = children.length;
        final columns = n <= 2 || width >= n * 200 ? n : 2;

        final rows = <List<Widget>>[];
        for (var i = 0; i < n; i += columns) {
          rows.add(children.sublist(i, (i + columns).clamp(0, n)));
        }

        return Column(
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: Space.md),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < rows[r].length; i++) ...[
                      if (i > 0) const SizedBox(width: Space.md),
                      Expanded(child: rows[r][i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
