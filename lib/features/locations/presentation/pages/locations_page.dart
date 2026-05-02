import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/locations_provider.dart';
import '../../domain/entities/storage_location.dart';

class LocationsPage extends ConsumerWidget {
  const LocationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final locations = ref.watch(activeLocationsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: ModernProfileAppBar(
        title: 'Localizações',
        subtitle: 'Seções e prateleiras do estoque',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        showBackButton: true,
      ),
      body: SafeArea(
        child: locations.when(
          data: (items) {
            if (items.isEmpty) {
              return _EmptyLocations(
                  onAdd: () => _showCreateModal(context, ref));
            }
            return _LocationsList(
              items: items,
              onAdd: () => _showCreateModal(context, ref),
              onDeactivate: (loc) async {
                final confirm = await CasaDialogConfirmacao.show(
                  context: context,
                  title: 'Desativar localização',
                  message:
                      'Esta localização não será mais exibida nos novos lotes. Continuar?',
                  confirmLabel: 'Desativar',
                  isDanger: true,
                );
                if (confirm != true) return;
                await ref
                    .read(locationsNotifierProvider.notifier)
                    .deactivateLocation(loc.id);
              },
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar',
            description: e.toString(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateModal(context, ref),
        backgroundColor: AppColors.brandPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Nova Localização'),
        elevation: 6,
      ),
    );
  }

  void _showCreateModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _CreateLocationModal(parentRef: ref),
    );
  }
}

// ─── Lista principal ────────────────────────────────────────────────────────

class _LocationsList extends StatelessWidget {
  final List<StorageLocation> items;
  final VoidCallback onAdd;
  final void Function(StorageLocation) onDeactivate;

