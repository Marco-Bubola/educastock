import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/risk_prediction.dart';

/// Badge compacto exibindo o nível de risco ML de um lote.
class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  final bool compact;

  const RiskBadge({super.key, required this.level, this.compact = false});

  Color get _bgColor {
    switch (level) {
      case RiskLevel.verde:
        return const Color(0xFFE6F4EA);
      case RiskLevel.amarelo:
        return const Color(0xFFFEF3C7);
      case RiskLevel.vermelho:
        return const Color(0xFFFEE2E2);
    }
  }

  Color get _fgColor {
    switch (level) {
      case RiskLevel.verde:
        return AppColors.success600;
      case RiskLevel.amarelo:
        return AppColors.warning600;
      case RiskLevel.vermelho:
        return AppColors.danger600;
    }
  }

  IconData get _icon {
    switch (level) {
      case RiskLevel.verde:
        return Icons.check_circle_outline_rounded;
      case RiskLevel.amarelo:
        return Icons.schedule_rounded;
      case RiskLevel.vermelho:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(_icon, size: 14, color: _fgColor),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _fgColor),
          const SizedBox(width: 4),
          Text(
            level.label,
            style: AppTypography.labelSmall.copyWith(color: _fgColor),
          ),
        ],
      ),
    );
  }
}

/// Card de insight para o dashboard/página de ML.
class RiskInsightCard extends StatelessWidget {
  final RiskPrediction prediction;
  final VoidCallback? onTap;

  const RiskInsightCard({super.key, required this.prediction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = (prediction.confidence * 100).toStringAsFixed(0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.neutral100),
        ),
        child: Row(
          children: [
            RiskBadge(level: prediction.level),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.productName,
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.neutral900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    prediction.level.description,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$pct%',
              style: AppTypography.numberSmall.copyWith(
                color: AppColors.neutral700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linha de resumo de contadores por nível (Verde/Amarelo/Vermelho).
class RiskSummaryRow extends StatelessWidget {
  final Map<RiskLevel, int> counts;

  const RiskSummaryRow({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RiskLevel.values.map((level) {
        final count = counts[level] ?? 0;
        return Expanded(
          child: _RiskCounter(level: level, count: count),
        );
      }).toList(),
    );
  }
}

class _RiskCounter extends StatelessWidget {
  final RiskLevel level;
  final int count;
  const _RiskCounter({required this.level, required this.count});

  Color get _bgColor {
    switch (level) {
      case RiskLevel.verde:
        return const Color(0xFFE6F4EA);
      case RiskLevel.amarelo:
        return const Color(0xFFFEF3C7);
      case RiskLevel.vermelho:
        return const Color(0xFFFEE2E2);
    }
  }

  Color get _fgColor {
    switch (level) {
      case RiskLevel.verde:
        return AppColors.success600;
      case RiskLevel.amarelo:
        return AppColors.warning600;
      case RiskLevel.vermelho:
        return AppColors.danger600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: AppTypography.numberMedium.copyWith(color: _fgColor),
          ),
          const SizedBox(height: 2),
          Text(
            level.label,
            style: AppTypography.labelSmall.copyWith(color: _fgColor),
          ),
        ],
      ),
    );
  }
}
