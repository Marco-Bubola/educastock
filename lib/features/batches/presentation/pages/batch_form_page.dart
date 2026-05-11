import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
  final _keyBatchQty = GlobalKey();
  final _keyBatchExpiry = GlobalKey();
  final _keyBatchLocation = GlobalKey();
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
  bool _prefilledProductName = false;
  int _quantity = 1;


  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
  }

  void _setQuantity(int value) {
    final normalized = value < 1 ? 1 : value;
    setState(() {
      _quantity = normalized;
      _quantityController.text = normalized.toString();
    });
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
    final isPerishable = linkedProduct?.isPerishable ?? true;

    // Se nao perecivel, define noExpiry automaticamente
    if (!isPerishable) {
      _noExpiry = true;
      _expiryDate = null;
    }

    // Validacao critica: perecivel exige validade
    if (isPerishable && !_noExpiry && _expiryDate == null) {
      showCasaSnackbar(
        context,
        message: 'Informe a data de validade do lote.',
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

    await ref.read(batchFormProvider.notifier).saveBatch(batch);

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
    final cs = Theme.of(context).colorScheme;
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
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Cadastrar Lote',
        subtitle: productName != null ? 'Produto: $productName' : 'Adicionar ao estoque',
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyBatchQty,
                  title: 'Número do Lote e Quantidade',
                  description: 'Informe o número de identificação do lote (código da embalagem) e a quantidade de unidades recebidas. O número do lote permite rastrear a origem de cada item.',
                  icon: Icons.tag_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Use o código impresso na embalagem do fornecedor',
                    'A quantidade deve ser em unidades (peças, latas, caixas)',
                    'Um lote = uma entrada de estoque com mesma origem e validade',
                  ],
                ),
                TutorialStep(
                  key: _keyBatchExpiry,
                  title: 'Data de Validade',
                  description: 'Informe a data de validade impressa na embalagem. Use os atalhos (+30, +90, +180 dias) para datas aproximadas ou o escaner para ler QR codes com data.',
                  icon: Icons.event_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Sempre registre a data exata da embalagem',
                    'Lotes vencidos são automaticamente bloqueados para saída',
                    'Produtos não perecíveis não precisam de data de validade',
                  ],
                ),
                TutorialStep(
                  key: _keyBatchLocation,
                  title: 'Localização no Estoque',
                  description: 'Selecione onde este lote está fisicamente armazenado na instituição. Localizações ajudam a encontrar produtos rapidamente e organizar o espaço físico.',
                  icon: Icons.location_on_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Ex: "Prateleira A-3", "Depósito 2", "Cozinha"',
                    'Crie novas localizações em Configurações → Localizações',
                    'A localização aparece na lista de lotes e relatórios',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _BatchSaveFab(isLoading: isLoading, onSave: _submit),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
            children: [

              // â”€â”€â”€ SeÃ§Ã£o 1: NÃºmero do lote + Quantidade â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              KeyedSubtree(
                key: _keyBatchQty,
                child: _BatchSection(
                  icon: Icons.tag_rounded,
                  iconColor: AppColors.brandPrimary600,
                  title: 'Informações do Lote',
                cs: cs,
                child: Column(
                  children: [
                    CasaTextField(
                      label: 'NÃºmero do Lote (embalagem)',
                      hint: 'Ex: LOT20251201, L4578',
                      controller: _batchNumberController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_rounded,
                              size: 18, color: AppColors.brandPrimary600),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Quantidade',
                              style: AppTypography.labelMedium
                                  .copyWith(color: cs.onSurface)),
                          const Spacer(),
                          for (final add in [5, 10, 20])
                            GestureDetector(
                              onTap: () => _setQuantity(_quantity + add),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary600
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                  border: Border.all(
                                      color: AppColors.brandPrimary600
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Text('+$add',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.brandPrimary600,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Row(
                            children: [
                              _QtyBtn(
                                icon: Icons.remove_rounded,
                                enabled: _quantity > 1,
                                onTap: () => _setQuantity(_quantity - 1),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '$_quantity',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.headingSmall.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _QtyBtn(
                                icon: Icons.add_rounded,
                                enabled: true,
                                onTap: () => _setQuantity(_quantity + 1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // --- Secao 2: Validade ---
              Builder(builder: (_) {
                final isPerishable = productAsync.valueOrNull?.isPerishable ?? true;
                if (!isPerishable) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_noExpiry) setState(() { _noExpiry = true; _expiryDate = null; });
                  });
                  return KeyedSubtree(
                    key: _keyBatchExpiry,
                    child: _BatchSection(
                      icon: Icons.all_inclusive_rounded,
                      iconColor: AppColors.neutral500,
                      title: 'Validade',
                      cs: cs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.neutral500.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AppColors.neutral500.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 18, color: AppColors.neutral500),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Produto nao perecivel - sem data de validade',
                                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return KeyedSubtree(
                  key: _keyBatchExpiry,
                  child: _BatchSection(
                    icon: Icons.event_rounded,
                    iconColor: _expiryDate != null ? AppColors.success600 : AppColors.warning600,
                    title: 'Validade',
                    cs: cs,
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _QuickDateChip(label: '+30 dias', onTap: () => setState(() => _expiryDate = DateTime.now().add(const Duration(days: 30)))),
                          _QuickDateChip(label: '+90 dias', onTap: () => setState(() => _expiryDate = DateTime.now().add(const Duration(days: 90)))),
                          _QuickDateChip(label: '+180 dias', onTap: () => setState(() => _expiryDate = DateTime.now().add(const Duration(days: 180)))),
                          _QuickDateChip(label: '+1 ano', onTap: () => setState(() => _expiryDate = DateTime.now().add(const Duration(days: 365)))),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: _expiryDate != null
                                    ? AppColors.success600.withValues(alpha: 0.08)
                                    : cs.surfaceContainer,
                                borderRadius: BorderRadius.circular(AppRadius.input),
                                border: Border.all(
                                  color: _expiryDate != null
                                      ? AppColors.success600.withValues(alpha: 0.45)
                                      : cs.outlineVariant.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded, size: 18,
                                      color: _expiryDate != null ? AppColors.success600 : cs.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Text(
                                    _expiryDate != null ? fmt.format(_expiryDate!) : 'Selecione a validade',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _expiryDate != null ? FontWeight.w700 : FontWeight.w400,
                                      color: _expiryDate != null ? cs.onSurface : cs.onSurfaceVariant,
                                    ),
                                  ),
                                  if (_expiryDate != null) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(() => _expiryDate = null),
                                      child: Icon(Icons.close_rounded, size: 14, color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: _pickExpiryDate,
                            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                            label: const Text('Outra data'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brandPrimary600,
                              side: const BorderSide(color: AppColors.brandPrimary600),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ExpiryOcrButton(
                            onDateSuggested: (date) {
                              setState(() => _expiryDate = date);
                              showCasaSnackbar(
                                context,
                                message: 'Data lida: ${DateFormat('dd/MM/yyyy').format(date)} — confirme se está correta',
                                isSuccess: true,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.md),

              // â”€â”€â”€ SeÃ§Ã£o 3: Origem â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _BatchSection(
                icon: Icons.source_outlined,
                iconColor: AppColors.secondaryBlue600,
                title: 'Origem',
                cs: cs,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _OriginCard(
                          originKey: 'doacao',
                          label: 'DoaÃ§Ã£o',
                          icon: Icons.volunteer_activism_rounded,
                          color: AppColors.success600,
                          selected: _origin == 'doacao',
                          onTap: () => setState(() => _origin = 'doacao'),
                          cs: cs,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _OriginCard(
                          originKey: 'compra',
                          label: 'Compra',
                          icon: Icons.shopping_cart_rounded,
                          color: AppColors.brandPrimary600,
                          selected: _origin == 'compra',
                          onTap: () => setState(() => _origin = 'compra'),
                          cs: cs,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _OriginCard(
                          originKey: 'parceiro',
                          label: 'Parceiro',
                          icon: Icons.handshake_rounded,
                          color: AppColors.warning600,
                          selected: _origin == 'parceiro',
                          onTap: () =>
                              setState(() => _origin = 'parceiro'),
                          cs: cs,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _OriginCard(
                          originKey: 'transferencia',
                          label: 'Transfer.',
                          icon: Icons.swap_horiz_rounded,
                          color: AppColors.secondaryBlue600,
                          selected: _origin == 'transferencia',
                          onTap: () =>
                              setState(() => _origin = 'transferencia'),
                          cs: cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaTextField(
                      label: _origin == 'compra'
                          ? 'Fornecedor'
                          : 'Doador / Parceiro',
                      controller: _donorController,
                      prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20),
                    ),
                    if (_origin == 'compra') ...[
                      const SizedBox(height: AppSpacing.md),
                      CasaTextField(
                        label: 'PreÃ§o unitÃ¡rio (R\$) *',
                        hint: 'Ex: 12,50',
                        controller: _unitPriceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        prefixIcon: const Icon(Icons.attach_money_rounded,
                            size: 20),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total: R\$ ${((double.tryParse(_unitPriceController.text.replaceAll(',', '.')) ?? 0) * _quantity).toStringAsFixed(2)}',
                          style: AppTypography.labelSmall
                              .copyWith(color: AppColors.success600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // â”€â”€â”€ SeÃ§Ã£o 4: LocalizaÃ§Ã£o â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              locationsState.when(
                data: (locations) => KeyedSubtree(
                  key: _keyBatchLocation,
                  child: _LocationPicker(
                  locations: locations,
                  selectedLabel:
                      _manualLocation ? null : _selectedLocationLabel,
                  onChanged: (label) => setState(() {
                    _selectedLocationLabel = label;
                    _manualLocation = false;
                  }),
                  onManual: () => setState(() {
                    _manualLocation = !_manualLocation;
                    if (_manualLocation) _selectedLocationLabel = null;
                  }),
                  onManageLocations: () =>
                      context.push(AppRoutes.locations),
                ),
                ),
                loading: () => const CasaCardSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              if (_manualLocation) ...[
                const SizedBox(height: AppSpacing.sm),
                CasaTextField(
                  label: 'LocalizaÃ§Ã£o manual (Sala/Prateleira/NÃ­vel)',
                  controller: _locationController,
                  prefixIcon:
                      const Icon(Icons.location_on_outlined, size: 20),
                  hint: 'Ex: Dep-A / P3 / N2',
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // â”€â”€â”€ SeÃ§Ã£o 5: ObservaÃ§Ãµes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _BatchSection(
                icon: Icons.notes_rounded,
                iconColor: AppColors.neutral500,
                title: 'ObservaÃ§Ãµes (opcional)',
                cs: cs,
                child: CasaTextField(
                  label: '',
                  hint: 'InformaÃ§Ãµes adicionais sobre este lote...',
                  controller: _notesController,
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€ FAB de confirmaÃ§Ã£o â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// --- FAB compacto de cadastro ---

class _BatchSaveFab extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSave;
  const _BatchSaveFab({required this.isLoading, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : const LinearGradient(colors: [
                  AppColors.brandPrimary600,
                  AppColors.secondaryBlue600
                ]),
          color: isLoading ? AppColors.neutral500 : null,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: [
            BoxShadow(
                color: AppColors.brandPrimary600.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
          icon: isLoading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.inventory_2_rounded, size: 18, color: Colors.white),
          label: const Text(
            'Cadastrar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

// --- Secao de card do formulario ---

class _BatchSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final ColorScheme cs;
  const _BatchSection(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.child,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.labelLarge.copyWith(
                    color: cs.onSurface, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

// â”€â”€â”€ BotÃ£o de quantidade â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.brandPrimary600.withValues(alpha: 0.1)
              : cs.surfaceContainer,
          shape: BoxShape.circle,
          border: Border.all(
              color: enabled
                  ? AppColors.brandPrimary600.withValues(alpha: 0.3)
                  : cs.outlineVariant),
        ),
        child: Icon(icon,
            size: 16,
            color:
                enabled ? AppColors.brandPrimary600 : cs.onSurfaceVariant),
      ),
    );
  }
}

// --- Chip de data rapida ---

class _QuickDateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickDateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.brandPrimary600.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.brandPrimary600.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brandPrimary600),
        ),
      ),
    );
  }
}

// --- Card de origem ---

class _OriginCard extends StatelessWidget {
  final String originKey;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _OriginCard({required this.originKey, required this.label, required this.icon, required this.color, required this.selected, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected
                  ? color
                  : cs.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? color : cs.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? color : cs.onSurfaceVariant,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

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