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

        return Scaffold(
          backgroundColor: cs.surface,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                context.push('${AppRoutes.batchForm}?productId=$productId'),
            backgroundColor: AppColors.brandPrimary600,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo Lote'),
            elevation: 6,
          ),
          body: batchesAsync.when(
            loading: () => CustomScrollView(
              slivers: [
                _buildAppBar(context, p, cs),
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
                  _buildAppBar(context, p, cs),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.md, AppSpacing.lg, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _StatsRow(
                          totalBatches: batches.length,
                          totalQty: totalQty,
                          totalValue: totalValue,
                          critical: critical,
                          expired: expired,
                          cs: cs,
                        ),
                        const SizedBox(height: AppSpacing.lg),
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
                                    bottom: AppSpacing.md),
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
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(
      BuildContext context, Product p, ColorScheme cs) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: AppColors.brandPrimary600,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
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
                  fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.push('${AppRoutes.productForm}?id=$productId'),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        titlePadding: EdgeInsets.zero,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 56, AppSpacing.lg, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      // Icone / imagem
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.card - 1),
                                child: Image.network(p.imageUrl!, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.inventory_2_rounded,
                                color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if ((p.brand ?? '').isNotEmpty)
                              Text(
                                p.brand!,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11),
                              ),
                            if ((p.barcode ?? '').isNotEmpty)
                              Row(children: [
                                Icon(Icons.qr_code_rounded, size: 10,
                                    color: Colors.white.withValues(alpha: 0.6)),
                                const SizedBox(width: 3),
                                Text(p.barcode!,
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 10, letterSpacing: 0.5)),
                              ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: [
                      _HChip(p.unit),
                      _HChip(p.category.name,
                          icon: Icons.category_outlined,
                          color: const Color(0xFFB8D4FF)),
                      if (p.isPerishable)
                        _HChip('Perecivel',
                            icon: Icons.schedule_rounded,
                            color: const Color(0xFFFFD580))
                      else
                        _HChip('Nao perecivel',
                            icon: Icons.shield_outlined,
                            color: const Color(0xFFA7F3D0)),
                      if (p.minimumStock > 0)
                        _HChip('Min: ${p.minimumStock}',
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFFFD580)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
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

// ─── Stats row ────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int totalBatches;
  final int totalQty;
  final double totalValue;
  final int critical;
  final int expired;
  final ColorScheme cs;
  const _StatsRow(
      {required this.totalBatches,
      required this.totalQty,
      required this.totalValue,
      required this.critical,
      required this.expired,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final alertCount = expired > 0 ? expired : critical;
    final alertLabel = expired > 0 ? 'Vencidos' : 'Criticos';
    final alertColor =
        expired > 0 ? AppColors.danger600 : AppColors.warning600;
    final alertIcon = expired > 0
        ? Icons.cancel_outlined
        : Icons.warning_amber_rounded;

    return Row(
      children: [
        _StatCard(label: 'Lotes', value: '$totalBatches',
            icon: Icons.layers_rounded, color: AppColors.brandPrimary600, cs: cs),
        const SizedBox(width: AppSpacing.sm),
        _StatCard(label: 'Itens', value: '$totalQty',
            icon: Icons.widgets_outlined, color: AppColors.secondaryBlue600, cs: cs),
        const SizedBox(width: AppSpacing.sm),
        _StatCard(label: 'Valor est.', value: currFmt.format(totalValue),
            icon: Icons.attach_money_rounded, color: AppColors.success600, cs: cs, flex: 2),
        const SizedBox(width: AppSpacing.sm),
        _StatCard(label: alertLabel, value: '$alertCount',
            icon: alertIcon, color: alertColor, cs: cs),
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
  final int flex;
  const _StatCard(
      {required this.label, required this.value, required this.icon,
      required this.color, required this.cs, this.flex = 1});

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
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: AppTypography.headingSmall.copyWith(
                    color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
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
      {required this.batch, required this.cs, required this.isDark,
      required this.onMovement, required this.onEdit});

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
    if (u <= 7) return 'Critico';
    if (u <= 30) return 'Atencao';
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
        'doacao' => 'Doacao',
        'compra' => 'Compra',
        'parceiro' => 'Parceiro',
        'transferencia' => 'Transferencia',
        _ => batch.origin,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final currFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final sc = _statusColor();
    final days = batch.daysToExpiry;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: sc, width: 4),
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + qty + edit
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sc,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(), size: 12, color: Colors.white),
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
                // Quantidade em destaque
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: sc.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.widgets_outlined, size: 12, color: sc),
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
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Icon(Icons.edit_outlined,
                        size: 14, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),

            // Data de validade
            if (!batch.noExpiry) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_rounded, size: 13, color: sc),
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

            // Metadados
            if (batch.origin.isNotEmpty ||
                (batch.batchNumber ?? '').isNotEmpty ||
                (batch.shelfLocation ?? '').isNotEmpty ||
                batch.unitPrice != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (batch.origin.isNotEmpty)
                    _MChip(icon: Icons.local_shipping_outlined,
                        label: _originLabel(), cs: cs),
                  if ((batch.batchNumber ?? '').isNotEmpty)
                    _MChip(icon: Icons.tag_rounded,
                        label: 'Lote ${batch.batchNumber!}', cs: cs),
                  if ((batch.shelfLocation ?? '').isNotEmpty)
                    _MChip(icon: Icons.location_on_rounded,
                        label: batch.shelfLocation!, cs: cs,
                        accent: AppColors.secondaryBlue600),
                  if (batch.unitPrice != null)
                    _MChip(icon: Icons.attach_money_rounded,
                        label: '${currFmt.format(batch.unitPrice!)}/un', cs: cs,
                        accent: AppColors.success600),
                ],
              ),
            ],

            // Notas
            if ((batch.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 12, color: cs.onSurfaceVariant),
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

            // Botao movimentar
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: onMovement,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 15, color: Colors.white),
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