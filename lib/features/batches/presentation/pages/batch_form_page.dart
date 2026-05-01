import 'dart:io';
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
import '../../../products/presentation/controllers/products_provider.dart';
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
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _locationController = TextEditingController();
  final _donorController = TextEditingController();
  final _notesController = TextEditingController();
  final _batchNumberController = TextEditingController();

  DateTime? _expiryDate;
  final DateTime _entryDate = DateTime.now();
  bool _noExpiry = false;
  String _origin = 'doacao';
  bool _manualLocation = false;
  String? _selectedLocationLabel;
  File? _imageFile;
  bool _prefilledProductName = false;
  int _quantity = 1;
  final _imagePicker = ImagePicker();

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
  void initState() {
    super.initState();
    _quantityController.text = '1';
  }

  DateTime? _tryParseDateFromText(String text) {
    final matches = RegExp(r'(\d{2})[\/-](\d{2})[\/-](\d{2,4})')
        .allMatches(text)
        .toList();
    final now = DateTime.now();

    for (final match in matches) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      var year = int.tryParse(match.group(3)!);
      if (day == null || month == null || year == null) continue;
      if (year < 100) year += 2000;

      try {
        final parsed = DateTime(year, month, day);
        if (!parsed.isBefore(DateTime(now.year - 1))) {
          return parsed;
        }
      } catch (_) {}
    }
    return null;
  }

  String? _tryParseBatchNumberFromText(String text) {
    final loteRegex = RegExp(
      r'(?:lote|lot|l\.?)(?:\s|:|#|-)*([a-zA-Z0-9\-]{3,})',
      caseSensitive: false,
    );
    final loteMatch = loteRegex.firstMatch(text);
    if (loteMatch != null) {
      return loteMatch.group(1)?.trim();
    }

    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.length >= 4)
        .toList();
    for (final line in lines) {
      if (RegExp(r'^[A-Z0-9\-]{4,}$').hasMatch(line)) return line;
    }
    return null;
  }

  String? _tryParseProductNameFromText(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.length >= 3 && e.length <= 50)
        .toList();
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('lote') ||
          lower.contains('valid') ||
          lower.contains('fabrica') ||
          lower.contains('ingrediente') ||
          RegExp(r'\d{2}[\/-]\d{2}[\/-]\d{2,4}').hasMatch(lower)) {
        continue;
      }
      if (RegExp(r'[a-zA-Z]{3,}').hasMatch(line)) return line;
    }
    return null;
  }

  void _setQuantity(int value) {
    final normalized = value < 1 ? 1 : value;
    setState(() {
      _quantity = normalized;
      _quantityController.text = normalized.toString();
    });
  }

  Future<void> _scanPackagingWithOcr() async {
    final file = await _imagePicker.pickImage(source: ImageSource.camera);
    if (file == null) return;

    final inputImage = InputImage.fromFilePath(file.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(inputImage);
      final parsedDate = _tryParseDateFromText(result.text);
      final parsedBatch = _tryParseBatchNumberFromText(result.text);
      final parsedName = _tryParseProductNameFromText(result.text);

      if (parsedDate == null && parsedBatch == null && parsedName == null) {
        if (!mounted) return;
        showCasaSnackbar(
          context,
          message: 'Não foi possível identificar dados automáticos da embalagem.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      final fmt = DateFormat('dd/MM/yyyy');
      final confirm = await CasaDialogConfirmacao.show(
        context: context,
        title: 'Confirmar dados detectados',
        message:
            'Nome: ${parsedName ?? '-'}\nLote: ${parsedBatch ?? '-'}\nValidade: ${parsedDate != null ? fmt.format(parsedDate) : '-'}',
        confirmLabel: 'Aplicar dados',
        cancelLabel: 'Cancelar',
      );

      if (confirm == true && mounted) {
        setState(() {
          if (parsedDate != null) {
            _expiryDate = parsedDate;
            _noExpiry = false;
          }
          if (parsedBatch != null && _batchNumberController.text.trim().isEmpty) {
            _batchNumberController.text = parsedBatch;
          }
          if (parsedName != null && _productNameController.text.trim().isEmpty) {
            _productNameController.text = parsedName;
          }
          _imageFile = File(file.path);
        });
      }
    } finally {
      await recognizer.close();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _locationController.dispose();
    _donorController.dispose();
    _notesController.dispose();
    _batchNumberController.dispose();
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

    final isPerishable =
        ref.read(productByIdProvider(widget.productId)).valueOrNull?.isPerishable ?? true;

    // Validação crítica: perecível exige validade ou flag noExpiry
    if (isPerishable && !_noExpiry && _expiryDate == null) {
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

    final qty = int.tryParse(_quantityController.text) ?? _quantity;
    if (qty <= 0) {
      showCasaSnackbar(
        context,
        message: 'Informe uma quantidade maior que zero.',
        isError: true,
      );
      return;
    }

    final productName = _productNameController.text.trim();
    if (productName.isEmpty) {
      showCasaSnackbar(
        context,
        message: 'Informe o nome do produto.',
        isError: true,
      );
      return;
    }

    final unitPrice = _origin == 'compra'
        ? double.tryParse(_unitPriceController.text.replaceAll(',', '.'))
        : null;

    if (_origin == 'compra' && (unitPrice == null || unitPrice < 0)) {
      showCasaSnackbar(
        context,
        message: 'Informe um preço unitário válido para compras.',
        isError: true,
      );
      return;
    }

    final batch = Batch(
      id: '',
      productId: widget.productId,
      productName: productName,
      quantity: qty,
      initialQuantity: qty,
      expiryDate: _noExpiry ? null : _expiryDate,
      noExpiry: _noExpiry,
      entryDate: _entryDate,
      origin: _origin,
      donor: _donorController.text.trim().isEmpty
          ? null
          : _donorController.text.trim(),
      batchNumber: _batchNumberController.text.trim().isEmpty
          ? null
          : _batchNumberController.text.trim(),
        supplier: _origin == 'compra' ? _donorController.text.trim() : null,
        unitPrice: unitPrice,
      shelfLocation: shelfLocation,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdBy: user.id,
      createdAt: DateTime.now(),
    );

    await ref.read(batchFormProvider.notifier).saveBatch(batch, imageFile: _imageFile);

    final state = ref.read(batchFormProvider);
    if (!mounted) return;
    state.when(
      data: (id) {
        if (id != null) {
          showCasaSnackbar(context, message: 'Produto adicionado ao estoque!', isSuccess: true);
          context.go('/products/${widget.productId}');
        }
      },
      error: (e, _) => showCasaSnackbar(context,
          message: 'Erro ao salvar cadastro.', isError: true),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final formState = ref.watch(batchFormProvider);
    final locationsState = ref.watch(activeLocationsProvider);
    final isLoading = formState is AsyncLoading;
    final productAsync = ref.watch(productByIdProvider(widget.productId));
    final productName = productAsync.valueOrNull?.name;
    if (!_prefilledProductName && productName != null) {
      _productNameController.text = productName;
      _prefilledProductName = true;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernProfileAppBar(
        title: 'Cadastrar Produto',
        subtitle: productName != null ? 'Produto: $productName' : 'Adicionar ao estoque',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.info600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.info600, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Use a câmera para preencher automaticamente nome, lote e validade da embalagem.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.info600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _scanPackagingWithOcr,
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: const Text('Ler embalagem automaticamente (OCR)'),
              ),
              const SizedBox(height: AppSpacing.lg),

              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.neutral100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dados principais do produto',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.neutral900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaTextField(
                      label: 'Nome do Produto *',
                      hint: 'Ex: Arroz Integral 1kg',
                      controller: _productNameController,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Informe o nome do produto' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaTextField(
                      label: 'Número do Lote (embalagem)',
                      hint: 'Ex: LOT20251201, L4578',
                      controller: _batchNumberController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Quantidade *',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.neutral700,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _quantity > 1 ? () => _setQuantity(_quantity - 1) : null,
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              SizedBox(
                                width: 42,
                                child: Text(
                                  '$_quantity',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.headingSmall.copyWith(
                                    color: AppColors.neutral900,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _setQuantity(_quantity + 1),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final add in [5, 10, 20])
                          ActionChip(
                            label: Text('+$add'),
                            onPressed: () => _setQuantity(_quantity + add),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.neutral100),
                ),
                child: CheckboxListTile(
                  title: Text(
                    'Sem validade definida',
                    style: AppTypography.labelLarge.copyWith(color: AppColors.neutral900),
                  ),
                  subtitle: Text(
                    'Marque para itens não perecíveis',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
                  ),
                  value: _noExpiry,
                  onChanged: (v) => setState(() => _noExpiry = v ?? false),
                  activeColor: AppColors.brandPrimary600,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (!_noExpiry) ...[
                InkWell(
                  onTap: _pickExpiryDate,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de Validade *',
                      prefixIcon: Icon(Icons.event_rounded, size: 20),
                      suffixIcon: Icon(Icons.chevron_right_rounded, size: 20),
                    ),
                    child: Text(
                      _expiryDate != null ? fmt.format(_expiryDate!) : 'Toque para selecionar',
                      style: AppTypography.bodyLarge.copyWith(
                        color: _expiryDate != null ? AppColors.neutral900 : AppColors.neutral500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              DropdownButtonFormField<String>(
                initialValue: _origin,
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
                label: _origin == 'compra' ? 'Fornecedor' : 'Doador / Fornecedor',
                controller: _donorController,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              ),
              if (_origin == 'compra') ...[
                const SizedBox(height: AppSpacing.md),
                CasaTextField(
                  label: 'Preço unitário (R\$) *',
                  hint: 'Ex: 12,50',
                  controller: _unitPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total estimado: R\$ ${((double.tryParse(_unitPriceController.text.replaceAll(',', '.')) ?? 0) * _quantity).toStringAsFixed(2)}',
                    style: AppTypography.labelMedium.copyWith(color: AppColors.success600),
                  ),
                ),
              ],
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
              const SizedBox(height: AppSpacing.md),

              // --- Foto da embalagem ---
              _ImagePickerSection(
                imageFile: _imageFile,
                onPickCamera: () => _pickImage(ImageSource.camera),
                onPickGallery: () => _pickImage(ImageSource.gallery),
                onRemove: () => setState(() => _imageFile = null),
              ),
              const SizedBox(height: AppSpacing.xxl),

              CasaButton(
                label: 'Adicionar Produto ao Estoque',
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

// ---------------------------------------------------------------------------
// Widget de seleção/visualização de imagem do lote
// ---------------------------------------------------------------------------

class _ImagePickerSection extends StatelessWidget {
  final File? imageFile;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  const _ImagePickerSection({
    required this.imageFile,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto da Embalagem (opcional)',
          style: AppTypography.labelLarge.copyWith(color: AppColors.neutral700),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (imageFile != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Image.file(
              imageFile!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger600),
            label: Text(
              'Remover foto',
              style: AppTypography.labelMedium.copyWith(color: AppColors.danger600),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickCamera,
                  icon: const Icon(Icons.photo_camera_rounded, size: 20),
                  label: const Text('Câmera'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Galeria'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
