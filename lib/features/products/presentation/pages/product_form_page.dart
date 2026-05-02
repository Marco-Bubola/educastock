import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  const ProductFormPage({
    super.key,
    this.productId,
    this.barcode,
    this.prefillName,
    this.prefillBrand,
    this.prefillCategory,
  });

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descController = TextEditingController();

  ProductCategory _category = ProductCategory.alimento;
  String _unit = 'un';
  bool _isPerishable = true;
  int _minimumStock = 0;
  DateTime? _originalCreatedAt;
  String? _originalCreatedBy;

  final List<String> _units = ['un', 'kg', 'g', 'L', 'mL', 'cx', 'pct', 'frd'];

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
    // Carregar produto existente para editar
    if (widget.productId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final product = await ref
            .read(productsDatasourceProvider)
            .getProductById(widget.productId!);
        if (product != null && mounted) {
          setState(() {
            _nameController.text = product.name;
            _brandController.text = product.brand ?? '';
            _descController.text = product.description ?? '';
            _category = product.category;
            _unit = product.unit;
            _isPerishable = product.isPerishable;
            _minimumStock = product.minimumStock;
            _originalCreatedAt = product.createdAt;
            _originalCreatedBy = product.createdBy;
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
      unit: _unit,
      barcode: widget.barcode,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      isPerishable: _isPerishable,
      minimumStock: _minimumStock,
      createdAt: _originalCreatedAt ?? DateTime.now(),
      createdBy: _originalCreatedBy ?? user.id,
    );

    await ref.read(productFormProvider.notifier).saveProduct(product);

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
      error: (e, _) => showCasaSnackbar(context,
          message: 'Erro ao salvar produto.', isError: true),
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
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
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
                onChanged: (v) => setState(() => _unit = v!),
              ),
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
              const SizedBox(height: AppSpacing.xxl),

              CasaButton(
                label: isEditing ? 'Salvar Alterações' : 'Salvar e Cadastrar Lote',
                onPressed: isLoading ? null : _submit,
                isLoading: isLoading,
                icon: isEditing ? Icons.save_rounded : Icons.arrow_forward_rounded,
              ),
              if (!isEditing) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: Text(
                    'Após salvar o produto, você será redirecionado\npara cadastrar o primeiro lote.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
