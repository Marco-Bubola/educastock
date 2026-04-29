import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
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

  Future<void> _submit(Batch batch) async {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_quantityController.text) ?? 0;

    // Regra: não permitir saída acima do saldo do lote
    if ((_type == MovementType.saida ||
            _type == MovementType.ajusteNegativo ||
            _type == MovementType.descarte) &&
        qty > batch.quantity) {
      showCasaSnackbar(
        context,
        message:
            'Quantidade indisponível. Saldo atual: ${batch.quantity}',
        isError: true,
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final isOutbound = _type == MovementType.saida ||
        _type == MovementType.ajusteNegativo ||
        _type == MovementType.descarte;
    final newQty =
        isOutbound ? batch.quantity - qty : batch.quantity + qty;
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
      if (mounted) {
        showCasaSnackbar(context,
            message: 'Movimentação registrada!', isSuccess: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showCasaSnackbar(context,
            message: 'Erro ao registrar movimentação.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Busca os lotes pelo productId não é suficiente; usamos todos os disponíveis
    final batchesAsync = ref.watch(allAvailableBatchesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Movimentação de Estoque')),
      body: SafeArea(
        child: batchesAsync.when(
          data: (batches) {
            final batch = batches.where((b) => b.id == widget.batchId).firstOrNull;
            if (batch == null && widget.batchId.isNotEmpty) {
              return CasaEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Lote não encontrado',
                description: 'O lote selecionado não está disponível.',
              );
            }
            return _buildForm(batch);
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
        ),
      ),
    );
  }

  Widget _buildForm(Batch? batch) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
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
                  Text('Lote selecionado',
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.neutral500)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(batch.productName,
                      style: AppTypography.headingSmall
                          .copyWith(color: AppColors.neutral900)),
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

          // Tipo de movimentação
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
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
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
            prefixIcon:
                const Icon(Icons.numbers_rounded, size: 20),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe a quantidade';
              final n = int.tryParse(v);
              if (n == null || n <= 0) return 'Quantidade inválida';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          CasaTextField(
            label: _type == MovementType.saida
                ? 'Atividade / Projeto'
                : 'Motivo',
            controller: _type == MovementType.saida
                ? _activityController
                : _reasonController,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.xxl),

          CasaButton(
            label: 'Registrar Movimentação',
            onPressed: (_isLoading || batch == null)
                ? null
                : () => _submit(batch),
            isLoading: _isLoading,
            icon: Icons.swap_horiz_rounded,
          ),
        ],
      ),
    );
  }
}
