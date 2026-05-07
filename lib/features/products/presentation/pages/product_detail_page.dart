// REWRITTEN - product_detail_page.dart
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
          backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
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
              final expired = batches.where((b) => b.isExpired).length;

              return CustomScrollView(
                slivers: [
                  _buildAppBar(context, p, cs, isDark),
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
                          isDark: isDark,
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
                                  isDark: isDark,
                                  onEdit: () => context.push(
                                      '${AppRoutes.batchForm}?id=${b.id}&productId=$productId'),
                                  onDelete: () => _confirmDelete(context, ref, b),
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

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Batch b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteConfirmDialog(batch: b),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(deleteBatchProvider.notifier).deleteBatch(b.id);
    }
  }

  SliverAppBar _buildAppBar(
      BuildContext context, Product p, ColorScheme cs, bool isDark) {
    return SliverAppBar(
      expandedHeight: 155,
      pinned: true,
      backgroundColor: AppColors.brandPrimary600,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _NavButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => context.pop(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                p.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _NavButton(
              icon: Icons.edit_rounded,
              onTap: () =>
                  context.push('${AppRoutes.productForm}?id=$productId'),
            ),
          ],
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        titlePadding: EdgeInsets.zero,
        background: Stack(
          children: [
            // Gradient base
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1348A0), Color(0xFF1D5FA8), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Círculos decorativos
            Positioned(
              right: -30,
              top: -20,
              child: Container(
                width: 130,
                height: 130,
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            // Conteúdo
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 52, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar do produto
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.25),
                                Colors.white.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1),
                          ),
                          child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(p.imageUrl!,
                                      fit: BoxFit.cover),
                                )
                              : const Icon(Icons.inventory_2_rounded,
                                  color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((p.brand ?? '').isNotEmpty)
                                Text(
                                  p.brand!.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              if ((p.barcode ?? '').isNotEmpty)
                                Row(children: [
                                  Icon(Icons.qr_code_rounded,
                                      size: 9,
                                      color:
                                          Colors.white.withValues(alpha: 0.5)),
                                  const SizedBox(width: 3),
                                  Text(p.barcode!,
                                      style: TextStyle(
                                          color:
                                              Colors.white.withValues(alpha: 0.5),
                                          fontSize: 9,
                                          letterSpacing: 0.5)),
                                ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        _HChip(p.unit),
                        _HChip(p.category.name,
                            icon: Icons.category_outlined,
                            color: const Color(0xFFBAD4FF)),
                        if (p.isPerishable)
                          _HChip('Perecivel',
                              icon: Icons.schedule_rounded,
                              color: const Color(0xFFFFE0A0))
                        else
                          _HChip('Nao perecivel',
                              icon: Icons.shield_outlined,
                              color: const Color(0xFFA7F3D0)),
                        if (p.minimumStock > 0)
                          _HChip('Min: ${p.minimumStock}',
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFFFE0A0)),
                      ],
                    ),
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

// ─── Botão de navegação ────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

// ─── Header chip ──────────────────────────────────────────────────────────

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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: c),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 9, color: c, fontWeight: FontWeight.w600)),
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
  final bool isDark;
  const _StatsRow(
      {required this.totalBatches,
      required this.totalQty,
      required this.totalValue,
      required this.critical,
      required this.expired,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final alertCount = expired > 0 ? expired : critical;
    final alertLabel = expired > 0 ? 'Vencidos' : 'Criticos';
    final alertColor = expired > 0
        ? const Color(0xFFF87171)
        : const Color(0xFFFBBF24);
    final alertIcon =
        expired > 0 ? Icons.cancel_rounded : Icons.warning_amber_rounded;

    return Row(
      children: [
        _StatCard(
          label: 'Lotes',
          value: '$totalBatches',
          icon: Icons.layers_rounded,
          color: const Color(0xFF60A5FA),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Itens',
          value: '$totalQty',
          icon: Icons.widgets_outlined,
          color: const Color(0xFF818CF8),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Valor',
          value: currFmt.format(totalValue),
          icon: Icons.attach_money_rounded,
          color: const Color(0xFF4ADE80),
          isDark: isDark,
          flex: 2,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: alertLabel,
          value: '$alertCount',
          icon: alertIcon,
          color: alertColor,
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
  final bool isDark;
  final int flex;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.isDark,
      this.flex = 1});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF111827) : Colors.white;
    final onBg = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: isDark ? 0.2 : 0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.08 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: onBg,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  color: sub,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Modal de confirmação de exclusão ─────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  final Batch batch;
  const _DeleteConfirmDialog({required this.batch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111827) : Colors.white;
    final onBg = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFF87171).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF87171).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFF87171).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFF87171), size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              'Excluir Lote',
              style: TextStyle(
                color: onBg,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Esta acao nao pode ser desfeita.\nTem certeza que deseja excluir este lote?',
              textAlign: TextAlign.center,
              style: TextStyle(color: sub, fontSize: 13, height: 1.4),
            ),
            if ((batch.batchNumber ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF87171).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFF87171).withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Lote ${batch.batchNumber!}  ·  ${batch.quantity} unidades',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Cancelar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sub,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Excluir',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card de lote ─────────────────────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BatchCard(
      {required this.batch,
      required this.isDark,
      required this.onEdit,
      required this.onDelete});

  Color _statusColor() {
    if (batch.noExpiry) return const Color(0xFF34D399);
    if (batch.isExpired) return const Color(0xFFF87171);
    final u = batch.daysToExpiry;
    if (u <= 7) return const Color(0xFFF87171);
    if (u <= 30) return const Color(0xFFFBBF24);
    return const Color(0xFF34D399);
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
    if (batch.isExpired) return Icons.cancel_rounded;
    final u = batch.daysToExpiry;
    if (u <= 7) return Icons.warning_amber_rounded;
    if (u <= 30) return Icons.schedule_rounded;
    return Icons.check_circle_rounded;
  }

  String _originLabel() => switch (batch.origin) {
        'doacao' => 'Doacao',
        'compra' => 'Compra',
        'parceiro' => 'Parceiro',
        'transferencia' => 'Transf.',
        _ => batch.origin,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final currFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final sc = _statusColor();
    final days = batch.daysToExpiry;

    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final headerBg = sc.withValues(alpha: isDark ? 0.1 : 0.06);
    final borderColor = sc.withValues(alpha: isDark ? 0.25 : 0.18);
    final labelColor = sc;
    final onCard = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final onCardSub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: sc.withValues(alpha: isDark ? 0.08 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── HEADER ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(
                  bottom: BorderSide(
                      color: sc.withValues(alpha: isDark ? 0.15 : 0.1))),
            ),
            child: Row(
              children: [
                // Dot + ícone + label
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: sc,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: sc.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1)
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Icon(_statusIcon(), size: 13, color: labelColor),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(),
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (!batch.noExpiry) ...[
                  Text('  ·  ',
                      style: TextStyle(color: onCardSub, fontSize: 11)),
                  Expanded(
                    child: Text(
                      batch.isExpired
                          ? 'Vencido ${batch.expiryDate != null ? fmt.format(batch.expiryDate!) : ''}'
                          : batch.expiryDate != null
                              ? '${fmt.format(batch.expiryDate!)} ($days d)'
                              : 'Sem data',
                      style: TextStyle(
                          color: onCardSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                // Quantidade pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: isDark ? 0.15 : 0.09),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sc.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    '${batch.quantity} un.',
                    style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                // Editar
                _ActionBtn(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFF60A5FA),
                  isDark: isDark,
                  onTap: onEdit,
                ),
                const SizedBox(width: 4),
                // Excluir
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFF87171),
                  isDark: isDark,
                  onTap: onDelete,
                ),
              ],
            ),
          ),

          // ── CORPO ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    if (batch.origin.isNotEmpty)
                      _InfoChip(
                          icon: Icons.local_shipping_outlined,
                          label: _originLabel(),
                          color: const Color(0xFF818CF8),
                          isDark: isDark),
                    if ((batch.batchNumber ?? '').isNotEmpty)
                      _InfoChip(
                          icon: Icons.tag_rounded,
                          label: batch.batchNumber!,
                          color: const Color(0xFFA78BFA),
                          isDark: isDark),
                    if ((batch.shelfLocation ?? '').isNotEmpty)
                      _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: batch.shelfLocation!,
                          color: const Color(0xFF38BDF8),
                          isDark: isDark),
                    if (batch.unitPrice != null)
                      _InfoChip(
                          icon: Icons.attach_money_rounded,
                          label: currFmt.format(batch.unitPrice!),
                          color: const Color(0xFF4ADE80),
                          isDark: isDark),
                  ],
                ),
                if ((batch.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_rounded, size: 11, color: onCardSub),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          batch.notes!,
                          style: TextStyle(
                            fontSize: 10,
                            color: onCardSub,
                            fontStyle: FontStyle.italic,
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

// ─── Action button (edit/delete) ──────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.13 : 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: isDark ? 0.25 : 0.2)),
        ),
        child: Icon(icon, size: 12, color: color),
      ),
    );
  }
}

// ─── Info chip ─────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.22 : 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.75)
                  : const Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
