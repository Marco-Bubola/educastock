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
            body: const Center(child: Text('Produto não encontrado')),
          );
        }

        return Scaffold(
          backgroundColor: cs.surface,
          // ─── AppBar: voltar | nome | editar na mesma linha
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: _ProductAppBar(
              product: p,
              productId: productId,
              context: context,
            ),
          ),
          body: SafeArea(
            child: batchesAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: 4,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm),
                  child: CasaCardSkeleton(),
                ),
              ),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (batches) {
                final totalQty =
                    batches.fold<int>(0, (s, b) => s + b.quantity);
                final totalValue = batches.fold<double>(
                    0, (s, b) => s + ((b.unitPrice ?? 0) * b.quantity));
                final critical = batches
                    .where((b) => !b.noExpiry && b.daysToExpiry <= 7 && !b.isExpired)
                    .length;
                final expired =
                    batches.where((b) => b.isExpired).length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
                  children: [
                    // ─── Stats row
                    _StatsRow(
                      totalBatches: batches.length,
                      totalQty: totalQty,
                      totalValue: totalValue,
                      critical: critical,
                      expired: expired,
                      cs: cs,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ─── Informações do produto
                    CasaSectionHeader(
                      title: 'Informações',
                      action: 'Editar',
                      onAction: () => context.push(
                          '${AppRoutes.productForm}?id=$productId'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ProductInfoCard(
                        product: p, cs: cs, isDark: isDark),
                    const SizedBox(height: AppSpacing.lg),

                    // ─── Lotes
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
                  ],
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context
                .push('${AppRoutes.batchForm}?productId=$productId'),
            backgroundColor: AppColors.brandPrimary600,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo Lote'),
            elevation: 6,
          ),
        );
      },
    );
  }
}

// ─── AppBar personalizada ─────────────────────────────────────────────────

class _ProductAppBar extends StatelessWidget {
  final Product product;
  final String productId;
  final BuildContext context;
  const _ProductAppBar(
      {required this.product,
      required this.productId,
      required this.context});

