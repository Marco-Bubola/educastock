import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../domain/entities/batch.dart';
import '../controllers/batches_provider.dart';

class BatchFormPage extends ConsumerStatefulWidget {
  final String productId;
  const BatchFormPage({super.key, required this.productId});

  @override
  ConsumerState<BatchFormPage> createState() => _BatchFormPageState();
}

class _BatchFormPageState extends ConsumerState<BatchFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  final _donorController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _expiryDate;
  DateTime _entryDate = DateTime.now();
  bool _noExpiry = false;
  String _origin = 'doacao';
  bool _isPerishableProduct = true;

  final List<String> _origins = [
    'doacao',
    'compra',
    'parceiro',
    'transferencia',
  ];
  final _originLabels = {
    'doacao': 'Doação',
    'compra': 'Compra',
    'parceiro': 'Parceiro',
    'transferencia': 'Transferência',
  };

  @override
  void dispose() {
    _quantityController.dispose();
    _locationController.dispose();
    _donorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Data de Validade do Lote',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validação crítica: perecível exige validade ou flag noExpiry
    if (_isPerishableProduct && !_noExpiry && _expiryDate == null) {
      showCasaSnackbar(
        context,
        message: 'Informe a data de validade ou marque "Sem validade".',
        isError: true,
      );
      return;
    }

    // Bloquear entrada de lote já vencido
    if (_expiryDate != null && _expiryDate!.isBefore(DateTime.now())) {
      final confirm = await CasaDialogConfirmacao.show(
        context: context,
        title: 'Produto Vencido',
        message:
            'A data de validade informada é anterior à data atual. Deseja registrar como descarte?',
        confirmLabel: 'Registrar Descarte',
        cancelLabel: 'Corrigir Data',
        isDanger: true,
      );
      if (confirm != true) return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final qty = int.tryParse(_quantityController.text) ?? 0;

    final batch = Batch(
      id: '',
      productId: widget.productId,
      productName: '',
      quantity: qty,
      initialQuantity: qty,
      expiryDate: _noExpiry ? null : _expiryDate,
      noExpiry: _noExpiry,
      entryDate: _entryDate,
      origin: _origin,
      donor: _donorController.text.trim().isEmpty
          ? null
          : _donorController.text.trim(),
      shelfLocation: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdBy: user.id,
      createdAt: DateTime.now(),
    );

    await ref.read(batchFormProvider.notifier).saveBatch(batch);

    final state = ref.read(batchFormProvider);
    if (!mounted) return;
    state.when(
      data: (id) {
        if (id != null) {
          showCasaSnackbar(context, message: 'Lote cadastrado!', isSuccess: true);
          context.go('/products/${widget.productId}');
        }
      },
      error: (e, _) => showCasaSnackbar(context,
          message: 'Erro ao salvar lote.', isError: true),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final formState = ref.watch(batchFormProvider);
    final isLoading = formState is AsyncLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cadastrar Lote')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Alerta sobre validade física
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.info600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_rounded,
                        color: AppColors.info600, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Confirme a validade física na embalagem do produto.',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.info600),
                      ),
                    ),
                  ],
                ),
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

              // Data de validade
              if (!_noExpiry) ...[
                InkWell(
                  onTap: _pickExpiryDate,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: _isPerishableProduct
                          ? 'Data de Validade *'
                          : 'Data de Validade',
                      prefixIcon:
                          const Icon(Icons.event_rounded, size: 20),
                      suffixIcon: const Icon(Icons.chevron_right_rounded,
                          size: 20),
                    ),
                    child: Text(
                      _expiryDate != null
                          ? fmt.format(_expiryDate!)
                          : 'Toque para selecionar',
                      style: AppTypography.bodyLarge.copyWith(
                        color: _expiryDate != null
                            ? AppColors.neutral900
                            : AppColors.neutral500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // Sem validade
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.neutral100),
                ),
                child: CheckboxListTile(
                  title: Text(
                    'Sem validade definida',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.neutral900),
                  ),
                  subtitle: Text(
                    'Marque para itens não perecíveis',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral500),
                  ),
                  value: _noExpiry,
                  onChanged: (v) => setState(() => _noExpiry = v ?? false),
                  activeColor: AppColors.brandPrimary600,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Origem
              DropdownButtonFormField<String>(
                value: _origin,
                decoration: const InputDecoration(
                  labelText: 'Origem *',
                  prefixIcon: Icon(Icons.source_outlined, size: 20),
                ),
                items: _origins
                    .map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(_originLabels[o] ?? o),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _origin = v!),
              ),
              const SizedBox(height: AppSpacing.md),

              CasaTextField(
                label: 'Doador / Fornecedor',
                controller: _donorController,
                prefixIcon:
                    const Icon(Icons.person_outline_rounded, size: 20),
              ),
              const SizedBox(height: AppSpacing.md),

              CasaTextField(
                label: 'Localização (Sala/Prateleira/Nível)',
                controller: _locationController,
                prefixIcon:
                    const Icon(Icons.location_on_outlined, size: 20),
                hint: 'Ex: Dep-A / P3 / N2',
              ),
              const SizedBox(height: AppSpacing.md),

              CasaTextField(
                label: 'Observações (opcional)',
                controller: _notesController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xxl),

              CasaButton(
                label: 'Registrar Lote',
                onPressed: isLoading ? null : _submit,
                isLoading: isLoading,
                icon: Icons.add_box_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
