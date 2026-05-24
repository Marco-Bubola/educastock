// product_detail_page.dart — modernizado, adaptativo (dark/light) e com ações para lotes vencidos
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../stock/domain/entities/stock_movement.dart';
import '../../../stock/presentation/controllers/stock_provider.dart';
import '../../domain/entities/product.dart';
import '../controllers/products_provider.dart';

final _keyDetailInfo = GlobalKey();
final _keyDetailBatches = GlobalKey();
final _keyDetailFAB = GlobalKey();

class ProductDetailPage extends ConsumerWidget {
  final String productId;
  const ProductDetailPage({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productAsync = ref.watch(productByIdProvider(productId));
    final batchesAsync = ref.watch(batchesByProductProvider(productId));

    // A página de detalhe não bloqueia mais com fullscreen spinner: o
    // productByIdProvider tenta servir o produto pelo cache do StreamProvider
    // imediatamente, e a lista de lotes mostra apenas skeleton local.
    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: FloatingActionButton.extended(
        key: _keyDetailFAB,
        onPressed: () =>
            context.push('${AppRoutes.batchForm}?productId=$productId'),
        backgroundColor: AppColors.brandPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Lote'),
        elevation: 6,
      ),
      body: productAsync.when(
        loading: () => _LoadingScaffold(cs: cs, isDark: isDark),
        error: (e, _) => _ErrorScaffold(message: e.toString(), cs: cs),
        data: (p) {
          if (p == null) {
            return _ErrorScaffold(message: 'Produto não encontrado', cs: cs);
          }
          return _DetailBody(
            product: p,
            productId: productId,
            batchesAsync: batchesAsync,
            cs: cs,
            isDark: isDark,
          );
        },
      ),
    );
  }
}

