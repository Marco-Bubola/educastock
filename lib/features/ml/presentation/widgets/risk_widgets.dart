import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/risk_prediction.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _fgForLevel(RiskLevel level) {
  switch (level) {
    case RiskLevel.verde:
      return AppColors.success600;
    case RiskLevel.amarelo:
      return AppColors.warning600;
    case RiskLevel.vermelho:
      return AppColors.danger600;
  }
}

Color _bgForLevel(RiskLevel level, bool isDark) {
  final fg = _fgForLevel(level);
  return fg.withValues(alpha: isDark ? 0.18 : 0.10);
}

IconData _iconForLevel(RiskLevel level) {
  switch (level) {
    case RiskLevel.verde:
      return Icons.check_circle_rounded;
    case RiskLevel.amarelo:
      return Icons.schedule_rounded;
    case RiskLevel.vermelho:
      return Icons.warning_rounded;
  }
}

// ─── RiskBadge ────────────────────────────────────────────────────────────────

/// Badge compacto exibindo o nível de risco ML de um lote.
class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  final bool compact;

  const RiskBadge({super.key, required this.level, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _fgForLevel(level);
    final bg = _bgForLevel(level, isDark);

    if (compact) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Icon(_iconForLevel(level), size: 14, color: fg),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForLevel(level), size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            level.label,
            style: AppTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RiskInsightCard ─────────────────────────────────────────────────────────

/// Card de insight para o dashboard/página de ML.
class RiskInsightCard extends StatelessWidget {
  final RiskPrediction prediction;
  final VoidCallback? onTap;

  const RiskInsightCard({super.key, required this.prediction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final fg = _fgForLevel(prediction.level);
    final pct = (prediction.confidence * 100).clamp(0, 100).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: fg.withValues(alpha: isDark ? 0.3 : 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: fg.withValues(alpha: isDark ? 0.08 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Barra colorida lateral
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [fg, fg.withValues(alpha: 0.5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.card),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Ícone
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _bgForLevel(prediction.level, isDark),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(_iconForLevel(prediction.level), color: fg, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Conteúdo
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.productName,
                      style: AppTypography.labelLarge.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      prediction.level.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // Barra de confiança
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: prediction.confidence.clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(fg),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '$pct%',
                          style: AppTypography.labelSmall.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── RiskSummaryRow ──────────────────────────────────────────────────────────

/// Linha de resumo de contadores por nível (Verde/Amarelo/Vermelho).
class RiskSummaryRow extends StatelessWidget {
  final Map<RiskLevel, int> counts;

  const RiskSummaryRow({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RiskLevel.values.asMap().entries.map((e) {
        final i = e.key;
        final level = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : AppSpacing.xs,
              right: i == RiskLevel.values.length - 1 ? 0 : AppSpacing.xs,
            ),
            child: _RiskCounter(level: level, count: counts[level] ?? 0),
          ),
        );
      }).toList(),
    );
  }
}

class _RiskCounter extends StatelessWidget {
  final RiskLevel level;
  final int count;
  const _RiskCounter({required this.level, required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _fgForLevel(level);
    final bg = _bgForLevel(level, isDark);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [fg, fg.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: fg.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$count',
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            level.label,
            style: AppTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

