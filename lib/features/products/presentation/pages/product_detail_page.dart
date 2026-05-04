import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../domain/entities/product.dart';
import '../controllers/products_provider.dart';

class ProductDetailPage extends ConsumerWidget {
  final String productId;
  const ProductDetailPage({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final batchesAsync = ref.watch(batchesByProductProvider(productId));
    final productAsync = ref.watch(productByIdProvider(productId));

    return productAsync.when(
      loading: () => Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: cs.surface,
        body: Center(child: Text('Erro: $e')),
      ),
      data: (p) {
        if (p == null) {
          return Scaffold(
            backgroundColor: cs.surface,
            appBar: AppBar(backgroundColor: cs.surface),
            body: const Center(child: Text('Produto nao encontrado')),
          );
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: cs.surface,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () =>
                  context.push('${AppRoutes.batchForm}?productId=$productId'),
              backgroundColor: AppColors.brandPrimary600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo Lote'),
              elevation: 4,
            ),
            body: batchesAsync.when(
              loading: () => CustomScrollView(
                slivers: [
                  _buildAppBar(context, p, cs, isDark),
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, __) => const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: CasaCardSkeleton(),
                        ),
                        childCount: 4,
                      ),
                    ),
                  ),
                ],
              ),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (batches) {
                final totalQty =
                    batches.fold<int>(0, (s, b) => s + b.quantity);
                final totalValue = batches.fold<double>(
                    0, (s, b) => s + ((b.unitPrice ?? 0) * b.quantity));
                final critical = batches
                    .where((b) =>
                        !b.noExpiry && b.daysToExpiry <= 7 && !b.isExpired)
                    .length;
                final expired =
                    batches.where((b) => b.isExpired).length;

                return CustomScrollView(
                  slivers: [
                    _buildAppBar(context, p, cs, isDark),
                    SliverToBoxAdapter(
                      child: _ProductInfoSection(
                          product: p, cs: cs, isDark: isDark),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                      sliver: SliverToBoxAdapter(
                        child: _StatsRow(
                          totalBatches: batches.length,
                          totalQty: totalQty,
                          totalValue: totalValue,
                          critical: critical,
                          expired: expired,
                          cs: cs,
                          isDark: isDark,
                          minimumStock: p.minimumStock,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                      sliver: SliverToBoxAdapter(
                        child: CasaSectionHeader(
                          title: 'Lotes em Estoque',
                          count: batches.length,
                          action: 'Novo Lote',
                          onAction: () => context.push(
                              '${AppRoutes.batchForm}?productId=$productId'),
                        ),
                      ),
                    ),
                    if (batches.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, 120),
                        sliver: SliverToBoxAdapter(
                          child: CasaEmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Nenhum lote cadastrado',
                            description:
                                'Cadastre o primeiro lote para controlar a validade.',
                            ctaLabel: 'Cadastrar Lote',
                            onCta: () => context.push(
                                '${AppRoutes.batchForm}?productId=$productId'),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 0, AppSpacing.lg, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md),
                              child: _BatchCard(
                                batch: batches[i],
                                cs: cs,
                                isDark: isDark,
                                onMovement: () => context.push(
                                    '${AppRoutes.movement}?batchId=${batches[i].id}'),
                                onEdit: () => context.push(
                                    '${AppRoutes.batchForm}?id=${batches[i].id}&productId=$productId'),
                              ),
                            ),
                            childCount: batches.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(
      BuildContext context, Product p, ColorScheme cs, bool isDark) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.brandPrimary700,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              p.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  fontFamily: AppTypography.fontPoppins),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.push('${AppRoutes.productForm}?id=$productId'),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1),
              ),
              child: const Icon(Icons.edit_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        stretchModes: const [StretchMode.zoomBackground],
        titlePadding: EdgeInsets.zero,
        background: _AppBarBackground(p: p),
      ),
    );
  }
}

// ─── App Bar Background ────────────────────────────────────────────────────

class _AppBarBackground extends StatelessWidget {
  final Product p;
  const _AppBarBackground({required this.p});

