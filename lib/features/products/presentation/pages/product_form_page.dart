import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../domain/entities/product.dart';
import '../controllers/products_provider.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  final String? productId;
  final String? barcode;
  final String? prefillName;
  final String? prefillBrand;
  final String? prefillCategory;
  final String? prefillImageUrl;
  final String? prefillIsPerishable;
  final String? prefillUnit;
  final String? prefillUnitSize;
  final String? prefillDescription;

  const ProductFormPage({
    super.key,
    this.productId,
    this.barcode,
    this.prefillName,
    this.prefillBrand,
    this.prefillCategory,
    this.prefillImageUrl,
    this.prefillIsPerishable,
    this.prefillUnit,
    this.prefillUnitSize,
    this.prefillDescription,
  });

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _keyNameField = GlobalKey();
  final _keyCategoryField = GlobalKey();
  final _keyPerishableToggle = GlobalKey();
  final _keySaveBtn = GlobalKey();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descController = TextEditingController();
  final _unitSizeController = TextEditingController();

  ProductCategory _category = ProductCategory.alimento;
  String _unit = 'un';
  bool _isPerishable = true;
  int _minimumStock = 0;
  DateTime? _originalCreatedAt;
  String? _originalCreatedBy;
  File? _imageFile;
  String? _existingImageUrl;
  final _imagePicker = ImagePicker();

  // Unidades que precisam de tamanho de embalagem
  static const _sizedUnits = {'kg', 'g', 'L', 'mL'};
  bool get _needsSize => _sizedUnits.contains(_unit);

  final List<String> _units = ['un', 'kg', 'g', 'L', 'mL', 'cx', 'pct', 'frd'];

  String get _unitHint => switch (_unit) {
        'kg' => 'Ex: 1, 0.5, 5',
        'g' => 'Ex: 500, 250, 100',
        'L' => 'Ex: 1, 2, 0.5',
        'mL' => 'Ex: 250, 500, 1000',
        _ => '',
      };

  String get _unitLabel => switch (_unit) {
        'kg' => 'Quantidade em kg',
        'g' => 'Quantidade em gramas',
        'L' => 'Quantidade em litros',
        'mL' => 'Quantidade em mililitros',
        _ => '',
      };

  // Retorna a unidade final a ser salva (ex: "500g", "1kg", "2L")
  String get _effectiveUnit {
    if (_needsSize && _unitSizeController.text.trim().isNotEmpty) {
      return '${_unitSizeController.text.trim()}$_unit';
    }
    return _unit;
  }

  @override
  void initState() {
    super.initState();
    if (widget.prefillName != null) {
      _nameController.text = widget.prefillName!;
    }
    if (widget.prefillBrand != null) {
      _brandController.text = widget.prefillBrand!;
    }
    if (widget.prefillCategory != null) {
      try {
        _category = ProductCategory.values.firstWhere(
          (c) => c.name == widget.prefillCategory,
        );
      } catch (_) {}
    }
    // Pre-fill extra fields from API result (only for new products)
    if (widget.productId == null) {
      if (widget.prefillImageUrl != null && widget.prefillImageUrl!.isNotEmpty) {
        _existingImageUrl = widget.prefillImageUrl;
      }
      if (widget.prefillIsPerishable != null) {
        _isPerishable = widget.prefillIsPerishable == 'true';
      }
      if (widget.prefillUnit != null &&
          widget.prefillUnit!.isNotEmpty &&
          _units.contains(widget.prefillUnit)) {
        _unit = widget.prefillUnit!;
      }
      if (widget.prefillUnitSize != null && widget.prefillUnitSize!.isNotEmpty) {
        _unitSizeController.text = widget.prefillUnitSize!;
      }
      if (widget.prefillDescription != null &&
          widget.prefillDescription!.isNotEmpty) {
        _descController.text = widget.prefillDescription!;
      }
    }
    // Carregar produto existente para editar
    if (widget.productId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final product = await ref
            .read(productsDatasourceProvider)
            .getProductById(widget.productId!);
        if (product != null && mounted) {
          // Decompõe unidade armazenada (ex: "500g" → size="500", unit="g")
          String storedUnit = product.unit;
          String storedSize = '';
          for (final u in _sizedUnits) {
            if (storedUnit.endsWith(u) && storedUnit.length > u.length) {
              storedSize = storedUnit.substring(0, storedUnit.length - u.length);
              storedUnit = u;
              break;
            }
          }
          setState(() {
            _nameController.text = product.name;
            _brandController.text = product.brand ?? '';
            _descController.text = product.description ?? '';
            _category = product.category;
            _unit = storedUnit;
            _unitSizeController.text = storedSize;
            _isPerishable = product.isPerishable;
            _minimumStock = product.minimumStock;
            _originalCreatedAt = product.createdAt;
            _originalCreatedBy = product.createdBy;
            _existingImageUrl = product.imageUrl;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _descController.dispose();
    _unitSizeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final product = Product(
      id: widget.productId ?? '',
      name: _nameController.text.trim(),
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      category: _category,
      unit: _effectiveUnit,
      barcode: widget.barcode,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      isPerishable: _isPerishable,
      minimumStock: _minimumStock,
      createdAt: _originalCreatedAt ?? DateTime.now(),
      createdBy: _originalCreatedBy ?? user.id,
    );

    await ref.read(productFormProvider.notifier).saveProduct(
          product,
          imageFile: _imageFile,
        );

    final state = ref.read(productFormProvider);
    if (!mounted) return;
    state.when(
      data: (id) {
        if (id != null) {
          showCasaSnackbar(context,
              message: 'Produto salvo!', isSuccess: true);
          if (widget.productId != null) {
            // Edição: apenas volta
            context.pop();
          } else {
            // Criação: vai para cadastro de lote
            context.push('${AppRoutes.batchForm}?productId=$id');
          }
        }
      },
      error: (e, _) {
        String msg = 'Erro ao salvar produto.';
        final detail = e.toString();
        if (detail.contains('permission-denied') ||
            detail.contains('PERMISSION_DENIED')) {
          msg = 'Sem permissão para salvar. Verifique seu acesso.';
        } else if (detail.contains('network') ||
            detail.contains('unavailable') ||
            detail.contains('UNAVAILABLE')) {
          msg = 'Sem conexão com a internet. Tente novamente.';
        } else if (detail.contains('storage') ||
            detail.contains('object-not-found')) {
          msg = 'Erro ao enviar foto. Tente sem foto ou tente novamente.';
        } else if (detail.isNotEmpty) {
          msg = 'Erro: ${detail.length > 80 ? detail.substring(0, 80) : detail}';
        }
        showCasaSnackbar(context, message: msg, isError: true);
      },
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final formState = ref.watch(productFormProvider);
    final activeCategories = ref.watch(activeProductCategoriesProvider);
    final categoryLabelMap = ref.watch(categoryLabelMapProvider);
    if (!activeCategories.contains(_category)) {
      _category = activeCategories.first;
    }
    final isLoading = formState is AsyncLoading;
    final isEditing = widget.productId != null;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: isEditing ? 'Editar Produto' : 'Novo Produto',
        subtitle: isEditing ? 'Atualize os dados do produto' : 'Preencha as informações do produto',
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyNameField,
                  title: 'Nome do Produto',
                  description: 'Informe o nome completo e descritivo do produto. Use nomes claros como "Feijão Carioca 1kg" para facilitar a busca e identificação no estoque.',
                  icon: Icons.label_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Seja específico: inclua tipo e peso quando relevante',
                    'Use nomes padronizados que toda a equipe reconheça',
                    'O nome é usado em buscas, relatórios e receitas',
                  ],
                ),
                TutorialStep(
                  key: _keyCategoryField,
                  title: 'Categoria',
                  description: 'Selecione a categoria que melhor classifica o produto. As categorias organizam o estoque e permitem filtros e relatórios por grupo de produtos.',
                  icon: Icons.category_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Alimento: produtos comestíveis em geral',
                    'Higiene: sabonetes, fraldas, produtos de limpeza',
                    'Materiais: papelaria, itens educacionais, outros',
                  ],
                ),
                TutorialStep(
                  key: _keyPerishableToggle,
                  title: 'Produto Perecível',
                  description: 'Ative esta opção se o produto possui data de validade. Produtos perecíveis exigem informação de validade em cada lote cadastrado e geram alertas automáticos.',
                  icon: Icons.timer_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Alimentos e medicamentos: sempre perecíveis',
                    'Produtos de limpeza: geralmente não perecíveis',
                    'Perecíveis aparecem nos alertas e relatórios de vencimento',
                  ],
                ),
                TutorialStep(
                  key: _keySaveBtn,
                  title: 'Salvar Produto',
                  description: 'Toque para salvar o produto no catálogo. Após salvar, você poderá cadastrar lotes de estoque para este produto e registrar movimentações.',
                  icon: Icons.save_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Todos os campos obrigatórios devem estar preenchidos',
                    'Produtos salvos aparecem imediatamente na lista de estoque',
                    'Você pode editar as informações do produto a qualquer momento',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: KeyedSubtree(
        key: _keySaveBtn,
        child: _SaveBar(
          isEditing: isEditing,
          isLoading: isLoading,
          onSave: _submit,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
            children: [
              // Banner do código de barras
              if (widget.barcode != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandPrimary600.withValues(alpha: 0.08),
                        AppColors.brandPrimary600.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.brandPrimary100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary100,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Icon(Icons.qr_code_rounded,
                            color: AppColors.brandPrimary600, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Código de barras detectado',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.brandPrimary600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.barcode!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.brandPrimary700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // ── Seção: Identificação ──────────────────────────────
              _SectionLabel(
                icon: Icons.inventory_2_rounded,
                label: 'IDENTIFICAÇÃO',
                color: AppColors.brandPrimary600,
              ),
              const SizedBox(height: AppSpacing.sm),
              CasaTextField(
                key: _keyNameField,
                label: 'Nome do Produto *',
                hint: 'Ex: Arroz Integral, Sabonete Líquido...',
                controller: _nameController,
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(Icons.label_rounded, size: 20),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nome obrigatório' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CasaTextField(
                label: 'Marca',
                hint: 'Ex: Camil, Unilever...',
                controller: _brandController,
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(Icons.branding_watermark_rounded, size: 20),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Seção: Classificação ──────────────────────────────
              _SectionLabel(
                icon: Icons.category_rounded,
                label: 'CLASSIFICAÇÃO',
                color: AppColors.secondaryBlue600,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<ProductCategory>(
                key: _keyCategoryField,
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoria *',
                  prefixIcon: Icon(Icons.category_outlined, size: 20),
                ),
                items: activeCategories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            categoryLabelMap[c.name] ?? defaultCategoryLabel(c),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unidade de Medida *',
                  prefixIcon: Icon(Icons.straighten_outlined, size: 20),
                ),
                items: _units
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _unit = v!;
                  if (!_sizedUnits.contains(v)) {
                    _unitSizeController.clear();
                  }
                }),
              ),
              // Campo de tamanho da embalagem (aparece para kg, g, L, mL)
              if (_needsSize) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: CasaTextField(
                        label: _unitLabel,
                        hint: _unitHint,
                        controller: _unitSizeController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.scale_outlined, size: 20),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(
                            color: AppColors.brandPrimary600
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _unitSizeController.text.trim().isNotEmpty
                            ? '${_unitSizeController.text.trim()}$_unit'
                            : _unit,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.brandPrimary600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Exemplo: "500g", "1kg", "250mL" serão salvos como unidade.',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              // ── Seção: Configurações ──────────────────────────────
              _SectionLabel(
                icon: Icons.settings_rounded,
                label: 'CONFIGURAÇÕES',
                color: AppColors.success600,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Perecível
              Container(
                key: _keyPerishableToggle,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: _isPerishable
                        ? AppColors.warning600.withValues(alpha: 0.4)
                        : cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  secondary: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isPerishable
                          ? AppColors.warning600.withValues(alpha: 0.12)
                          : cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: _isPerishable
                          ? AppColors.warning600
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    'Produto Perecível',
                    style: AppTypography.labelLarge
                        .copyWith(color: cs.onSurface),
                  ),
                  subtitle: Text(
                    _isPerishable
                        ? 'Validade obrigatória nos lotes'
                        : 'Sem controle de validade',
                    style: AppTypography.bodySmall.copyWith(
                      color: _isPerishable
                          ? AppColors.warning600
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  value: _isPerishable,
                  onChanged: (v) => setState(() => _isPerishable = v),
                  activeThumbColor: AppColors.warning600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Estoque mínimo
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.danger600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          size: 20, color: AppColors.danger600),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estoque Mínimo',
                            style: AppTypography.labelLarge
                                .copyWith(color: cs.onSurface),
                          ),
                          Text(
                            'Alerta abaixo deste valor',
                            style: AppTypography.bodySmall
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_minimumStock > 0) {
                              setState(() => _minimumStock--);
                            }
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainer,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: cs.outlineVariant),
                            ),
                            child: Icon(Icons.remove_rounded,
                                size: 16, color: cs.onSurfaceVariant),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '$_minimumStock',
                            textAlign: TextAlign.center,
                            style: AppTypography.headingSmall.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _minimumStock++),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.brandPrimary600,
                                  AppColors.secondaryBlue600,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Seção: Observações ──────────────────────────────
              _SectionLabel(
                icon: Icons.notes_rounded,
                label: 'OBSERVAÇÕES',
                color: AppColors.neutral500,
              ),
              const SizedBox(height: AppSpacing.sm),
              CasaTextField(
                label: 'Descrição (opcional)',
                hint: 'Informações adicionais sobre o produto...',
                controller: _descController,
                maxLines: 3,
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Seção: Foto do Produto ─────────────────────────
              _SectionLabel(
                icon: Icons.photo_camera_rounded,
                label: 'FOTO DO PRODUTO',
                color: AppColors.brandPrimary600,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProductImagePicker(
                imageFile: _imageFile,
                existingImageUrl: _existingImageUrl,
                cs: cs,
                onPickCamera: () async {
                  final picked = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                    maxWidth: 1280,
                  );
                  if (picked != null && mounted) {
                    setState(() => _imageFile = File(picked.path));
                  }
                },
                onPickGallery: () async {
                  final picked = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                    maxWidth: 1280,
                  );
                  if (picked != null && mounted) {
                    setState(() => _imageFile = File(picked.path));
                  }
                },
                onRemove: () => setState(() {
                  _imageFile = null;
                  _existingImageUrl = null;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Barra de ação de salvar ──────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  final bool isEditing;
  final bool isLoading;
  final VoidCallback onSave;
  const _SaveBar(
      {required this.isEditing,
      required this.isLoading,
      required this.onSave});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isLoading
              ? null
              : const LinearGradient(
                  colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
                ),
          color: isLoading ? AppColors.neutral500 : null,
          borderRadius: BorderRadius.circular(AppRadius.button),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: AppColors.brandPrimary600.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Icon(
                  isEditing ? Icons.save_rounded : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 18),
          label: Text(
            isEditing ? 'Salvar Alterações' : 'Salvar e Cadastrar Lote',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

// ─── Seletor de imagem do produto ─────────────────────────────────────────

class _ProductImagePicker extends StatelessWidget {
  final File? imageFile;
  final String? existingImageUrl;
  final ColorScheme cs;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  const _ProductImagePicker({
    required this.imageFile,
    required this.existingImageUrl,
    required this.cs,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null || existingImageUrl != null;

    if (hasImage) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: imageFile != null
                ? Image.file(imageFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover)
                : Image.network(existingImageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, loading) =>
                        loading == null ? child : const SizedBox(height: 180)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 16, color: AppColors.danger600),
            label: Text(
              'Remover foto',
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.danger600),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Foto opcional para identificar o produto',
            style: AppTypography.bodySmall.copyWith(
                color: cs.onSurfaceVariant, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickCamera,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Câmera'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galeria'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Divider(color: color.withValues(alpha: 0.25), height: 1)),
      ],
    );
  }
}