  const _LocationsList({
    required this.items,
    required this.onAdd,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, List<StorageLocation>> grouped = {};
    for (final loc in items) {
      grouped.putIfAbsent(loc.section, () => []).add(loc);
    }
    final sections = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
      children: [
        // Banner de resumo
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary600.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: const Icon(Icons.warehouse_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${items.length} localização${items.length != 1 ? 'ões' : ''}',
                      style: AppTypography.headingMedium
                          .copyWith(color: Colors.white),
                    ),
                    Text(
                      '${sections.length} seção${sections.length != 1 ? 'ões' : ''} • ${items.where((l) => l.productsPerLevel != null).length} com limite de capacidade',
                      style: AppTypography.bodySmall
                          .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.brandPrimary600.withValues(alpha: 0.22)
                        : AppColors.brandPrimary100,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Seção $section',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.brandPrimary700,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Divider(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          ...grouped[section]!.map((loc) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _LocationCard(
                  location: loc,
                  onDeactivate: () => onDeactivate(loc),
                ),
              )),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final StorageLocation location;
  final VoidCallback onDeactivate;

  const _LocationCard({required this.location, required this.onDeactivate});

  Color _sectionColor(String section) {
    const colors = [
      AppColors.brandPrimary600,
      AppColors.secondaryBlue600,
      AppColors.success600,
      AppColors.warning600,
      Color(0xFF7C3AED),
      AppColors.danger600,
    ];
    final idx = section.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = _sectionColor(location.section);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(Icons.shelves, color: accentColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (location.locationName ?? '').isNotEmpty
                        ? location.locationName!
                        : 'Prateleira ${location.shelf}',
                    style: AppTypography.labelLarge.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      _InfoChip(icon: Icons.grid_view_rounded,
                          text: 'Seção ${location.section}', color: accentColor),
                      _InfoChip(icon: Icons.shelves,
                          text: 'P${location.shelf}', color: accentColor),
                      if ((location.level ?? '').isNotEmpty)
                        _InfoChip(icon: Icons.layers_outlined,
                            text: 'N${location.level}', color: accentColor),
                      if ((location.room ?? '').isNotEmpty)
                        _InfoChip(icon: Icons.door_back_door_outlined,
                            text: location.room!, color: accentColor),
                      if (location.productsPerLevel != null)
                        _InfoChip(icon: Icons.inventory_2_outlined,
                            text: '${location.productsPerLevel} prod/nível',
                            color: AppColors.success600),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger600, size: 20),
              tooltip: 'Desativar',
              onPressed: onDeactivate,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cs.brightness == Brightness.dark
                  ? color.withValues(alpha: 0.9)
                  : color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Estado vazio ────────────────────────────────────────────────────────────

class _EmptyLocations extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyLocations({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary600.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: const Icon(Icons.add_location_alt_rounded,
                  size: 44, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Nenhuma localização cadastrada',
                style: AppTypography.headingMedium.copyWith(color: cs.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cadastre seções e prateleiras para organizar\no estoque e facilitar o armazenamento.',
              style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary600.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                    color: AppColors.brandPrimary600.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        size: 14, color: AppColors.brandPrimary600),
                    const SizedBox(width: 6),
                    Text('Exemplos de organização:',
                        style: AppTypography.labelSmall.copyWith(
                            color: AppColors.brandPrimary600,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  _ExRow('Seção A • Prateleira 1 • 3 Níveis • 20 itens/nível'),
                  _ExRow('Seção B • Prateleira 2 • Depósito Principal'),
                  _ExRow('Seção C • Prateleira 3 • Sala Fria'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            CasaButton(
              label: 'Cadastrar primeira localização',
              icon: Icons.add_location_alt_rounded,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExRow extends StatelessWidget {
  final String text;
  const _ExRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(Icons.shelves, size: 12, color: AppColors.brandPrimary500),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(text,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.brandPrimary600)),
          ),
        ],
      ),
    );
  }
}

// ─── Modal de criação ─────────────────────────────────────────────────────────

class _CreateLocationModal extends ConsumerStatefulWidget {
  final WidgetRef parentRef;
  const _CreateLocationModal({required this.parentRef});

  @override
  ConsumerState<_CreateLocationModal> createState() =>
      _CreateLocationModalState();
}

class _CreateLocationModalState extends ConsumerState<_CreateLocationModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _customSectionCtrl = TextEditingController();
  final _customShelfCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();

  bool _saving = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const _presetSections = ['A', 'B', 'C', 'D', 'E', 'F'];
  String? _selectedSection;
  bool _customSection = false;

  static const _presetShelves = ['1', '2', '3', '4', '5', '6', '7', '8'];
  String? _selectedShelf;
  bool _customShelf = false;

  static const _presetLevels = [
    'Superior', 'Médio', 'Inferior', '1', '2', '3', '4'
  ];
  String? _selectedLevel;
  bool _showLevel = false;
  bool _showCapacity = false;
  bool _showExtras = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _customSectionCtrl.dispose();
    _customShelfCtrl.dispose();
    _levelCtrl.dispose();
    _roomCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  String get _effectiveSection =>
      _customSection ? _customSectionCtrl.text.trim() : (_selectedSection ?? '');
  String get _effectiveShelf =>
      _customShelf ? _customShelfCtrl.text.trim() : (_selectedShelf ?? '');
  String get _effectiveLevel {
    if (_selectedLevel != null) return _selectedLevel!;
    return _levelCtrl.text.trim();
  }

  String get _previewLabel {
    final parts = <String>[];
    if (_nameCtrl.text.trim().isNotEmpty) parts.add(_nameCtrl.text.trim());
    if (_effectiveSection.isNotEmpty) parts.add('Seção $_effectiveSection');
    if (_effectiveShelf.isNotEmpty) parts.add('P$_effectiveShelf');
    if (_showLevel && _effectiveLevel.isNotEmpty) parts.add('N$_effectiveLevel');
    if (_showExtras && _roomCtrl.text.trim().isNotEmpty) {
      parts.add(_roomCtrl.text.trim());
    }
    return parts.isEmpty ? 'Preencha os campos abaixo...' : parts.join(' • ');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_effectiveSection.isEmpty) {
      showCasaSnackbar(context,
          message: 'Selecione ou informe a Seção.', isError: true);
      return;
    }
    if (_effectiveShelf.isEmpty) {
      showCasaSnackbar(context,
          message: 'Selecione ou informe a Prateleira.', isError: true);
      return;
    }

    setState(() => _saving = true);
    await widget.parentRef
        .read(locationsNotifierProvider.notifier)
        .createLocation(
          locationName:
              _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          section: _effectiveSection,
          shelf: _effectiveShelf,
          level: (_showLevel && _effectiveLevel.isNotEmpty)
              ? _effectiveLevel
              : null,
          room: (_showExtras && _roomCtrl.text.trim().isNotEmpty)
              ? _roomCtrl.text.trim()
              : null,
          productsPerLevel: _showCapacity
              ? int.tryParse(_capacityCtrl.text.trim())
              : null,
        );

    setState(() => _saving = false);
    final state = widget.parentRef.read(locationsNotifierProvider);
    if (!mounted) return;
    state.when(
      data: (_) {
        Navigator.pop(context);
        showCasaSnackbar(context,
            message: 'Localização cadastrada!', isSuccess: true);
      },
      error: (e, _) => showCasaSnackbar(context,
          message: e.toString().replaceFirst('Exception: ', ''),
          isError: true),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                .animate(_fadeAnim),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
              bottom + AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.brandPrimary600,
                              AppColors.secondaryBlue600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_location_alt_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nova Localização',
                                style: AppTypography.headingMedium
                                    .copyWith(color: cs.onSurface)),
                            Text('Configure rápido com os chips abaixo',
                                style: AppTypography.bodySmall
                                    .copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Prévia ao vivo
                  _PreviewBanner(label: _previewLabel, isDark: isDark),
                  const SizedBox(height: AppSpacing.lg),

                  // Nome opcional
                  _FieldLabel('Nome (opcional)', cs),
                  const SizedBox(height: AppSpacing.xs),
                  CasaTextField(
                    label: '',
                    hint: 'Ex: Depósito Principal',
                    controller: _nameCtrl,
                    prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Seção
                  _FieldLabel('Seção', cs, required: true),
                  const SizedBox(height: AppSpacing.xs),
                  _ChipSelector(
                    presets: _presetSections,
                    selected: _customSection ? null : _selectedSection,
                    onSelect: (v) => setState(() {
                      _selectedSection = v;
                      _customSection = false;
                    }),
                    isCustom: _customSection,
                    onCustomToggle: () => setState(() {
                      _customSection = !_customSection;
                      _selectedSection = null;
                    }),
                    activeColor: AppColors.brandPrimary600,
                  ),
                  if (_customSection) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CasaTextField(
                      label: '',
                      hint: 'Ex: G, H, Ext-1...',
                      controller: _customSectionCtrl,
                      prefixIcon:
                          const Icon(Icons.grid_view_rounded, size: 18),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Informe a seção' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),

                  // Prateleira
                  _FieldLabel('Prateleira', cs, required: true),
                  const SizedBox(height: AppSpacing.xs),
                  _ChipSelector(
                    presets: _presetShelves,
                    selected: _customShelf ? null : _selectedShelf,
                    onSelect: (v) => setState(() {
                      _selectedShelf = v;
                      _customShelf = false;
                    }),
                    isCustom: _customShelf,
                    onCustomToggle: () => setState(() {
                      _customShelf = !_customShelf;
                      _selectedShelf = null;
                    }),
                    activeColor: AppColors.secondaryBlue600,
                  ),
                  if (_customShelf) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CasaTextField(
                      label: '',
                      hint: 'Ex: 9, 10, A-1...',
                      controller: _customShelfCtrl,
                      prefixIcon: const Icon(Icons.shelves, size: 18),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Informe a prateleira' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),

                  // Toggles opcionais
                  _ToggleRow(
                    label: 'Adicionar Nível',
                    icon: Icons.layers_rounded,
                    value: _showLevel,
                    onToggle: () => setState(() {
                      _showLevel = !_showLevel;
                      if (!_showLevel) _selectedLevel = null;
                    }),
                    activeColor: AppColors.success600,
                  ),
                  if (_showLevel) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ChipSelector(
                      presets: _presetLevels,
                      selected: _selectedLevel,
                      onSelect: (v) => setState(() {
                        _selectedLevel = v;
                        _levelCtrl.clear();
                      }),
                      isCustom: false,
                      onCustomToggle: () {},
                      activeColor: AppColors.success600,
                      showCustom: false,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    CasaTextField(
                      label: '',
                      hint: 'Ou informe manualmente...',
                      controller: _levelCtrl,
                      prefixIcon:
                          const Icon(Icons.layers_outlined, size: 18),
                      textInputAction: TextInputAction.next,
                      onChanged: (v) => setState(() {
                        if (v.isNotEmpty) _selectedLevel = null;
                      }),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),

                  _ToggleRow(
                    label: 'Definir capacidade máxima por nível',
                    icon: Icons.inventory_2_outlined,
                    value: _showCapacity,
                    onToggle: () =>
                        setState(() => _showCapacity = !_showCapacity),
                    activeColor: AppColors.warning600,
                  ),
                  if (_showCapacity) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CasaTextField(
                      label: '',
                      hint: 'Ex: 30 itens',
                      controller: _capacityCtrl,
                      prefixIcon: const Icon(Icons.shelves, size: 18),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),

                  _ToggleRow(
                    label: 'Adicionar sala / depósito',
                    icon: Icons.door_back_door_outlined,
                    value: _showExtras,
                    onToggle: () =>
                        setState(() => _showExtras = !_showExtras),
                    activeColor: cs.onSurfaceVariant,
                  ),
                  if (_showExtras) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CasaTextField(
                      label: '',
                      hint: 'Ex: Depósito A, Sala Fria...',
                      controller: _roomCtrl,
                      prefixIcon:
                          const Icon(Icons.door_back_door_outlined, size: 18),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  CasaButton(
                    label: 'Salvar Localização',
                    icon: Icons.add_location_alt_rounded,
                    onPressed: _saving ? null : _save,
                    isLoading: _saving,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _PreviewBanner extends StatelessWidget {
  final String label;
  final bool isDark;
  const _PreviewBanner({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.brandPrimary600.withValues(alpha: 0.12)
            : AppColors.brandPrimary100,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.brandPrimary600.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.preview_rounded,
              size: 15, color: AppColors.brandPrimary600),
          const SizedBox(width: 8),
          Text('Prévia: ',
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.brandPrimary600)),
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  final bool required;
  const _FieldLabel(this.text, this.cs, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: AppTypography.labelMedium.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            )),
        if (required) ...[
          const SizedBox(width: 4),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.danger600, shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final VoidCallback onToggle;
  final Color activeColor;
  const _ToggleRow(
      {required this.label,
      required this.icon,
      required this.value,
      required this.onToggle,
      required this.activeColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: value
                    ? activeColor.withValues(alpha: 0.15)
                    : cs.surfaceContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: value
                      ? activeColor.withValues(alpha: 0.5)
                      : cs.outlineVariant,
                ),
              ),
              child: Icon(
                value ? Icons.check_rounded : icon,
                size: 14,
                color: value ? activeColor : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: value ? activeColor : cs.onSurfaceVariant,
                  fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              value ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipSelector extends StatelessWidget {
  final List<String> presets;
  final String? selected;
  final ValueChanged<String> onSelect;
  final bool isCustom;
  final VoidCallback onCustomToggle;
  final Color activeColor;
  final bool showCustom;

  const _ChipSelector({
    required this.presets,
    required this.selected,
    required this.onSelect,
    required this.isCustom,
    required this.onCustomToggle,
    required this.activeColor,
    this.showCustom = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        ...presets.map((p) {
          final sel = selected == p;
          return GestureDetector(
            onTap: () => onSelect(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: sel
                    ? LinearGradient(colors: [
                        activeColor,
                        activeColor.withValues(alpha: 0.75)
                      ])
                    : null,
                color: sel ? null : cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: sel
                      ? Colors.transparent
                      : activeColor.withValues(alpha: 0.35),
                ),
                boxShadow: sel
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
                p,
                style: AppTypography.labelMedium.copyWith(
                  color: sel ? Colors.white : activeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }),
        if (showCustom)
          GestureDetector(
            onTap: onCustomToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isCustom
                    ? activeColor.withValues(alpha: 0.1)
                    : cs.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isCustom
                      ? activeColor.withValues(alpha: 0.5)
                      : cs.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCustom ? Icons.edit_rounded : Icons.add_rounded,
                    size: 13,
                    color: isCustom ? activeColor : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCustom ? 'Personalizado' : 'Outro',
                    style: AppTypography.labelSmall.copyWith(
                      color: isCustom ? activeColor : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