  @override
  Widget build(BuildContext buildContext) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ─── Linha principal: ← | ícone + nome | ✏️
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Row(
                children: [
                  // Botão voltar
                  IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 18),
                    ),
                    onPressed: () => context.pop(),
                  ),
                  // Ícone do produto
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: product.imageUrl != null &&
                            (product.imageUrl!).isNotEmpty
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
                            child: Image.network(product.imageUrl!,
                                fit: BoxFit.cover),
                          )
                        : const Icon(Icons.inventory_2_rounded,
                            color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Nome + marca
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          style: AppTypography.headingSmall
                              .copyWith(color: Colors.white, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((product.brand ?? '').isNotEmpty)
                          Text(
                            product.brand!,
                            style: AppTypography.bodySmall.copyWith(
                                color:
                                    Colors.white.withValues(alpha: 0.75)),
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                  // Botão editar
                  IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
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
              ),
            ),
            // ─── Chips de atributos
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _HeaderChip(product.unit),
                    const SizedBox(width: 6),
                    _HeaderChip(
                      product.category.name,
                      icon: Icons.category_outlined,
                      color: const Color(0xFFB8D4FF),
                    ),
                    const SizedBox(width: 6),
                    if (product.isPerishable)
                      _HeaderChip('Perecível',
                          icon: Icons.schedule_rounded,
                          color: const Color(0xFFFFD580))
                    else
                      _HeaderChip('Não perecível',
                          icon: Icons.shield_outlined,
                          color: const Color(0xFFA7F3D0)),
                    if ((product.barcode ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _HeaderChip('Cód. barras',
                          icon: Icons.qr_code_rounded),
                    ],
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
    final alertLabel = expired > 0 ? 'Vencidos' : 'Críticos';
    final alertColor =
        expired > 0 ? AppColors.danger600 : AppColors.warning600;
    final alertIcon = expired > 0
        ? Icons.cancel_outlined
        : Icons.warning_amber_rounded;

    return Row(
      children: [
        _StatCard(
          label: 'Lotes',
          value: '$totalBatches',
          icon: Icons.layers_rounded,
          color: AppColors.brandPrimary600,
          cs: cs,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatCard(
          label: 'Itens',
          value: '$totalQty',
          icon: Icons.widgets_outlined,
          color: AppColors.secondaryBlue600,
          cs: cs,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatCard(
          label: 'Valor est.',
          value: currFmt.format(totalValue),
          icon: Icons.attach_money_rounded,
          color: AppColors.success600,
          cs: cs,
          flex: 2,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatCard(
          label: alertLabel,
          value: '$alertCount',
          icon: alertIcon,
          color: alertColor,
          cs: cs,
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
  final int flex;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      required this.cs,
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
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)
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
                  fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
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
      if ((product.barcode ?? '').isNotEmpty)
        _InfoDef(
            Icons.qr_code_rounded, 'Código de Barras', product.barcode!),
      if (product.minimumStock > 0)
        _InfoDef(Icons.warning_amber_rounded, 'Estoque mínimo',
            '${product.minimumStock}'),
      if ((product.description ?? '').isNotEmpty)
        _InfoDef(Icons.notes_rounded, 'Descrição', product.description!),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
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
    final currFmt =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final statusColor = _statusColor();
    final days = batch.daysToExpiry;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
          top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Cabeçalho: status + dias + ações
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(), size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        _statusLabel(),
                        style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w700),
                      ),
                      if (!batch.noExpiry && !batch.isExpired) ...[
                        const SizedBox(width: 4),
                        Text(
                          '· ${days}d',
                          style: TextStyle(
                              fontSize: 11,
                              color: statusColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
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

          // ─── Destaque de vencimento / sem validade
          if (!batch.noExpiry) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded,
                        size: 16, color: statusColor),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      batch.isExpired
                          ? 'Vencido em ${batch.expiryDate != null ? fmt.format(batch.expiryDate!) : '?'}'
                          : batch.expiryDate != null
                              ? 'Vence em ${fmt.format(batch.expiryDate!)}  •  $days dia${days == 1 ? '' : 's'} restante${days == 1 ? '' : 's'}'
                              : 'Sem data de vencimento',
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ─── Informações principais
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: Column(
              children: [
                // Quantidade + Localização (linha de destaque)
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.widgets_outlined,
                      label: '${batch.quantity} ${_unitSuffix()}',
                      color: AppColors.brandPrimary600,
                      cs: cs,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if ((batch.shelfLocation ?? '').isNotEmpty)
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.location_on_rounded,
                          label: batch.shelfLocation!,
                          color: AppColors.secondaryBlue600,
                          cs: cs,
                        ),
                      )
                    else
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.location_off_outlined,
                          label: 'Sem localização',
                          color: cs.onSurfaceVariant,
                          cs: cs,
                          muted: true,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Linha 2: origem + nº lote
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.local_shipping_outlined,
                      label: _originLabel(),
                      color: AppColors.neutral500,
                      cs: cs,
                      muted: true,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if ((batch.batchNumber ?? '').isNotEmpty)
                      _InfoChip(
                        icon: Icons.tag_rounded,
                        label: 'Lote ${batch.batchNumber!}',
                        color: AppColors.neutral500,
                        cs: cs,
                        muted: true,
                      ),
                  ],
                ),
                // Linha 3: preço (se houver)
                if (batch.unitPrice != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.attach_money_rounded,
                        label:
                            '${currFmt.format(batch.unitPrice!)}/un',
                        color: AppColors.success600,
                        cs: cs,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _InfoChip(
                        icon: Icons.calculate_outlined,
                        label:
                            'Total: ${currFmt.format(batch.unitPrice! * batch.quantity)}',
                        color: AppColors.success600,
                        cs: cs,
                      ),
                    ],
                  ),
                ],
                // Notas
                if ((batch.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            batch.notes!,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _unitSuffix() => '';
}

// ─── Info chip inline ─────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ColorScheme cs;
  final bool muted;
  const _InfoChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.cs,
      this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: muted
            ? cs.surfaceContainer
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13, color: muted ? cs.onSurfaceVariant : color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: muted ? cs.onSurfaceVariant : color,
              fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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


