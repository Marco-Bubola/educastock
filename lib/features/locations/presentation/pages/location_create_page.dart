import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../controllers/locations_provider.dart';

class LocationCreatePage extends ConsumerStatefulWidget {
  const LocationCreatePage({super.key});

  @override
  ConsumerState<LocationCreatePage> createState() => _LocationCreatePageState();
}

class _LocationCreatePageState extends ConsumerState<LocationCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _customSectionCtrl = TextEditingController();
  final _customShelfCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();

  bool _saving = false;

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
  final _keySaveBtn = GlobalKey();
  final _keyNameField = GlobalKey();

  @override
  void dispose() {
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

  bool get _hasSection => _effectiveSection.isNotEmpty;
  bool get _hasShelf => _effectiveShelf.isNotEmpty;

  Color _sectionColor(String s) {
    if (s.isEmpty) return AppColors.brandPrimary600;
    const colors = [
      AppColors.brandPrimary600,
      AppColors.secondaryBlue600,
      AppColors.success600,
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      AppColors.warning600,
    ];
    return colors[s.codeUnitAt(0) % colors.length];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasSection) {
      showCasaSnackbar(context,
          message: 'Selecione ou informe a Seção.', isError: true);
      return;
    }
    if (!_hasShelf) {
      showCasaSnackbar(context,
          message: 'Selecione ou informe a Prateleira.', isError: true);
      return;
    }

    setState(() => _saving = true);
    await ref.read(locationsNotifierProvider.notifier).createLocation(
          locationName:
              _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          section: _effectiveSection,
          shelf: _effectiveShelf,
          level:
              (_showLevel && _effectiveLevel.isNotEmpty) ? _effectiveLevel : null,
          room: (_showExtras && _roomCtrl.text.trim().isNotEmpty)
              ? _roomCtrl.text.trim()
              : null,
          productsPerLevel:
              _showCapacity ? int.tryParse(_capacityCtrl.text.trim()) : null,
        );

    setState(() => _saving = false);
    final state = ref.read(locationsNotifierProvider);
    if (!mounted) return;
    state.when(
      data: (_) {
        showCasaSnackbar(context,
            message: 'Localização cadastrada com sucesso!', isSuccess: true);
        Navigator.pop(context);
      },
      error: (e, _) => showCasaSnackbar(context,
          message: e.toString().replaceFirst('Exception: ', ''), isError: true),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final accent = _hasSection ? _sectionColor(_effectiveSection) : AppColors.brandPrimary600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1520) : const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF141B2D) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_location_alt_rounded,
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nova Localização',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  'Configure seção, prateleira e mais',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFADB5BD)
                        : const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyNameField,
                  title: 'Nome da Localização',
                  description: 'Informe um nome claro e único para identificar este local de armazenamento. Use um sistema de nomenclatura consistente para toda a instituição.',
                  icon: Icons.edit_location_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Seja específico: "Prateleira B-2" é melhor que "Prateleira"',
                    'Inclua referências físicas: sala, corredor, nível',
                    'Ex: "Despensa Principal", "Armário Cozinha", "Galpão Fundo"',
                  ],
                ),
                TutorialStep(
                  key: _keySaveBtn,
                  title: 'Salvar Localização',
                  description: 'Salve a nova localização para que ela fique disponível ao cadastrar lotes de estoque. A localização aparece imediatamente nas opções de seleção.',
                  icon: Icons.save_as_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Localizações ficam disponíveis para toda a equipe',
                    'Você pode criar quantas localizações precisar',
                    'Edite o nome posteriormente se necessário',
                  ],
                ),
              ],
            ),
          ),
          if (_hasSection && _hasShelf)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: accent, strokeWidth: 2))
                  : GestureDetector(
                      key: _keySaveBtn,
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.8)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Salvar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── Card prévia ──
            _PreviewCard(
              isDark: isDark,
              accent: accent,
              hasSection: _hasSection,
              hasShelf: _hasShelf,
              section: _effectiveSection,
              shelf: _effectiveShelf,
              level: _showLevel ? _effectiveLevel : '',
              room: _showExtras ? _roomCtrl.text.trim() : '',
              capacity: _showCapacity ? _capacityCtrl.text.trim() : '',
              name: _nameCtrl.text.trim(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Seção: Nome ──
            _SectionCard(
              isDark: isDark,
              icon: Icons.badge_outlined,
              title: 'Nome da localização',
              subtitle: 'Opcional — identifica com facilidade',
              color: AppColors.brandPrimary600,
              child: CasaTextField(
                key: _keyNameField,
                label: '',
                hint: 'Ex: Depósito Principal, Sala Fria...',
                controller: _nameCtrl,
                prefixIcon:
                    const Icon(Icons.badge_outlined, size: 18),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Seção: Seção ──
            _SectionCard(
              isDark: isDark,
              icon: Icons.grid_view_rounded,
              title: 'Seção',
              subtitle: 'Obrigatório',
              color: AppColors.brandPrimary600,
              required: true,
              child: Column(
                children: [
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
                      prefixIcon: const Icon(Icons.grid_view_rounded, size: 18),
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Informe a seção'
                          : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Seção: Prateleira ──
            _SectionCard(
              isDark: isDark,
              icon: Icons.layers_rounded,
              title: 'Prateleira',
              subtitle: 'Obrigatório',
              color: AppColors.secondaryBlue600,
              required: true,
              child: Column(
                children: [
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
                      prefixIcon: const Icon(Icons.layers_rounded, size: 18),
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Informe a prateleira'
                          : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Seção: Nível (opcional) ──
            _ExpandableSectionCard(
              isDark: isDark,
              icon: Icons.format_list_numbered_rounded,
              title: 'Nível',
              subtitle: 'Superior, Médio, Inferior...',
              color: AppColors.success600,
              expanded: _showLevel,
              onToggle: () => setState(() {
                _showLevel = !_showLevel;
                if (!_showLevel) _selectedLevel = null;
              }),
              child: Column(
                children: [
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
                        const Icon(Icons.format_list_numbered_rounded, size: 18),
                    textInputAction: TextInputAction.next,
                    onChanged: (v) => setState(() {
                      if (v.isNotEmpty) _selectedLevel = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Seção: Capacidade (opcional) ──
            _ExpandableSectionCard(
              isDark: isDark,
              icon: Icons.inventory_2_rounded,
              title: 'Capacidade por nível',
              subtitle: 'Qtd máxima de produtos',
              color: AppColors.warning600,
              expanded: _showCapacity,
              onToggle: () => setState(() => _showCapacity = !_showCapacity),
              child: CasaTextField(
                label: '',
                hint: 'Ex: 30 itens',
                controller: _capacityCtrl,
                prefixIcon: const Icon(Icons.inventory_2_rounded, size: 18),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Seção: Sala/Depósito (opcional) ──
            _ExpandableSectionCard(
              isDark: isDark,
              icon: Icons.meeting_room_rounded,
              title: 'Sala / Depósito',
              subtitle: 'Localização física adicional',
              color: const Color(0xFF7C3AED),
              expanded: _showExtras,
              onToggle: () => setState(() => _showExtras = !_showExtras),
              child: CasaTextField(
                label: '',
                hint: 'Ex: Depósito A, Sala Fria...',
                controller: _roomCtrl,
                prefixIcon: const Icon(Icons.meeting_room_rounded, size: 18),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Botão salvar ──
            CasaButton(
              label: 'Salvar Localização',
              icon: Icons.add_location_alt_rounded,
              onPressed: _saving ? null : _save,
              isLoading: _saving,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  String _buildPreviewText() {
    final parts = <String>[];
    if (_nameCtrl.text.trim().isNotEmpty) parts.add(_nameCtrl.text.trim());
    if (_effectiveSection.isNotEmpty) parts.add('Seção $_effectiveSection');
    if (_effectiveShelf.isNotEmpty) parts.add('P$_effectiveShelf');
    if (_showLevel && _effectiveLevel.isNotEmpty) parts.add('N$_effectiveLevel');
    if (_showExtras && _roomCtrl.text.trim().isNotEmpty) {
      parts.add(_roomCtrl.text.trim());
    }
    return parts.join(' • ');
  }
}

// ─── Preview Card ─────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final bool hasSection;
  final bool hasShelf;
  final String section;
  final String shelf;
  final String level;
  final String room;
  final String capacity;
  final String name;

  const _PreviewCard({
    required this.isDark,
    required this.accent,
    required this.hasSection,
    required this.hasShelf,
    required this.section,
    required this.shelf,
    required this.level,
    required this.room,
    required this.capacity,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (hasSection || hasShelf)
              ? accent.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.15 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topo colorido
          Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.5)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Prévia da localização',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accent,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name.isNotEmpty ? name : (hasSection || hasShelf ? _buildLabel() : 'Preencha os campos...'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasSection || hasShelf) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  if (hasSection)
                    _PreviewTag('Seção $section', Icons.grid_view_rounded, accent, isDark),
                  if (hasShelf)
                    _PreviewTag('P$shelf', Icons.layers_rounded, accent, isDark),
                  if (level.isNotEmpty)
                    _PreviewTag('Nível $level', Icons.format_list_numbered_rounded,
                        AppColors.success600, isDark),
                  if (capacity.isNotEmpty)
                    _PreviewTag('$capacity itens/nível', Icons.inventory_2_rounded,
                        AppColors.warning600, isDark),
                  if (room.isNotEmpty)
                    _PreviewTag(room, Icons.meeting_room_rounded,
                        const Color(0xFF7C3AED), isDark),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildLabel() {
    final parts = <String>[];
    if (section.isNotEmpty) parts.add('Seção $section');
    if (shelf.isNotEmpty) parts.add('Prateleira $shelf');
    return parts.join(' • ');
  }
}

class _PreviewTag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _PreviewTag(this.label, this.icon, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool required;
  final Widget child;

  const _SectionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          if (required) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                  color: AppColors.danger600,
                                  shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: subColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

// ─── Expandable Section Card ──────────────────────────────────────────────────

class _ExpandableSectionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _ExpandableSectionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: expanded
            ? Border.all(color: color.withValues(alpha: 0.4))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: expanded
                          ? color.withValues(alpha: isDark ? 0.25 : 0.15)
                          : color.withValues(alpha: isDark ? 0.1 : 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      expanded ? Icons.check_rounded : icon,
                      size: 17,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: expanded ? color : textColor,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: subColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: expanded
                          ? color.withValues(alpha: 0.1)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      expanded ? Icons.remove_rounded : Icons.add_rounded,
                      size: 16,
                      color: expanded ? color : subColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              color: color.withValues(alpha: 0.15),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Chip Selector ────────────────────────────────────────────────────────────

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
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      : activeColor.withValues(alpha: 0.3),
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Text(
                p,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : activeColor,
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
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    style: TextStyle(
                      fontSize: 12,
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