// ─── Body principal ────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final Product product;
  final String productId;
  final AsyncValue<List<Batch>> batchesAsync;
  final ColorScheme cs;
  final bool isDark;
  const _DetailBody({
    required this.product,
    required this.productId,
    required this.batchesAsync,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = batchesAsync.valueOrNull ?? const [];
    final loading = batchesAsync.isLoading && batches.isEmpty;
    final totalQty = batches.fold<int>(0, (s, b) => s + b.quantity);
    final totalValue = batches.fold<double>(
        0, (s, b) => s + ((b.unitPrice ?? 0) * b.quantity));
    final expired = batches.where((b) => b.isExpired).toList();
    final critical = batches
        .where((b) => !b.noExpiry && !b.isExpired && b.daysToExpiry <= 7)
        .length;

    return CustomScrollView(
      slivers: [
        _ProductSliverAppBar(product: product, productId: productId),

        // Banner de lotes vencidos (sticky no topo do conteúdo)
        if (expired.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            sliver: SliverToBoxAdapter(
              child: _ExpiredBanner(
                product: product,
                expired: expired,
                isDark: isDark,
                cs: cs,
                onResolveAll: () => _openBulkResolveSheet(
                    context, ref, product, expired, isDark, cs),
              ),
            ),
          ),

        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              expired.isNotEmpty ? AppSpacing.md : AppSpacing.md,
              AppSpacing.lg,
              120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              KeyedSubtree(
                key: _keyDetailInfo,
                child: _StatsRow(
                  totalBatches: batches.length,
                  totalQty: totalQty,
                  totalValue: totalValue,
                  critical: critical,
                  expired: expired.length,
                  isDark: isDark,
                  cs: cs,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              KeyedSubtree(
                key: _keyDetailBatches,
                child: CasaSectionHeader(
                  title: 'Lotes',
                  count: batches.length,
                  action: 'Novo Lote',
                  onAction: () => context
                      .push('${AppRoutes.batchForm}?productId=$productId'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (loading)
                ...List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: CasaCardSkeleton(),
                  ),
                )
              else if (batches.isEmpty)
                CasaEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nenhum lote cadastrado',
                  description:
                      'Cadastre o primeiro lote para controlar a validade.',
                  ctaLabel: 'Cadastrar Lote',
                  onCta: () => context
                      .push('${AppRoutes.batchForm}?productId=$productId'),
                )
              else
                ...batches.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _BatchCard(
                      batch: b,
                      isDark: isDark,
                      cs: cs,
                      onEdit: () => context.push(
                          '${AppRoutes.batchForm}?id=${b.id}&productId=$productId'),
                      onDelete: () => _confirmDelete(context, ref, b),
                      onResolveExpired: b.isExpired
                          ? () => _openSingleResolveSheet(
                              context, ref, product, b, isDark, cs)
                          : null,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
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

  void _openSingleResolveSheet(BuildContext context, WidgetRef ref,
      Product product, Batch batch, bool isDark, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResolveExpiredSheet(
        product: product,
        batches: [batch],
        isDark: isDark,
        cs: cs,
      ),
    );
  }

  void _openBulkResolveSheet(BuildContext context, WidgetRef ref,
      Product product, List<Batch> expired, bool isDark, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResolveExpiredSheet(
        product: product,
        batches: expired,
        isDark: isDark,
        cs: cs,
      ),
    );
  }
}

// ─── SliverAppBar moderno ──────────────────────────────────────────────────

class _ProductSliverAppBar extends ConsumerWidget {
  final Product product;
  final String productId;
  const _ProductSliverAppBar(
      {required this.product, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final alertCount = ref.watch(allAvailableBatchesProvider).when(
          data: (list) => list
              .where((b) =>
                  !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30))
              .length,
          loading: () => 0,
          error: (_, __) => 0,
        );
    final initial = (user?.name ?? '').trim().isEmpty
        ? 'U'
        : user!.name.trim().substring(0, 1).toUpperCase();

    return SliverAppBar(
      expandedHeight: 165,
      pinned: true,
      backgroundColor: AppColors.brandPrimary600,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      actions: [
        buildHelpButton(
          context: context,
          onPressed: () => showCasaTutorial(
            context: context,
            steps: [
              TutorialStep(
                key: _keyDetailInfo,
                title: 'Estatísticas do Produto',
                description: 'Os 4 cards coloridos na linha superior mostram os números mais importantes do produto: total de lotes ativos, quantidade total em estoque (somando todos os lotes), valor financeiro estimado e alertas (vencidos ou críticos).',
                icon: Icons.info_rounded,
                align: ContentAlign.bottom,
                hints: const [
                  '📦 Lotes: quantos lotes ativos existem',
                  '🔢 Itens: total de unidades somadas',
                  '💰 Valor: estimativa em reais (R\$) do estoque',
                  '⚠️ Alertas: vencidos primeiro, depois críticos',
                  '✏️ Botão lápis no topo edita os dados do produto',
                ],
              ),
              TutorialStep(
                key: _keyDetailBatches,
                title: 'Lotes Ativos',
                description: 'Lista todos os lotes registrados para este produto. Cada cartão mostra: status colorido, número do lote, quantidade, data de validade com contagem de dias, origem (doação/compra), localização física e preço unitário. Lotes vencidos têm botão "Resolver" para baixa rápida.',
                icon: Icons.inventory_rounded,
                align: ContentAlign.bottom,
                hints: const [
                  '🔴 Vencido → toque "Resolver" para baixa rápida',
                  '🟡 Borda amarela = vence em até 30 dias',
                  '🟢 Borda verde = validade segura (>30 dias)',
                  '✏️ Ícone lápis edita o lote',
                  '🗑️ Ícone lixeira exclui SEM baixa em estoque',
                ],
              ),
              TutorialStep(
                key: _keyDetailFAB,
                title: 'Adicionar Novo Lote',
                description: 'Toque no botão azul "Novo Lote" para registrar uma nova entrada deste produto. Você informa número do lote, quantidade, validade, origem, localização e preço unitário. Cada nova compra/doação deve virar um lote separado para rastreabilidade.',
                icon: Icons.add_box_rounded,
                align: ContentAlign.top,
                hints: const [
                  '📦 Cada entrada = 1 lote separado',
                  '📅 Validades diferentes SEMPRE em lotes separados',
                  '⚡ Atalho: escaneie código de barras na tela inicial',
                  '🏷️ Use o número LOT impresso na embalagem',
                ],
              ),
            ],
          ),
        ),
        CasaAlertsBellButton(alertCount: alertCount, onDarkBg: true),
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.xs),
          child: CasaThemeToggleButton(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: GestureDetector(
            onTap: () => context.push(AppRoutes.settings),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
                product.name,
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
                  colors: [
                    Color(0xFF0F3B82),
                    Color(0xFF1D5FA8),
                    Color(0xFF2563EB),
                  ],
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
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: 10,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Conteúdo
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 58, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0.10),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1),
                          ),
                          child: product.imageUrl != null &&
                                  product.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(product.imageUrl!,
                                      fit: BoxFit.cover),
                                )
                              : const Icon(Icons.inventory_2_rounded,
                                  color: Colors.white, size: 23),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((product.brand ?? '').isNotEmpty)
                                Text(
                                  product.brand!.toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.7),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              if ((product.barcode ?? '').isNotEmpty)
                                Row(children: [
                                  Icon(Icons.qr_code_rounded,
                                      size: 10,
                                      color: Colors.white
                                          .withValues(alpha: 0.55)),
                                  const SizedBox(width: 3),
                                  Text(product.barcode!,
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.55),
                                          fontSize: 9.5,
                                          letterSpacing: 0.5)),
                                ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _HChip(product.unit),
                        _HChip(product.category.name,
                            icon: Icons.category_outlined,
                            color: const Color(0xFFBAD4FF)),
                        if (product.isPerishable)
                          _HChip('Perecível',
                              icon: Icons.schedule_rounded,
                              color: const Color(0xFFFFE0A0))
                        else
                          _HChip('Não perecível',
                              icon: Icons.shield_outlined,
                              color: const Color(0xFFA7F3D0)),
                        if (product.minimumStock > 0)
                          _HChip('Mín: ${product.minimumStock}',
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

// ─── Loading / Error scaffolds ─────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;
  const _LoadingScaffold({required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 165,
          pinned: true,
          backgroundColor: AppColors.brandPrimary600,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F3B82),
                  Color(0xFF1D5FA8),
                  Color(0xFF2563EB),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: CasaCardSkeleton(),
              ),
              childCount: 4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final ColorScheme cs;
  const _ErrorScaffold({required this.message, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: cs.error),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ─── Banner de vencidos ────────────────────────────────────────────────────

class _ExpiredBanner extends StatelessWidget {
  final Product product;
  final List<Batch> expired;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onResolveAll;
  const _ExpiredBanner({
    required this.product,
    required this.expired,
    required this.isDark,
    required this.cs,
    required this.onResolveAll,
  });

  @override
  Widget build(BuildContext context) {
    final totalUnits = expired.fold<int>(0, (s, b) => s + b.quantity);
    final accent = const Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF3F1414),
                  const Color(0xFF2A0F0F),
                ]
              : [
                  const Color(0xFFFEF2F2),
                  const Color(0xFFFEE2E2),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                    color: accent.withValues(alpha: 0.45), width: 1.2),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${expired.length} lote${expired.length > 1 ? 's' : ''} vencido${expired.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color:
                          isDark ? const Color(0xFFFCA5A5) : accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$totalUnits ${product.unit} pendentes de baixa',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onResolveAll,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                elevation: 0,
              ),
              icon: const Icon(Icons.task_alt_rounded, size: 15),
              label: const Text('Resolver'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheet de resolução (vencidos) ──────────────────────────────────

class _ResolveExpiredSheet extends ConsumerStatefulWidget {
  final Product product;
  final List<Batch> batches;
  final bool isDark;
  final ColorScheme cs;
  const _ResolveExpiredSheet({
    required this.product,
    required this.batches,
    required this.isDark,
    required this.cs,
  });

  @override
  ConsumerState<_ResolveExpiredSheet> createState() =>
      _ResolveExpiredSheetState();
}

class _ResolveExpiredSheetState extends ConsumerState<_ResolveExpiredSheet> {
  bool _submitting = false;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply({
    required MovementType type,
    required MovementReasonCode reasonCode,
    required String successMessage,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final notifier = ref.read(stockNotifierProvider.notifier);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    try {
      for (final b in widget.batches) {
        await notifier.writeOffExpiredBatch(
          b,
          type: type,
          reasonCode: reasonCode,
          note: note,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showCasaSnackbar(context, message: successMessage, isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showCasaSnackbar(context,
          message: 'Erro ao registrar baixa: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final totalUnits =
        widget.batches.fold<int>(0, (s, b) => s + b.quantity);
    final bg = isDark ? const Color(0xFF111827) : cs.surface;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: const Color(0xFFEF4444)
                            .withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.batches.length == 1
                            ? 'Lote vencido'
                            : '${widget.batches.length} lotes vencidos',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '$totalUnits ${widget.product.unit} de ${widget.product.name}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'O que deseja fazer?',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ResolveOption(
              icon: Icons.delete_sweep_rounded,
              title: 'Descartar (validade vencida)',
              subtitle:
                  'Baixa total · status descartado · motivo: validade',
              color: const Color(0xFFEF4444),
              isDark: isDark,
              cs: cs,
              enabled: !_submitting,
              onTap: () => _apply(
                type: MovementType.descarte,
                reasonCode: MovementReasonCode.validade,
                successMessage: 'Lote(s) descartado(s) por validade.',
              ),
            ),
            const SizedBox(height: 8),
            _ResolveOption(
              icon: Icons.warning_amber_rounded,
              title: 'Descartar (avaria/estraga­do)',
              subtitle:
                  'Baixa total · status descartado · motivo: avaria',
              color: const Color(0xFFF59E0B),
              isDark: isDark,
              cs: cs,
              enabled: !_submitting,
              onTap: () => _apply(
                type: MovementType.descarte,
                reasonCode: MovementReasonCode.avaria,
                successMessage: 'Lote(s) descartado(s) por avaria.',
              ),
            ),
            const SizedBox(height: 8),
            _ResolveOption(
              icon: Icons.volunteer_activism_rounded,
              title: 'Registrar como doação',
              subtitle:
                  'Baixa total como saída · status distribuído · motivo: doação',
              color: const Color(0xFF22C55E),
              isDark: isDark,
              cs: cs,
              enabled: !_submitting,
              onTap: () => _apply(
                type: MovementType.saida,
                reasonCode: MovementReasonCode.doacao,
                successMessage: 'Lote(s) registrado(s) como doação.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _noteCtrl,
              enabled: !_submitting,
              minLines: 1,
              maxLines: 3,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Observação (opcional)',
                labelStyle:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                hintText: 'Ex.: Conferido por... / Destino...',
                hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 12),
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide:
                      const BorderSide(color: AppColors.brandPrimary600),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_submitting)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            const SizedBox(height: 4),
            TextButton(
              onPressed:
                  _submitting ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
                minimumSize: const Size.fromHeight(40),
              ),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolveOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;
  final ColorScheme cs;
  final bool enabled;
  final VoidCallback onTap;
  const _ResolveOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.cs,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: color.withValues(alpha: isDark ? 0.30 : 0.22),
                  width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Botão de navegação (no AppBar) ────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.22), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }
}

// ─── Chip do header ────────────────────────────────────────────────────────

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
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9.5, color: c),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 9.5, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Stats row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int totalBatches;
  final int totalQty;
  final double totalValue;
  final int critical;
  final int expired;
  final bool isDark;
  final ColorScheme cs;
  const _StatsRow({
    required this.totalBatches,
    required this.totalQty,
    required this.totalValue,
    required this.critical,
    required this.expired,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final alertCount = expired > 0 ? expired : critical;
    final alertLabel = expired > 0 ? 'Vencidos' : 'Críticos';
    final alertColor = expired > 0
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);
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
          cs: cs,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Itens',
          value: '$totalQty',
          icon: Icons.widgets_outlined,
          color: const Color(0xFF818CF8),
          isDark: isDark,
          cs: cs,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Valor',
          value: currFmt.format(totalValue),
          icon: Icons.attach_money_rounded,
          color: const Color(0xFF22C55E),
          isDark: isDark,
          cs: cs,
          flex: 2,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: alertLabel,
          value: '$alertCount',
          icon: alertIcon,
          color: alertColor,
          isDark: isDark,
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
  final bool isDark;
  final ColorScheme cs;
  final int flex;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.cs,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: color.withValues(alpha: isDark ? 0.28 : 0.18),
              width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.10 : 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                color: color.withValues(alpha: isDark ? 0.18 : 0.11),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
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
                color: cs.onSurfaceVariant,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Modal de confirmação de exclusão ──────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  final Batch batch;
  const _DeleteConfirmDialog({required this.batch});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444), size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              'Excluir Lote',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Esta ação remove o lote sem registrar baixa em estoque.\nUse "Resolver" para lotes vencidos quando quiser auditoria.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.4),
            ),
            if ((batch.batchNumber ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          const Color(0xFFEF4444).withValues(alpha: 0.2)),
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
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        'Cancelar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
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
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
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

// ─── Card de lote ──────────────────────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onResolveExpired;
  const _BatchCard({
    required this.batch,
    required this.isDark,
    required this.cs,
    required this.onEdit,
    required this.onDelete,
    this.onResolveExpired,
  });

  Color _statusColor() {
    if (batch.noExpiry) return const Color(0xFF22C55E);
    if (batch.isExpired) return const Color(0xFFEF4444);
    final u = batch.daysToExpiry;
    if (u <= 7) return const Color(0xFFEF4444);
    if (u <= 30) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
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
    if (batch.isExpired) return Icons.cancel_rounded;
    final u = batch.daysToExpiry;
    if (u <= 7) return Icons.warning_amber_rounded;
    if (u <= 30) return Icons.schedule_rounded;
    return Icons.check_circle_rounded;
  }

  String _originLabel() => switch (batch.origin) {
        'doacao' => 'Doação',
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

    final cardBg = cs.surfaceContainerLow;
    final headerBg = sc.withValues(alpha: isDark ? 0.12 : 0.07);
    final borderColor = sc.withValues(alpha: isDark ? 0.28 : 0.20);
    final onCardSub = cs.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: sc.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── HEADER ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(
                    color: sc.withValues(alpha: isDark ? 0.18 : 0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: sc,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: sc.withValues(alpha: 0.55),
                          blurRadius: 5,
                          spreadRadius: 1)
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Icon(_statusIcon(), size: 13, color: sc),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(),
                  style: TextStyle(
                    color: sc,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: sc.withValues(alpha: 0.32)),
                  ),
                  child: Text(
                    '${batch.quantity} un.',
                    style: TextStyle(
                        color: sc,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                _ActionBtn(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFF60A5FA),
                  isDark: isDark,
                  onTap: onEdit,
                  tooltip: 'Editar',
                ),
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFEF4444),
                  isDark: isDark,
                  onTap: onDelete,
                  tooltip: 'Excluir',
                ),
              ],
            ),
          ),

          // ── CORPO ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
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
                          isDark: isDark,
                          cs: cs),
                    if ((batch.batchNumber ?? '').isNotEmpty)
                      _InfoChip(
                          icon: Icons.tag_rounded,
                          label: batch.batchNumber!,
                          color: const Color(0xFFA78BFA),
                          isDark: isDark,
                          cs: cs),
                    if ((batch.shelfLocation ?? '').isNotEmpty)
                      _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: batch.shelfLocation!,
                          color: const Color(0xFF38BDF8),
                          isDark: isDark,
                          cs: cs),
                    if (batch.unitPrice != null)
                      _InfoChip(
                          icon: Icons.attach_money_rounded,
                          label: currFmt.format(batch.unitPrice!),
                          color: const Color(0xFF22C55E),
                          isDark: isDark,
                          cs: cs),
                  ],
                ),
                if ((batch.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_rounded,
                          size: 11, color: onCardSub),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          batch.notes!,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: onCardSub,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (onResolveExpired != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onResolveExpired,
                      icon: const Icon(Icons.task_alt_rounded, size: 16),
                      label: const Text('Resolver lote vencido'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12.5),
                        elevation: 0,
                      ),
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

}

// ─── Action button ─────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final String? tooltip;
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: color.withValues(alpha: isDark ? 0.30 : 0.22)),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

// ─── Info chip ─────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final ColorScheme cs;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: color.withValues(alpha: isDark ? 0.24 : 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.5, color: color.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: cs.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
