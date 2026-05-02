import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../controllers/scanner_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_provider.dart';

class ProductReviewPage extends ConsumerStatefulWidget {
  final String barcode;
  const ProductReviewPage({super.key, required this.barcode});

  @override
  ConsumerState<ProductReviewPage> createState() => _ProductReviewPageState();
}

class _ProductReviewPageState extends ConsumerState<ProductReviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scannerProvider.notifier).onBarcodeDetected(widget.barcode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scanState = ref.watch(scannerProvider);
    final localProductAsync =
        ref.watch(productByBarcodeProvider(widget.barcode));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: const ModernProfileAppBar(
          title: 'Revisão de Dados',
          subtitle: 'Confirme as informações do produto',
          showBackButton: true,
        ),
        body: SafeArea(
          child: localProductAsync.when(
            loading: () => _buildLoading(cs, 'Verificando produto...'),
            error: (e, _) => _buildError(cs, e.toString()),
            data: (product) {
              if (product != null) {
                return _ProductFoundView(
                  product: product,
                  barcode: widget.barcode,
                  cs: cs,
                  isDark: isDark,
                );
              }
              return _ApiSearchView(
                barcode: widget.barcode,
                scanState: scanState,
                cs: cs,
                isDark: isDark,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(ColorScheme cs, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: AppColors.brandPrimary600),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              style: AppTypography.bodyMedium
                  .copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme cs, String error) {
    return CasaEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Erro ao verificar',
      description: error,
      ctaLabel: 'Cadastrar manualmente',
      onCta: () =>
          context.push('${AppRoutes.productForm}?barcode=${widget.barcode}'),
    );
  }
}

// ─── Vista: produto encontrado localmente ─────────────────────────────────

class _ProductFoundView extends ConsumerWidget {
  final Product product;
  final String barcode;
  final ColorScheme cs;
  final bool isDark;

  const _ProductFoundView({
    required this.product,
    required this.barcode,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(batchesByProductProvider(product.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        _BarcodeChip(barcode: barcode, cs: cs),
        const SizedBox(height: AppSpacing.md),
        _ProductHeader(product: product, cs: cs, isDark: isDark),
        const SizedBox(height: AppSpacing.lg),
        CasaSectionHeader(
          title: 'Lotes em estoque',
          action: 'Novo lote',
          onAction: () => context
              .push('${AppRoutes.batchForm}?productId=${product.id}'),
        ),
        const SizedBox(height: AppSpacing.sm),
        batchesAsync.when(
          loading: () => const CasaCardSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (batches) {
            if (batches.isEmpty) {
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 36, color: cs.onSurfaceVariant),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Nenhum lote cadastrado',
                            style: AppTypography.labelMedium
                                .copyWith(color: cs.onSurface)),
                        const SizedBox(height: 4),
                        Text(
                          'Cadastre o primeiro lote para este produto.',
                          style: AppTypography.bodySmall
                              .copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CasaButton(
                    label: 'Cadastrar Lote',
                    icon: Icons.add_box_rounded,
                    onPressed: () => context.push(
                        '${AppRoutes.batchForm}?productId=${product.id}'),
                  ),
                ],
              );
            }
            return Column(
              children: [
                ...batches.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ExistingBatchCard(
                          batch: b,
                          cs: cs,
                          isDark: isDark,
                          productName: product.name),
                    )),
                const SizedBox(height: AppSpacing.sm),
                CasaButton(
                  label: 'Cadastrar Novo Lote',
                  icon: Icons.add_rounded,
                  onPressed: () => context.push(
                      '${AppRoutes.batchForm}?productId=${product.id}'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
        const SizedBox(height: AppSpacing.sm),
        CasaButton(
          label: 'Editar informações do produto',
          variant: CasaButtonVariant.secondary,
          icon: Icons.edit_outlined,
          onPressed: () =>
              context.push('${AppRoutes.productForm}?id=${product.id}'),
        ),
      ],
    );
  }
}

// ─── Vista: busca na API ──────────────────────────────────────────────────

class _ApiSearchView extends StatelessWidget {
  final String barcode;
  final ScannerState scanState;
  final ColorScheme cs;
  final bool isDark;

  const _ApiSearchView({
    required this.barcode,
    required this.scanState,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BarcodeChip(barcode: barcode, cs: cs),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warning600.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border:
                  Border.all(color: AppColors.warning600.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.warning600.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.search_off_rounded,
                      color: AppColors.warning600, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Produto não cadastrado',
                          style: AppTypography.labelMedium.copyWith(
                              color: AppColors.warning600,
                              fontWeight: FontWeight.w700)),
                      Text('Buscando dados na internet...',
                          style: AppTypography.bodySmall
                              .copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          scanState.apiResult.when(
            data: (apiResult) {
              if (apiResult == null || !apiResult.found) {
                return _NotFoundActions(barcode: barcode, cs: cs);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success600.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                          color: AppColors.success600.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_done_rounded,
                            color: AppColors.success600, size: 16),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Dados encontrados na internet. Confirme e cadastre.',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.success600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ApiProductCard(
                    name: apiResult.name ?? '',
                    brand: apiResult.brand ?? '',
                    category: apiResult.category ?? '',
                    imageUrl: apiResult.imageUrl,
                    cs: cs,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning600.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.warning600, size: 14),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Verifique nome e categoria antes de confirmar.',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.warning600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CasaButton(
                    label: 'Confirmar e Cadastrar Produto',
                    icon: Icons.check_rounded,
                    onPressed: () => context.push(
                      '${AppRoutes.productForm}?barcode=$barcode'
                      '&name=${Uri.encodeComponent(apiResult.name ?? '')}'
                      '&brand=${Uri.encodeComponent(apiResult.brand ?? '')}'
                      '&category=${apiResult.category ?? ''}',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CasaButton(
                    label: 'Ignorar e cadastrar manualmente',
                    variant: CasaButtonVariant.secondary,
                    onPressed: () => context
                        .push('${AppRoutes.productForm}?barcode=$barcode'),
                  ),
                ],
              );
            },
            loading: () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: AppColors.brandPrimary600),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Buscando dados do produto...',
                    style: AppTypography.bodyMedium
                        .copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text('Consultando base de dados online',
                    style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant, fontSize: 12),
                    textAlign: TextAlign.center),
              ],
            ),
            error: (_, __) =>
                _NotFoundActions(barcode: barcode, cs: cs, isError: true),
          ),
        ],
      ),
    );
  }
}

