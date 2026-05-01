import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../locations/presentation/controllers/locations_provider.dart';
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
  final DateTime _entryDate = DateTime.now();
  bool _noExpiry = false;
  String _origin = 'doacao';
  final bool _isPerishableProduct = true;
  bool _manualLocation = false;
  String? _selectedLocationLabel;

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

  DateTime? _tryParseDateFromText(String text) {
    final regex = RegExp(r'(\d{2})[\/-](\d{2})[\/-](\d{2,4})');
    final match = regex.firstMatch(text);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    var year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _scanExpiryDateWithOcr() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file == null) return;

    final inputImage = InputImage.fromFilePath(file.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(inputImage);
      final parsed = _tryParseDateFromText(result.text);

      if (parsed == null) {
        if (!mounted) return;
        showCasaSnackbar(
          context,
          message: 'Nao foi possivel identificar uma data valida.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      final fmt = DateFormat('dd/MM/yyyy');
      final confirm = await CasaDialogConfirmacao.show(
        context: context,
        title: 'Confirmar validade',
        message: 'Data sugerida pelo OCR: ${fmt.format(parsed)}',
        confirmLabel: 'Usar data',
        cancelLabel: 'Cancelar',
      );

      if (confirm == true && mounted) {
        setState(() {
          _expiryDate = parsed;
          _noExpiry = false;
        });
      }
    } finally {
      await recognizer.close();
    }
  }

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

    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    String? shelfLocation;
    if (_manualLocation) {
      shelfLocation = _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim();
    } else {
      shelfLocation = _selectedLocationLabel;
    }

    if (shelfLocation == null || shelfLocation.isEmpty) {
      showCasaSnackbar(
        context,
        message: 'Selecione uma localizacao ou preencha manualmente.',
        isError: true,
      );
      return;
    }

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
        shelfLocation: shelfLocation,
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
    final locationsState = ref.watch(activeLocationsProvider);
    final isLoading = formState is AsyncLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ModernProfileAppBar(
        title: 'Cadastrar Lote',
        subtitle: 'Novo lote de produto',
        showBackButton: true,
      ),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _scanExpiryDateWithOcr,
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('Ler validade pela câmera (OCR)'),
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
                // ignore: deprecated_member_use
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

              locationsState.when(
                data: (locations) {
                  final items = locations
                      .map((l) => DropdownMenuItem<String>(
                            value: l.label,
                            child: Text(l.label),
                          ))
                      .toList();

                  return Column(
                    children: [
                      if (locations.isNotEmpty)
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _manualLocation ? null : _selectedLocationLabel,
                          decoration: const InputDecoration(
                            labelText: 'Localizacao estruturada',
                            prefixIcon:
                                Icon(Icons.inventory_2_outlined, size: 20),
                          ),
                          items: items,
                          onChanged: (v) {
                            setState(() {
                              _selectedLocationLabel = v;
                              _manualLocation = false;
                            });
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.warning600.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: AppColors.warning600, size: 18),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Nenhuma localizacao cadastrada.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.warning600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _manualLocation = !_manualLocation;
                                  if (_manualLocation) {
                                    _selectedLocationLabel = null;
                                  }
                                });
                              },
                              icon: Icon(
                                _manualLocation
                                    ? Icons.check_circle_rounded
                                    : Icons.edit_location_alt_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _manualLocation
                                    ? 'Usando preenchimento manual'
                                    : 'Preencher localizacao manualmente',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => context.push(AppRoutes.locations),
                              icon: const Icon(Icons.settings_outlined, size: 18),
                              label: const Text('Gerenciar localizacoes'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const CasaCardSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.md),

              if (_manualLocation) ...[
                CasaTextField(
                  label: 'Localizacao manual (Sala/Prateleira/Nivel)',
                  controller: _locationController,
                  prefixIcon:
                      const Icon(Icons.location_on_outlined, size: 20),
                  hint: 'Ex: Dep-A / P3 / N2',
                ),
                const SizedBox(height: AppSpacing.md),
              ],

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
