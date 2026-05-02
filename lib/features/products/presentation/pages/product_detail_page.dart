import 'package:flutter/material.dart';
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

    return Scaffold(
      backgroundColor: cs.surface,
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (p) {
          if (p == null) {
            return const Center(child: Text('Produto não encontrado'));
          }
          return CustomScrollView(
            slivers: [
              // ─── SliverAppBar com gradiente
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.brandPrimary600,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 18),
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 18),
                    ),
                    onPressed: () => context
                        .push('${AppRoutes.productForm}?id=$productId'),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.brandPrimary600,
                          AppColors.secondaryBlue600,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, 56, AppSpacing.lg, AppSpacing.lg),
                        child: Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.card),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.inventory_2_rounded,
                                  color: Colors.white, size: 36),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    p.name,
                                    style: AppTypography.headingMedium
                                        .copyWith(color: Colors.white),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if ((p.brand ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      p.brand!,
                                      style: AppTypography.bodyMedium
                                          .copyWith(
                                              color: Colors.white
                                                  .withValues(alpha: 0.8)),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _HeaderChip(p.unit),
                                  if (p.isPerishable)
                                        _HeaderChip('Perecível',
                                            icon: Icons.schedule_rounded,
                                            color: const Color(0xFFFFD580)),
                                      if ((p.barcode ?? '').isNotEmpty)
                                        _HeaderChip('Cód. barras',
                                            icon: Icons.qr_code_rounded),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Conteúdo
              SliverToBoxAdapter(
                child: batchesAsync.when(
                  loading: () => ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: 3,
                    itemBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: CasaCardSkeleton(),
                    ),
                  ),
                  error: (e, _) =>
                      Center(child: Text('Erro ao carregar lotes: $e')),
                  data: (batches) {
                    final totalQty = batches.fold<int>(
                        0, (sum, b) => sum + b.quantity);
                    final totalValue = batches.fold<double>(
                        0,
                        (sum, b) =>
                            sum +
                            ((b.unitPrice ?? 0) * b.quantity));
                    final expiring7 = batches
                        .where((b) => !b.noExpiry && b.daysToExpiry <= 7)
                        .length;
                    final expired = batches
                        .where((b) => b.isExpired)
                        .length;

                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ─── Painel de estatísticas rápidas
                          _StatsRow(
                            totalBatches: batches.length,
                            totalQty: totalQty,
                            totalValue: totalValue,
                            expiring7: expiring7,
                            expired: expired,
                            isDark: isDark,
                            cs: cs,
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // ─── Seção de informações do produto
                          CasaSectionHeader(
                            title: 'Informações',
                            action: 'Editar',
                            onAction: () => context.push(
                                '${AppRoutes.productForm}?id=$productId'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _ProductInfoCard(product: p, cs: cs, isDark: isDark),
                          const SizedBox(height: AppSpacing.lg),

                          // ─── Seção de lotes
                          CasaSectionHeader(
                            title: 'Lotes',
                            count: batches.length,
                            action: 'Novo Lote',
                            onAction: () => context.push(
                                '${AppRoutes.batchForm}?productId=$productId'),
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          if (batches.isEmpty)
                            CasaEmptyState(
                              icon: Icons.inbox_outlined,
                              title: 'Nenhum lote cadastrado',
                              description:
                                  'Cadastre o primeiro lote para controlar a validade.',
                              ctaLabel: 'Cadastrar Lote',
                              onCta: () => context.push(
                                  '${AppRoutes.batchForm}?productId=$productId'),
                            )
                          else
                            ...batches.map((b) => Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm),
                                  child: _BatchCard(
                                    batch: b,
                                    cs: cs,
                                    isDark: isDark,
                                    onMovement: () => context.push(
                                        '${AppRoutes.movement}?batchId=${b.id}'),
                                    onEdit: () => context.push(
                                        '${AppRoutes.batchForm}?id=${b.id}&productId=$productId'),
                                  ),
                                )),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('${AppRoutes.batchForm}?productId=$productId'),
        backgroundColor: AppColors.brandPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Lote'),
        elevation: 6,
      ),
    );
  }
}

// ─── Header chip ─────────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  const _HeaderChip(this.label, {this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white.withValues(alpha: 0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: c),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: c, fontWeight: FontWeight.w600)),
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
  final int expiring7;
  final int expired;
  final bool isDark;
  final ColorScheme cs;
  const _StatsRow(
      {required this.totalBatches,
      required this.totalQty,
      required this.totalValue,
      required this.expiring7,
      required this.expired,
      required this.isDark,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final currFmt =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    return Row(
      children: [
        _StatCard(
          label: 'Lotes',
          value: '$totalBatches',
          icon: Icons.layers_rounded,
          color: AppColors.brandPrimary600,
          cs: cs,
          isDark: isDark,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatCard(
          label: 'Itens',
          value: '$totalQty',
          icon: Icons.widgets_outlined,
          color: AppColors.secondaryBlue600,
          cs: cs,
          isDark: isDark,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatCard(
          label: 'Valor est.',
          value: currFmt.format(totalValue),
          icon: Icons.attach_money_rounded,
          color: AppColors.success600,
          cs: cs,
          isDark: isDark,
          flex: 2,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatCard(
          label: expired > 0 ? 'Vencidos' : 'Críticos',
          value: expired > 0 ? '$expired' : '$expiring7',
          icon: expired > 0
              ? Icons.cancel_outlined
              : Icons.warning_amber_rounded,
          color: expired > 0 ? AppColors.danger600 : AppColors.warning600,
          cs: cs,
          isDark: isDark,
        ),
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
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
              color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.headingSmall.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                  color: cs.onSurfaceVariant, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Informações do produto ───────────────────────────────────────────────

class _ProductInfoCard extends StatelessWidget {
  final Product product;
  final ColorScheme cs;
  final bool isDark;
  const _ProductInfoCard(
      {required this.product, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoDef>[
      if ((product.brand ?? '').isNotEmpty)
        _InfoDef(Icons.business_rounded, 'Marca', product.brand!),
      _InfoDef(Icons.category_outlined, 'Categoria', product.category.name),
      _InfoDef(Icons.straighten_rounded, 'Unidade', product.unit),
      if ((product.barcode ?? '').isNotEmpty)
        _InfoDef(Icons.qr_code_rounded, 'Código de Barras', product.barcode!),
      _InfoDef(
        product.isPerishable ? Icons.schedule_rounded : Icons.shield_outlined,
        'Tipo',
        product.isPerishable ? 'Perecível' : 'Não perecível',
      ),
      if (product.minimumStock > 0)
        _InfoDef(Icons.warning_amber_rounded, 'Estoque mínimo',
            '${product.minimumStock}'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  indent: 48),
            _InfoRow(def: rows[i], cs: cs),
          ],
        ],
      ),
    );
  }
}

class _InfoDef {
  final IconData icon;
  final String label;
  final String value;
  const _InfoDef(this.icon, this.label, this.value);
}

class _InfoRow extends StatelessWidget {
  final _InfoDef def;
  final ColorScheme cs;
  const _InfoRow({required this.def, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(def.icon,
                size: 16, color: AppColors.brandPrimary600),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.label,
                    style: AppTypography.labelSmall
                        .copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
                Text(def.value,
                    style: AppTypography.labelMedium
                        .copyWith(color: cs.onSurface)),
              ],
            ),
          ),
        ],
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
    final u = batch.daysToExpiry;
    if (u < 0) return AppColors.danger600;
    if (u <= 7) return AppColors.danger600;
    if (u <= 30) return AppColors.warning600;
    return AppColors.success600;
  }

  String _statusLabel() {
    if (batch.noExpiry) return 'Sem validade';
    final u = batch.daysToExpiry;
    if (u < 0) return 'Vencido';
    if (u <= 7) return 'Crítico';
    if (u <= 30) return 'Atenção';
    return 'OK';
  }

  IconData _statusIcon() {
    if (batch.noExpiry) return Icons.all_inclusive_rounded;
    final u = batch.daysToExpiry;
    if (u < 0) return Icons.cancel_outlined;
    if (u <= 7) return Icons.warning_rounded;
    if (u <= 30) return Icons.schedule_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final currFmt =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final statusColor = _statusColor();
    final days = batch.daysToExpiry;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: statusColor, width: 3),
          top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ─── Cabeçalho do lote
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(), size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(),
                        style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (!batch.noExpiry && days >= 0) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${days}d',
                    style: AppTypography.numberSmall.copyWith(
                        color: statusColor, fontWeight: FontWeight.w800),
                  ),
                ],
                const Spacer(),
                // Ações rápidas
                _ActionBtn(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Movimentar',
                  color: AppColors.brandPrimary600,
                  onTap: onMovement,
                ),
                const SizedBox(width: AppSpacing.xs),
                _ActionBtn(
                  icon: Icons.edit_outlined,
                  label: 'Editar',
                  color: cs.onSurfaceVariant,
                  onTap: onEdit,
                ),
              ],
            ),
          ),
          // ─── Grade de informações (2 colunas)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 4.5,
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.sm,
              children: [
                _BatchInfoCell(
                  icon: Icons.widgets_outlined,
                  label: 'Quantidade',
                  value: '${batch.quantity}',
                  cs: cs,
                ),
                if (batch.expiryDate != null && !batch.noExpiry)
                  _BatchInfoCell(
                    icon: Icons.event_rounded,
                    label: 'Validade',
                    value: fmt.format(batch.expiryDate!),
                    cs: cs,
                  ),
                if ((batch.batchNumber ?? '').isNotEmpty)
                  _BatchInfoCell(
                    icon: Icons.tag_rounded,
                    label: 'Nº Lote',
                    value: batch.batchNumber!,
                    cs: cs,
                  ),
                if (batch.unitPrice != null)
                  _BatchInfoCell(
                    icon: Icons.attach_money_rounded,
                    label: 'Preço unit.',
                    value: currFmt.format(batch.unitPrice!),
                    cs: cs,
                  ),
                if (batch.unitPrice != null)
                  _BatchInfoCell(
                    icon: Icons.calculate_outlined,
                    label: 'Total est.',
                    value:
                        currFmt.format(batch.unitPrice! * batch.quantity),
                    cs: cs,
                  ),
                if ((batch.shelfLocation ?? '').isNotEmpty)
                  _BatchInfoCell(
                    icon: Icons.location_on_outlined,
                    label: 'Localização',
                    value: batch.shelfLocation!,
                    cs: cs,
                  ),
                _BatchInfoCell(
                  icon: Icons.local_shipping_outlined,
                  label: 'Origem',
                  value: batch.origin,
                  cs: cs,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchInfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  const _BatchInfoCell(
      {required this.icon,
      required this.label,
      required this.value,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
              Text(
                value,
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