// ─── Ações para produto não encontrado ───────────────────────────────────

class _NotFoundActions extends StatelessWidget {
  final String barcode;
  final ColorScheme cs;
  final bool isError;
  const _NotFoundActions(
      {required this.barcode, required this.cs, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.brandPrimary600,
                      AppColors.secondaryBlue600
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Icon(Icons.add_box_outlined,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isError ? 'Sem conexão com internet' : 'Produto não encontrado',
                style: AppTypography.headingSmall.copyWith(
                    color: cs.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                isError
                    ? 'Não foi possível buscar dados online. Cadastre manualmente.'
                    : 'Nenhum dado encontrado para este código. Preencha as informações manualmente.',
                style:
                    AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CasaButton(
          label: 'Cadastrar Produto Novo',
          icon: Icons.inventory_2_outlined,
          onPressed: () =>
              context.push('${AppRoutes.productForm}?barcode=$barcode'),
        ),
      ],
    );
  }
}

// ─── Cabeçalho do produto ────────────────────────────────────────────────

class _ProductHeader extends StatelessWidget {
  final Product product;
  final ColorScheme cs;
  final bool isDark;
  const _ProductHeader(
      {required this.product, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card + 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary600.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child:
                product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppRadius.card),
                        child: Image.network(product.imageUrl!,
                            fit: BoxFit.cover),
                      )
                    : const Icon(Icons.inventory_2_rounded,
                        color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 11),
                      SizedBox(width: 4),
                      Text('Produto cadastrado',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.name,
                  style: AppTypography.headingSmall.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((product.brand ?? '').isNotEmpty)
                  Text(product.brand!,
                      style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.75))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _SmallChip(product.category.name),
                    _SmallChip(product.unit,
                        icon: Icons.straighten_rounded),
                    if (product.isPerishable)
                      _SmallChip('Perecível',
                          icon: Icons.schedule_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _SmallChip(this.label, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Card de lote existente ───────────────────────────────────────────────

class _ExistingBatchCard extends ConsumerStatefulWidget {
  final Batch batch;
  final String productName;
  final ColorScheme cs;
  final bool isDark;

  const _ExistingBatchCard(
      {required this.batch,
      required this.productName,
      required this.cs,
      required this.isDark});

  @override
  ConsumerState<_ExistingBatchCard> createState() =>
      _ExistingBatchCardState();
}

class _ExistingBatchCardState extends ConsumerState<_ExistingBatchCard> {
  Color _statusColor() {
    final b = widget.batch;
    if (b.noExpiry) return AppColors.success600;
    if (b.isExpired) return AppColors.danger600;
    final d = b.daysToExpiry;
    if (d <= 7) return AppColors.danger600;
    if (d <= 30) return AppColors.warning600;
    return AppColors.success600;
  }

  String _statusLabel() {
    final b = widget.batch;
    if (b.noExpiry) return 'Sem validade';
    if (b.isExpired) return 'Vencido';
    final d = b.daysToExpiry;
    if (d <= 7) return 'Crítico';
    if (d <= 30) return 'Atenção';
    return 'OK';
  }

  void _showAddQtySheet() {
    int amount = 1;
    final ctrl = TextEditingController(text: '1');
    final cs = widget.cs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.modal)),
            ),
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill)),
                  ),
                ),
                Text('Adicionar ao lote',
                    style: AppTypography.headingSmall.copyWith(
                        color: cs.onSurface, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.batch.batchNumber != null
                      ? 'Lote ${widget.batch.batchNumber} · ${widget.batch.quantity} unidades'
                      : '${widget.batch.quantity} unidades em estoque',
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        if (amount > 1) {
                          setModal(() => amount--);
                          ctrl.text = '$amount';
                        }
                      },
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: ctrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: AppTypography.headingMedium.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  AppRadius.input)),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) {
                            setModal(() => amount = n);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        setModal(() => amount++);
                        ctrl.text = '$amount';
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Consumer(
                  builder: (ctx, cref, _) {
                    final addState = cref.watch(addBatchQuantityProvider);
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: addState.isLoading
                            ? null
                            : () async {
                                await cref
                                    .read(
                                        addBatchQuantityProvider.notifier)
                                    .addUnits(widget.batch, amount);
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  showCasaSnackbar(
                                    ctx,
                                    message: '$amount unidade${amount == 1 ? '' : 's'} adicionada${amount == 1 ? '' : 's'}!',
                                    isSuccess: true,
                                  );
                                }
                              },
                        icon: addState.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.add_rounded),
                        label: Text(
                            'Adicionar $amount unidade${amount == 1 ? '' : 's'}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary600,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppRadius.button)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final statusColor = _statusColor();
    final b = widget.batch;

    return Container(
      decoration: BoxDecoration(
        color: widget.cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
          top: BorderSide(
              color: widget.cs.outlineVariant.withValues(alpha: 0.3)),
          right: BorderSide(
              color: widget.cs.outlineVariant.withValues(alpha: 0.3)),
          bottom: BorderSide(
              color: widget.cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(Icons.inventory_2_outlined,
                color: statusColor, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.25)),
                      ),
                      child: Text(_statusLabel(),
                          style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w700)),
                    ),
                    if ((b.batchNumber ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('# ${b.batchNumber}',
                          style: AppTypography.labelSmall.copyWith(
                              color: widget.cs.onSurfaceVariant,
                              fontSize: 11)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.widgets_outlined,
                        size: 13, color: AppColors.brandPrimary600),
                    const SizedBox(width: 4),
                    Text('${b.quantity} unidades',
                        style: AppTypography.labelMedium.copyWith(
                            color: widget.cs.onSurface,
                            fontWeight: FontWeight.w700)),
                    if (!b.noExpiry && b.expiryDate != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.event_rounded,
                          size: 12, color: statusColor),
                      const SizedBox(width: 3),
                      Text(fmt.format(b.expiryDate!),
                          style: AppTypography.bodySmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11)),
                    ],
                    if (b.noExpiry) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.all_inclusive_rounded,
                          size: 12, color: AppColors.success600),
                      const SizedBox(width: 3),
                      Text('Sem validade',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.success600, fontSize: 11)),
                    ],
                  ],
                ),
                if ((b.shelfLocation ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11,
                            color: widget.cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(b.shelfLocation!,
                            style: AppTypography.bodySmall.copyWith(
                                color: widget.cs.onSurfaceVariant,
                                fontSize: 10)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showAddQtySheet,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.button),
                boxShadow: [
                  BoxShadow(
                    color:
                        AppColors.brandPrimary600.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Adicionar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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

// ─── Card produto da API ──────────────────────────────────────────────────

class _ApiProductCard extends StatelessWidget {
  final String name;
  final String brand;
  final String category;
  final String? imageUrl;
  final ColorScheme cs;
  const _ApiProductCard(
      {required this.name,
      required this.brand,
      required this.category,
      this.imageUrl,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: AppColors.success600.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.success600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Image.network(imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.success600,
                            size: 26)))
                : const Icon(Icons.inventory_2_outlined,
                    color: AppColors.success600, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success600.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_rounded,
                          size: 10, color: AppColors.success600),
                      SizedBox(width: 4),
                      Text('Dados da internet',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.success600,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (name.isNotEmpty)
                  Text(name,
                      style: AppTypography.labelLarge.copyWith(
                          color: cs.onSurface, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                if (brand.isNotEmpty)
                  Text(brand,
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant)),
                if (category.isNotEmpty)
                  Text(category,
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.brandPrimary600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chips de barcode ─────────────────────────────────────────────────────

class _BarcodeChip extends StatelessWidget {
  final String barcode;
  final ColorScheme cs;
  const _BarcodeChip({required this.barcode, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary600.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.brandPrimary600.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_rounded,
              color: AppColors.brandPrimary600, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Código detectado',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.brandPrimary600,
                      fontWeight: FontWeight.w600,
                      fontSize: 11)),
              Text(barcode,
                  style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurface, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Botão de quantidade ──────────────────────────────────────────────────

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: cs.onSurface, size: 20),
      ),
    );
  }
}