  IconData _categoryIcon() => switch (p.category) {
        ProductCategory.alimento => Icons.restaurant_rounded,
        ProductCategory.bebida => Icons.local_drink_rounded,
        ProductCategory.limpeza => Icons.cleaning_services_rounded,
        ProductCategory.higienePessoal => Icons.soap_rounded,
        ProductCategory.escolar => Icons.school_rounded,
        ProductCategory.roupas => Icons.checkroom_rounded,
        ProductCategory.outro => Icons.inventory_2_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandPrimary800, AppColors.secondaryBlue600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -40,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: 10,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 60, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Product image / icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14.5),
                                child: Image.network(p.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                        _categoryIcon(),
                                        color: Colors.white,
                                        size: 32)),
                              )
                            : Icon(_categoryIcon(),
                                color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((p.brand ?? '').isNotEmpty)
                              Container(
                                margin:
                                    const EdgeInsets.only(bottom: AppSpacing.xs),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  p.brand!.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0),
                                ),
                              ),
                            Text(
                              p.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                fontFamily: AppTypography.fontPoppins,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: [
                                _HChip(p.unit,
                                    icon: Icons.straighten_rounded),
                                _HChip(p.categoryLabel,
                                    icon: Icons.category_outlined,
                                    color: const Color(0xFFB8D4FF)),
                                if (p.isPerishable)
                                  _HChip('Perecível',
                                      icon: Icons.schedule_rounded,
                                      color: const Color(0xFFFFD580))
                                else
                                  _HChip('Não perecível',
                                      icon: Icons.shield_outlined,
                                      color: const Color(0xFFA7F3D0)),
                                if (p.minimumStock > 0)
                                  _HChip(
                                      'Estoque mín: ${p.minimumStock}',
                                      icon: Icons.warning_amber_rounded,
                                      color: const Color(0xFFFFD580)),
                                if ((p.barcode ?? '').isNotEmpty)
                                  _HChip(p.barcode!,
                                      icon: Icons.qr_code_rounded,
                                      color: Colors.white70),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header chip compacto ─────────────────────────────────────────────────

class _HChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  const _HChip(this.label, {this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white.withValues(alpha: 0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: c),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Product info section ─────────────────────────────────────────────────

class _ProductInfoSection extends StatelessWidget {
  final Product product;
  final ColorScheme cs;
  final bool isDark;
  const _ProductInfoSection(
      {required this.product, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if ((product.description ?? '').isEmpty) return const SizedBox(height: AppSpacing.lg);
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline_rounded,
                size: 16, color: AppColors.brandPrimary600),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Descrição',
                    style: AppTypography.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  product.description!,
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurface, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int totalBatches;
  final int totalQty;
  final double totalValue;
  final int critical;
  final int expired;
  final int minimumStock;
  final ColorScheme cs;
  final bool isDark;
  const _StatsRow({
    required this.totalBatches,
    required this.totalQty,
    required this.totalValue,
    required this.critical,
    required this.expired,
    required this.minimumStock,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

    // Stock health
    Color stockColor;
    String stockLabel;
    IconData stockIcon;
    if (expired > 0) {
      stockColor = AppColors.danger600;
      stockLabel = '$expired Vencido${expired > 1 ? 's' : ''}';
      stockIcon = Icons.cancel_outlined;
    } else if (critical > 0) {
      stockColor = AppColors.warning600;
      stockLabel = '$critical Crítico${critical > 1 ? 's' : ''}';
      stockIcon = Icons.warning_amber_rounded;
    } else if (minimumStock > 0 && totalQty < minimumStock) {
      stockColor = AppColors.warning600;
      stockLabel = 'Abaixo do mín.';
      stockIcon = Icons.trending_down_rounded;
    } else {
      stockColor = AppColors.success600;
      stockLabel = 'Em dia';
      stockIcon = Icons.check_circle_outline_rounded;
    }

    return Column(
      children: [
        Row(
          children: [
            _StatCard(
                label: 'Lotes',
                value: '$totalBatches',
                icon: Icons.layers_rounded,
                color: AppColors.brandPrimary600,
                cs: cs,
                isDark: isDark),
            const SizedBox(width: AppSpacing.sm),
            _StatCard(
                label: 'Unidades',
                value: '$totalQty',
                icon: Icons.widgets_outlined,
                color: AppColors.secondaryBlue600,
                cs: cs,
                isDark: isDark),
            const SizedBox(width: AppSpacing.sm),
            _StatCard(
                label: 'Valor est.',
                value: currFmt.format(totalValue),
                icon: Icons.attach_money_rounded,
                color: AppColors.success600,
                cs: cs,
                isDark: isDark,
                flex: 2),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Stock status banner
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: stockColor.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: stockColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(stockIcon, size: 16, color: stockColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  minimumStock > 0
                      ? 'Status: $stockLabel  ·  Mínimo: $minimumStock un.'
                      : 'Status: $stockLabel',
                  style: AppTypography.labelSmall.copyWith(
                      color: stockColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;
  final bool isDark;
  final int flex;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.cs,
      required this.isDark,
      this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(value,
                style: AppTypography.headingSmall.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ─── Card de lote ─────────────────────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onMovement;
  final VoidCallback onEdit;
  const _BatchCard(
      {required this.batch,
      required this.cs,
      required this.isDark,
      required this.onMovement,
      required this.onEdit});

  Color _statusColor() {
    if (batch.noExpiry) return AppColors.success600;
    if (batch.isExpired) return AppColors.danger600;
    final u = batch.daysToExpiry;
    if (u <= 7) return AppColors.danger600;
    if (u <= 30) return AppColors.warning600;
    return AppColors.success600;
  }

  String _statusLabel() {
    if (batch.noExpiry) return 'Sem validade';
    if (batch.isExpired) return 'Vencido';
    final u = batch.daysToExpiry;
    if (u <= 7) return 'Crítico';
    if (u <= 30) return 'Atenção';
    return 'OK';
  }

  IconData _statusIcon() {
    if (batch.noExpiry) return Icons.all_inclusive_rounded;
    if (batch.isExpired) return Icons.cancel_outlined;
    final u = batch.daysToExpiry;
    if (u <= 7) return Icons.warning_rounded;
    if (u <= 30) return Icons.schedule_rounded;
    return Icons.check_circle_outline_rounded;
  }

  String _originLabel() => switch (batch.origin) {
        'doacao' => 'Doação',
        'compra' => 'Compra',
        'parceiro' => 'Parceiro',
        'transferencia' => 'Transferência',
        _ => batch.origin,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final currFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final sc = _statusColor();
    final days = batch.daysToExpiry;
    final pct = batch.initialQuantity > 0
        ? (batch.quantity / batch.initialQuantity).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card + 2),
        border: Border(
          left: BorderSide(color: sc, width: 4),
          top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.8),
          right: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.8),
          bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: status badge + qty + actions ────────────────
                Row(
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sc,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(),
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(_statusLabel(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                          if (!batch.noExpiry && !batch.isExpired) ...[
                            const SizedBox(width: 4),
                            Text('· ${days}d',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Qty badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sc.withValues(
                            alpha: isDark ? 0.2 : 0.1),
                        borderRadius:
                            BorderRadius.circular(AppRadius.small),
                        border: Border.all(
                            color: sc.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.widgets_outlined,
                              size: 12, color: sc),
                          const SizedBox(width: 4),
                          Text('${batch.quantity} un.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // Edit button
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainer,
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                          border: Border.all(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Icon(Icons.edit_outlined,
                            size: 14,
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),

                // ── Quantity progress bar ──────────────────────────────
                if (batch.initialQuantity > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor: cs.outlineVariant
                                .withValues(alpha: 0.2),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(sc),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${(pct * 100).round()}%',
                        style: AppTypography.labelSmall.copyWith(
                            color: sc,
                            fontWeight: FontWeight.w700,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ],

                // ── Expiry date ────────────────────────────────────────
                if (!batch.noExpiry) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 6),
                    decoration: BoxDecoration(
                      color: sc.withValues(
                          alpha: isDark ? 0.18 : 0.07),
                      borderRadius:
                          BorderRadius.circular(AppRadius.small),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_rounded,
                            size: 13, color: sc),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          batch.isExpired
                              ? 'Vencido em ${batch.expiryDate != null ? fmt.format(batch.expiryDate!) : '?'}'
                              : batch.expiryDate != null
                                  ? '${fmt.format(batch.expiryDate!)}  ·  $days dia${days == 1 ? '' : 's'}'
                                  : '-',
                          style: TextStyle(
                              fontSize: 12,
                              color: sc,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Metadata chips ─────────────────────────────────────
                if (batch.origin.isNotEmpty ||
                    (batch.batchNumber ?? '').isNotEmpty ||
                    (batch.shelfLocation ?? '').isNotEmpty ||
                    batch.unitPrice != null ||
                    (batch.imageUrl ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.25)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (batch.origin.isNotEmpty)
                        _MChip(
                            icon: Icons.local_shipping_outlined,
                            label: _originLabel(),
                            cs: cs),
                      if ((batch.batchNumber ?? '').isNotEmpty)
                        _MChip(
                            icon: Icons.tag_rounded,
                            label: 'Lote ${batch.batchNumber!}',
                            cs: cs),
                      if ((batch.shelfLocation ?? '').isNotEmpty)
                        _MChip(
                            icon: Icons.location_on_rounded,
                            label: batch.shelfLocation!,
                            cs: cs,
                            accent: AppColors.secondaryBlue600),
                      if (batch.unitPrice != null)
                        _MChip(
                            icon: Icons.attach_money_rounded,
                            label:
                                '${currFmt.format(batch.unitPrice!)}/un',
                            cs: cs,
                            accent: AppColors.success600),
                    ],
                  ),
                ],

                // ── Notes ─────────────────────────────────────────────
                if ((batch.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_rounded,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(batch.notes!,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                                fontStyle: FontStyle.italic)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Move button ───────────────────────────────────────────────
          InkWell(
            onTap: onMovement,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppRadius.card + 2),
              bottomRight: Radius.circular(AppRadius.card + 2),
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.card + 2),
                  bottomRight: Radius.circular(AppRadius.card + 2),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz_rounded,
                      size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Movimentar',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Meta chip ────────────────────────────────────────────────────────────

class _MChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final Color? accent;
  const _MChip(
      {required this.icon, required this.label, required this.cs, this.accent});

  @override
  Widget build(BuildContext context) {
    final c = accent ?? cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
