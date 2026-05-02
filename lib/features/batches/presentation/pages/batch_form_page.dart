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
import '../../../locations/domain/entities/storage_location.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
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

    final existingProductId = widget.productId.trim();
    Product? linkedProduct;
    if (existingProductId.isNotEmpty) {
      linkedProduct = await ref.read(productsDatasourceProvider).getProductById(existingProductId);
    }
    if (!mounted) return;
    final isPerishable = linkedProduct?.isPerishable ?? !_noExpiry;

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

    var effectiveProductId = existingProductId;
    if (linkedProduct == null) {
      final activeCategories = ref.read(activeProductCategoriesProvider);
      final fallbackCategory = activeCategories.contains(ProductCategory.outro)
          ? ProductCategory.outro
          : activeCategories.first;

      final created = Product(
        id: '',
        name: productName,
        brand: null,
        category: fallbackCategory,
        unit: 'un',
        isPerishable: !_noExpiry,
        minimumStock: 0,
        createdAt: DateTime.now(),
        createdBy: user.id,
      );
      effectiveProductId =
          await ref.read(productsDatasourceProvider).saveProduct(created);
    }

    final batch = Batch(
      id: '',
      productId: effectiveProductId,
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
          context.go('/products/$effectiveProductId');
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
                data: (locations) => _LocationPicker(
                  locations: locations,
                  selectedLabel: _manualLocation ? null : _selectedLocationLabel,
                  onChanged: (label) => setState(() {
                    _selectedLocationLabel = label;
                    _manualLocation = false;
                  }),
                  onManual: () => setState(() {
                    _manualLocation = !_manualLocation;
                    if (_manualLocation) _selectedLocationLabel = null;
                  }),
                  onManageLocations: () => context.push(AppRoutes.locations),
                ),
                loading: () => const CasaCardSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.sm),

              if (_manualLocation) ...[
                CasaTextField(
                  label: 'Localização manual (Sala/Prateleira/Nível)',
                  controller: _locationController,
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
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

// ---------------------------------------------------------------------------
// Seletor de localização estruturado: Seção → Prateleira → Nível c/ capacidade
// ---------------------------------------------------------------------------

class _LocationPicker extends ConsumerStatefulWidget {
  final List<StorageLocation> locations;
  final String? selectedLabel;
  final ValueChanged<String?> onChanged;
  final VoidCallback onManual;
  final VoidCallback onManageLocations;

  const _LocationPicker({
    required this.locations,
    required this.selectedLabel,
    required this.onChanged,
    required this.onManual,
    required this.onManageLocations,
  });

  @override
  ConsumerState<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<_LocationPicker> {
  String? _section;
  String? _shelf;
  String? _level;

  @override
  void didUpdateWidget(covariant _LocationPicker old) {
    super.didUpdateWidget(old);
    if (widget.selectedLabel == null && old.selectedLabel != null) {
      setState(() {
        _section = null;
        _shelf = null;
        _level = null;
      });
    }
  }

  List<String> get _sections {
    final s = widget.locations.map((l) => l.section).toSet().toList();
    s.sort();
    return s;
  }

  List<StorageLocation> get _locInSection =>
      widget.locations.where((l) => l.section == _section).toList();

  List<String> get _shelves {
    final s = _locInSection.map((l) => l.shelf).toSet().toList();
    s.sort();
    return s;
  }

  List<StorageLocation> get _locInShelf =>
      _locInSection.where((l) => l.shelf == _shelf).toList();

  StorageLocation? _findLoc(String? level) {
    for (final l in _locInShelf) {
      if (l.level == level) return l;
    }
    return null;
  }

  void _pickSection(String s) {
    setState(() {
      _section = s;
      _shelf = null;
      _level = null;
    });
    widget.onChanged(null);
  }

  void _pickShelf(String s) {
    setState(() {
      _shelf = s;
      _level = null;
    });
    widget.onChanged(null);
  }

  void _pickLevel(String? lv) {
    setState(() => _level = lv);
    final loc = _findLoc(lv);
    widget.onChanged(loc?.label);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.locations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warning600.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.warning600.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.warning600, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nenhuma localização cadastrada.',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.warning600),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: widget.onManageLocations,
                    icon: const Icon(Icons.add_location_alt_outlined, size: 15),
                    label: const Text('Criar localização'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary600,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.layers_rounded,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Localização no Estoque',
                style: AppTypography.labelLarge.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onManageLocations,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Gerenciar'),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Seção
          _StepLabel(label: '1. Seção', done: _section != null),
          const SizedBox(height: AppSpacing.xs),
          _ChipRow(
            items: _sections,
            selected: _shelf != null ? _section : _section,
            onTap: _pickSection,
            activeColor: AppColors.brandPrimary600,
          ),

          // Prateleira
          if (_section != null) ...[
            const SizedBox(height: AppSpacing.md),
            _StepLabel(label: '2. Prateleira', done: _shelf != null),
            const SizedBox(height: AppSpacing.xs),
            _ChipRow(
              items: _shelves,
              selected: _shelf,
              onTap: _pickShelf,
              activeColor: AppColors.secondaryBlue600,
            ),
          ],

          // Nível
          if (_shelf != null) ...[
            const SizedBox(height: AppSpacing.md),
            _StepLabel(label: '3. Nível', done: _level != null),
            const SizedBox(height: AppSpacing.xs),
            _buildLevels(cs, isDark),
          ],

          // Confirmação
          if (widget.selectedLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success600.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(
                    color: AppColors.success600.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.selectedLabel!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.success600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _section = null;
                        _shelf = null;
                        _level = null;
                      });
                      widget.onChanged(null);
                    },
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.success600),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: widget.onManual,
            icon: const Icon(Icons.edit_location_alt_outlined, size: 15),
            label: const Text('Inserir manualmente'),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevels(ColorScheme cs, bool isDark) {
    final allBatches = ref.watch(allAvailableBatchesProvider).valueOrNull ?? [];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _locInShelf.map((loc) {
        final lv = loc.level ?? '—';
        final isSelected = _level == loc.level;
        final limit = loc.productsPerLevel;
        final count = limit != null
            ? allBatches
                .where((b) => b.shelfLocation == loc.label)
                .length
            : null;
        final isFull = limit != null && count != null && count >= limit;

        return GestureDetector(
          onTap: isFull ? null : () => _pickLevel(loc.level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(colors: [
                      AppColors.brandPrimary600,
                      AppColors.secondaryBlue600,
                    ])
                  : null,
              color: isSelected
                  ? null
                  : isFull
                      ? AppColors.danger600.withValues(alpha: 0.08)
                      : cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : isFull
                        ? AppColors.danger600.withValues(alpha: 0.45)
                        : cs.outlineVariant,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.brandPrimary600.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'N$lv',
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected
                            ? Colors.white
                            : isFull
                                ? AppColors.danger600
                                : cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isFull) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.block_rounded,
                          size: 11, color: AppColors.danger600),
                    ],
                  ],
                ),
                if (limit != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 42,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (count! / limit).clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: isSelected
                            ? Colors.white.withValues(alpha: 0.3)
                            : cs.outlineVariant,
                        valueColor: AlwaysStoppedAnimation(
                          isSelected
                              ? Colors.white
                              : isFull
                                  ? AppColors.danger600
                                  : AppColors.success600,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '$count/$limit',
                    style: TextStyle(
                      fontSize: 9,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : isFull
                              ? AppColors.danger600
                              : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String label;
  final bool done;
  const _StepLabel({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 13,
          color: done ? AppColors.success600 : cs.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: done ? AppColors.success600 : cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> items;
  final String? selected;
  final ValueChanged<String> onTap;
  final Color activeColor;

  const _ChipRow({
    required this.items,
    required this.selected,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isSelected = item == selected;
          return GestureDetector(
            onTap: () => onTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          activeColor,
                          activeColor.withValues(alpha: 0.75)
                        ],
                      )
                    : null,
                color: isSelected ? null : cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : activeColor.withValues(alpha: 0.4),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Text(
                item,
                style: AppTypography.labelMedium.copyWith(
                  color: isSelected ? Colors.white : activeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
