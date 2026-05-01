import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/observability/analytics_service.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../domain/entities/stock_movement.dart';

final stockDatasourceProvider = Provider<StockRemoteDatasource>(
  (_) => StockRemoteDatasource(),
);

class MovementPage extends ConsumerStatefulWidget {
  final String batchId;
  const MovementPage({super.key, required this.batchId});

  @override
  ConsumerState<MovementPage> createState() => _MovementPageState();
}

class _MovementPageState extends ConsumerState<MovementPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  final _activityController = TextEditingController();

  MovementType _type = MovementType.saida;
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  Batch? _getFefoRecommendedBatch({
    required List<Batch> allBatches,
    required Batch selectedBatch,
  }) {
    final candidates = allBatches
        .where(
          (b) =>
              b.productId == selectedBatch.productId &&
              b.quantity > 0 &&
              b.status == BatchStatus.disponivel,
        )
        .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      if (a.noExpiry && b.noExpiry) return 0;
      if (a.noExpiry) return 1;
      if (b.noExpiry) return -1;
      if (a.expiryDate == null && b.expiryDate == null) return 0;
      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });

    return candidates.first;
  }

  Future<void> _submit(Batch batch, List<Batch> allBatches) async {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_quantityController.text) ?? 0;

    if ((_type == MovementType.saida ||
            _type == MovementType.ajusteNegativo ||
            _type == MovementType.descarte) &&
        qty > batch.quantity) {
      showCasaSnackbar(
        context,
        message: 'Quantidade indisponível. Saldo atual: ${batch.quantity}',
        isError: true,
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final stockRules = ref.read(stockRulesConfigProvider).valueOrNull;
    final approvalLimit = stockRules?.negativeAdjustmentApprovalLimit ?? 50;

    final isOutbound = _type == MovementType.saida ||
        _type == MovementType.ajusteNegativo ||
        _type == MovementType.descarte;

    final fefoRecommended = _getFefoRecommendedBatch(
      allBatches: allBatches,
      selectedBatch: batch,
    );
    final isFefoViolation = isOutbound &&
        fefoRecommended != null &&
        fefoRecommended.id != batch.id;

    if (isFefoViolation) {
      final reason = _reasonController.text.trim();
      if (!user.canApproveAdjustments) {
        showCasaSnackbar(
          context,
          message:
              'Saída fora da ordem FEFO bloqueada. Use o lote recomendado primeiro.',
          isError: true,
        );
        return;
      }
      if (reason.isEmpty) {
        showCasaSnackbar(
          context,
          message:
              'Admin: informe motivo para liberar saída fora da ordem FEFO.',
          isError: true,
        );
        return;
      }
    }

    if (_type == MovementType.ajusteNegativo &&
        qty > approvalLimit &&
        !user.canApproveAdjustments) {
      final reason = _reasonController.text.trim();
      if (reason.isEmpty) {
        showCasaSnackbar(
          context,
          message: 'Informe o motivo para solicitar aprovação do ajuste.',
          isError: true,
        );
        return;
      }

      await ref.read(stockDatasourceProvider).createAdjustmentApprovalRequest(
            productId: batch.productId,
            productName: batch.productName,
            batchId: batch.id,
            quantity: qty,
            requestedBy: user.id,
            requestedByName: user.name,
            reason: reason,
          );
      ref.read(analyticsServiceProvider).logStockMovement(
            type: _type.name,
            quantity: qty,
            fefoOverride: isFefoViolation,
            requiresApproval: true,
          );
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message:
            'Ajuste enviado para aprovação (acima do limite de $approvalLimit).',
        isSuccess: true,
      );
      context.pop();
      return;
    }

    final newQty = isOutbound ? batch.quantity - qty : batch.quantity + qty;
    final shouldDistribute = newQty <= 0;

    final movement = StockMovement(
      id: '',
      productId: batch.productId,
      productName: batch.productName,
      batchId: batch.id,
      type: _type,
      quantity: qty,
      reason: _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim(),
      activity: _activityController.text.trim().isEmpty
          ? null
          : _activityController.text.trim(),
      performedBy: user.id,
      performedByName: user.name,
      performedAt: DateTime.now(),
      auditBefore: {'quantity': batch.quantity, 'status': batch.status.name},
      auditAfter: {
        'quantity': newQty,
        'status': shouldDistribute
            ? BatchStatus.distribuido.name
            : batch.status.name,
        'fefoRecommendedBatchId': fefoRecommended?.id,
        'fefoOverride': isFefoViolation,
      },
    );

    setState(() => _isLoading = true);
    try {
      await ref.read(stockDatasourceProvider).registerMovement(
            movement: movement,
            batchId: batch.id,
            previousQuantity: batch.quantity,
            newQuantity: newQty,
            shouldUpdateStatus: shouldDistribute,
          );
      ref.read(analyticsServiceProvider).logStockMovement(
            type: _type.name,
            quantity: qty,
            fefoOverride: isFefoViolation,
            requiresApproval: false,
          );
      if (mounted) {
        showCasaSnackbar(
          context,
          message: 'Movimentação registrada!',
          isSuccess: true,
        );
        context.pop();
      }
    } catch (error, stackTrace) {
      ref.read(analyticsServiceProvider).recordHandledError(
            error,
            stackTrace,
            reason: 'stock_movement_failed',
          );
      if (mounted) {
        showCasaSnackbar(
          context,
          message: 'Erro ao registrar movimentação.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(allAvailableBatchesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ModernProfileAppBar(
        title: 'Movimentação de Estoque',
        subtitle: 'Registro de entrada e saída',
        showBackButton: true,
      ),
      body: SafeArea(
        child: batchesAsync.when(
          data: (batches) {
            final batch = batches.where((b) => b.id == widget.batchId).firstOrNull;
            if (batch == null && widget.batchId.isNotEmpty) {
              return const CasaEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Lote não encontrado',
                description: 'O lote selecionado não está disponível.',
              );
            }
            return _buildForm(batch, batches);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
        ),
      ),
    );
  }

  Widget _buildForm(Batch? batch, List<Batch> allBatches) {
    final recommended = batch == null
        ? null
        : _getFefoRecommendedBatch(
            allBatches: allBatches,
            selectedBatch: batch,
          );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (batch != null &&
              recommended != null &&
              recommended.id != batch.id) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.priority_high_rounded,
                    color: AppColors.warning600,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'FEFO: lote recomendado para saída é o de validade mais próxima.',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.warning600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (batch != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lote selecionado',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.neutral500),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    batch.productName,
                    style: AppTypography.headingSmall
                        .copyWith(color: AppColors.neutral900),
                  ),
                  Text(
                    'Saldo atual: ${batch.quantity} • Origem: ${batch.origin}',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const CasaSectionHeader(title: 'Tipo de Movimentação'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: MovementType.values.map((t) {
              final isSelected = _type == t;
              final label = switch (t) {
                MovementType.entrada => 'Entrada',
                MovementType.saida => 'Saída',
                MovementType.ajustePositivo => 'Ajuste +',
                MovementType.ajusteNegativo => 'Ajuste -',
                MovementType.descarte => 'Descarte',
              };
              final color = switch (t) {
                MovementType.entrada || MovementType.ajustePositivo =>
                  AppColors.success600,
                MovementType.saida => AppColors.brandPrimary600,
                MovementType.ajusteNegativo => AppColors.warning600,
                MovementType.descarte => AppColors.danger600,
              };
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                selectedColor: color.withValues(alpha: 0.15),
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: isSelected ? color : AppColors.neutral700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          CasaTextField(
            label: 'Quantidade *',
            controller: _quantityController,
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe a quantidade';
              final n = int.tryParse(v);
              if (n == null || n <= 0) return 'Quantidade inválida';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          CasaTextField(
            label: _type == MovementType.saida ? 'Atividade / Projeto' : 'Motivo',
            controller:
                _type == MovementType.saida ? _activityController : _reasonController,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.xxl),
          CasaButton(
            label: 'Registrar Movimentação',
            onPressed: (_isLoading || batch == null)
                ? null
                : () => _submit(batch, allBatches),
            isLoading: _isLoading,
            icon: Icons.swap_horiz_rounded,
          ),
        ],
      ),
    );
  }
}
