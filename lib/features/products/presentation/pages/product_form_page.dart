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
    final formState = ref.watch(productFormProvider);
    final activeCategories = ref.watch(activeProductCategoriesProvider);
    if (!activeCategories.contains(_category)) {
      _category = activeCategories.first;
    }
    final isLoading = formState is AsyncLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernProfileAppBar(
        title: widget.productId != null ? 'Editar Produto' : 'Novo Produto',
        subtitle: 'Cadastro de produto',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (widget.barcode != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary100,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_rounded,
                          color: AppColors.brandPrimary600, size: 16),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Código: ${widget.barcode}',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.brandPrimary700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              CasaTextField(
                label: 'Nome do Produto *',
                controller: _nameController,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nome obrigatório' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CasaTextField(
                label: 'Marca',
                controller: _brandController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),

              // Categoria
              DropdownButtonFormField<ProductCategory>(
                // ignore: deprecated_member_use
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoria *',
                  prefixIcon: Icon(Icons.category_outlined, size: 20),
                ),
                items: activeCategories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(Product(
                            id: '', name: '', category: c, unit: '',
                            isPerishable: true, createdAt: DateTime.now(),
                            createdBy: '',
                          ).categoryLabel),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: AppSpacing.md),

              // Unidade
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _unit,
                decoration: const InputDecoration(
                  labelText: 'Unidade de Medida *',
                  prefixIcon: Icon(Icons.straighten_outlined, size: 20),
                ),
                items: _units
                    .map((u) =>
                        DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() => _unit = v!),
              ),
              const SizedBox(height: AppSpacing.md),

              // Perecível
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.neutral100),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Produto Perecível',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.neutral900),
                  ),
                  subtitle: Text(
                    _isPerishable
                        ? 'Validade obrigatória nos lotes'
                        : 'Sem obrigatoriedade de validade',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral500),
                  ),
                  value: _isPerishable,
                  onChanged: (v) => setState(() => _isPerishable = v),
                  activeThumbColor: AppColors.brandPrimary600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              CasaTextField(
                label: 'Descrição (opcional)',
                controller: _descController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xxl),

              CasaButton(
                label: widget.productId != null
                    ? 'Salvar Alterações'
                    : 'Salvar e Cadastrar Lote',
                onPressed: isLoading ? null : _submit,
                isLoading: isLoading,
                icon: Icons.save_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
