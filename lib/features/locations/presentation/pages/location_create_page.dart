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
  final _nameCtrl = TextEditingController();
  final _customShelfCtrl = TextEditingController();

  bool _saving = false;
  String? _selectedShelf;
  bool _customShelf = false;
  int _level = 1;
  int _productsPerLevel = 20;
  bool _showCapacity = false;
  bool _showName = false;

  static const _presetShelves = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customShelfCtrl.dispose();
    super.dispose();
  }

  String get _effectiveShelf =>
      _customShelf ? _customShelfCtrl.text.trim() : (_selectedShelf ?? '');

  bool get _isValid => _effectiveShelf.isNotEmpty;

  Color _shelfColor(String s) {
    if (s.isEmpty) return AppColors.brandPrimary600;
    const colors = [
      AppColors.brandPrimary600,
      AppColors.secondaryBlue600,
      AppColors.success600,
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      AppColors.warning600,
      Color(0xFFDB2777),
      Color(0xFF059669),
    ];
    return colors[s.codeUnitAt(0) % colors.length];
  }

  Future<void> _save() async {
    if (_effectiveShelf.isEmpty) {
      showCasaSnackbar(context,
          message: 'Escolha uma prateleira.', isError: true);
      return;
    }
    setState(() => _saving = true);
    await ref.read(locationsNotifierProvider.notifier).createLocation(
          locationName: (_showName && _nameCtrl.text.trim().isNotEmpty)
              ? _nameCtrl.text.trim()
              : null,
          shelf: _effectiveShelf,
          level: _level.toString(),
          productsPerLevel: _showCapacity ? _productsPerLevel : null,
        );
    setState(() => _saving = false);
    final st = ref.read(locationsNotifierProvider);
    if (!mounted) return;
    st.when(
      data: (_) {
        showCasaSnackbar(context,
            message: 'Localização cadastrada!', isSuccess: true);
        Navigator.pop(context);
      },
      error: (e, _) => showCasaSnackbar(context,
          message: e.toString().replaceFirst('Exception: ', ''),
          isError: true),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        _isValid ? _shelfColor(_effectiveShelf) : AppColors.brandPrimary600;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1520) : const Color(0xFFF5F7FB),
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Nova Localização',
        subtitle: 'Depósito · Prateleira · Nível',
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaHelpModal(
              context: context,
              pageTitle: 'Cadastrar localização',
              pageDescription:
                  'Organize seu depósito em prateleiras e níveis para encontrar produtos rapidamente.',
              accentColor: accent,
              headerIcon: Icons.shelves,
              tips: const [
                HelpTip(
                  icon: Icons.shelves,
                  title: 'Escolha a prateleira',
                  description:
                      'Use letras (A, B, C...) ou um nome personalizado como "Armário Frio" para identificar.',
                ),
                HelpTip(
                  icon: Icons.layers_rounded,
                  title: 'Defina o nível',
                  description:
                      'Conte de baixo para cima — nível 1 é o primeiro andar da prateleira.',
                ),
                HelpTip(
                  icon: Icons.inventory_2_rounded,
                  title: 'Capacidade (opcional)',
                  description:
                      'Informe quantos itens cabem por nível para alertas de ocupação.',
                ),
              ],
            ),
          ),
          if (_isValid)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 4),
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : GestureDetector(
                      onTap: _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.2),
                        ),
                        child: const Text(
                          'Salvar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
        children: [
          // ── Prévia animada ──
          _PreviewCard(
            isDark: isDark,
            accent: accent,
            shelf: _effectiveShelf,
            level: _level,
            capacity: _showCapacity ? _productsPerLevel : null,
            name: _showName ? _nameCtrl.text.trim() : '',
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Prateleira ──
          _ShelfPickerCard(
            isDark: isDark,
            presets: _presetShelves,
            selected: _customShelf ? null : _selectedShelf,
            customActive: _customShelf,
            customCtrl: _customShelfCtrl,
            onSelect: (v) => setState(() {
              _selectedShelf = v;
              _customShelf = false;
            }),
            onCustomToggle: () => setState(() {
              _customShelf = !_customShelf;
              _selectedShelf = null;
            }),
            onCustomChanged: () => setState(() {}),
            shelfColorFn: _shelfColor,
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Nível ──
          _LevelCard(
            isDark: isDark,
            level: _level,
            accent: accent,
            onDecrement: () => setState(() {
              if (_level > 1) _level--;
            }),
            onIncrement: () => setState(() {
              if (_level < 20) _level++;
            }),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Capacidade (opcional) ──
          _CapacityCard(
            isDark: isDark,
            accent: AppColors.warning600,
            enabled: _showCapacity,
            value: _productsPerLevel,
            onToggle: () => setState(() => _showCapacity = !_showCapacity),
            onDecrement: () => setState(() {
              if (_productsPerLevel >= 5) _productsPerLevel -= 5;
            }),
            onIncrement: () =>
                setState(() => _productsPerLevel += 5),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Nome personalizado (opcional) ──
          _NameCard(
            isDark: isDark,
            enabled: _showName,
            ctrl: _nameCtrl,
            onToggle: () => setState(() => _showName = !_showName),
            onChanged: () => setState(() {}),
          ),

          const SizedBox(height: AppSpacing.xxl),
          CasaButton(
            label: 'Salvar Localização',
            icon: Icons.add_location_alt_rounded,
            onPressed: (_saving || !_isValid) ? null : _save,
            isLoading: _saving,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      )),
      ]),
    );
  }

}

// ─── Preview Card ──────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final String shelf;
  final int level;
  final int? capacity;
  final String name;

  const _PreviewCard({
    required this.isDark,
    required this.accent,
    required this.shelf,
    required this.level,
    required this.capacity,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor =
        isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);
    final hasShelf = shelf.isNotEmpty;
    final displayName =
        name.isNotEmpty ? name : (hasShelf ? 'Prateleira $shelf' : null);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasShelf
              ? accent.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.4)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: hasShelf
                        ? LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: hasShelf
                        ? null
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: hasShelf
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Center(
                    child: hasShelf
                        ? Text(
                            shelf[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              height: 1,
                            ),
                          )
                        : Icon(Icons.shelves,
                            size: 24,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.2)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prévia',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName ?? 'Preencha os campos...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: hasShelf ? textColor : subColor,
                          fontFamily: 'Poppins',
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasShelf) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Nível $level${capacity != null ? ' · $capacity itens' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasShelf)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _Tag('Prat. $shelf', Icons.shelves, accent, isDark),
                  _Tag(
                      'Nível $level',
                      Icons.layers_rounded,
                      AppColors.secondaryBlue600,
                      isDark),
                  if (capacity != null)
                    _Tag('$capacity itens', Icons.inventory_2_rounded,
                        AppColors.warning600, isDark),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _Tag(this.label, this.icon, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─── Shelf Picker ──────────────────────────────────────────────────────────────

class _ShelfPickerCard extends StatelessWidget {
  final bool isDark;
  final List<String> presets;
  final String? selected;
  final bool customActive;
  final TextEditingController customCtrl;
  final ValueChanged<String> onSelect;
  final VoidCallback onCustomToggle;
  final VoidCallback onCustomChanged;
  final Color Function(String) shelfColorFn;

  const _ShelfPickerCard({
    required this.isDark,
    required this.presets,
    required this.selected,
    required this.customActive,
    required this.customCtrl,
    required this.onSelect,
    required this.onCustomToggle,
    required this.onCustomChanged,
    required this.shelfColorFn,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor =
        isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
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
                    color: AppColors.brandPrimary600
                        .withValues(alpha: isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shelves,
                      size: 17, color: AppColors.brandPrimary600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Prateleira / Armário',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                                color: AppColors.danger600,
                                shape: BoxShape.circle),
                          ),
                        ],
                      ),
                      Text('Qual unidade de armazenamento',
                          style: TextStyle(
                              fontSize: 11,
                              color: subColor,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Grid de prateleiras
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...presets.map((s) => _ShelfTile(
                      label: s,
                      selected: !customActive && selected == s,
                      color: shelfColorFn(s),
                      isDark: isDark,
                      onTap: () => onSelect(s),
                    )),
                _ShelfTile(
                  label: customActive ? 'Outro' : '+',
                  selected: customActive,
                  color: AppColors.brandPrimary600,
                  isDark: isDark,
                  isCustom: true,
                  onTap: onCustomToggle,
                ),
              ],
            ),
            if (customActive) ...[
              const SizedBox(height: AppSpacing.sm),
              CasaTextField(
                label: '',
                hint: 'Ex: Armário 1, Estante Fria...',
                controller: customCtrl,
                prefixIcon: const Icon(Icons.edit_rounded, size: 18),
                textInputAction: TextInputAction.next,
                onChanged: (_) => onCustomChanged(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShelfTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool isDark;
  final bool isCustom;
  final VoidCallback onTap;

  const _ShelfTile({
    required this.label,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 58,
        height: 56,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Center(
          child: isCustom
              ? Icon(
                  selected ? Icons.edit_rounded : Icons.add_rounded,
                  size: 22,
                  color: selected ? Colors.white : color,
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : color,
                    fontFamily: 'Poppins',
                    height: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Level Card ────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final bool isDark;
  final int level;
  final Color accent;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _LevelCard({
    required this.isDark,
    required this.level,
    required this.accent,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor =
        isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);
    final color = AppColors.secondaryBlue600;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                  child:
                      Icon(Icons.layers_rounded, size: 17, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Nível',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textColor)),
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                                color: AppColors.danger600,
                                shape: BoxShape.circle),
                          ),
                        ],
                      ),
                      Text('Qual prateleira dentro da unidade',
                          style: TextStyle(
                              fontSize: 11,
                              color: subColor,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepBtn(
                  icon: Icons.remove_rounded,
                  enabled: level > 1,
                  onTap: onDecrement,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.xl),
                Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: Text(
                        level.toString(),
                        key: ValueKey(level),
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Poppins',
                          color: color,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level == 1 ? 'nível inferior' : 'de baixo para cima',
                      style: TextStyle(
                        fontSize: 10,
                        color: subColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.xl),
                _StepBtn(
                  icon: Icons.add_rounded,
                  enabled: level < 20,
                  onTap: onIncrement,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

// ─── Capacity Card ─────────────────────────────────────────────────────────────

class _CapacityCard extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final bool enabled;
  final int value;
  final VoidCallback onToggle;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CapacityCard({
    required this.isDark,
    required this.accent,
    required this.enabled,
    required this.value,
    required this.onToggle,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor =
        isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: enabled
            ? Border.all(color: accent.withValues(alpha: 0.4))
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
                      color: accent.withValues(
                          alpha: enabled
                              ? (isDark ? 0.25 : 0.15)
                              : (isDark ? 0.1 : 0.06)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.inventory_2_rounded,
                        size: 17, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Itens por nível',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: enabled ? accent : textColor,
                            )),
                        Text('Quantos produtos cabem neste nível',
                            style: TextStyle(
                                fontSize: 11,
                                color: subColor,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: enabled,
                    onChanged: (_) => onToggle(),
                    activeTrackColor: accent,
                  ),
                ],
              ),
            ),
          ),
          if (enabled) ...[
            Container(
              height: 1,
              margin:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              color: accent.withValues(alpha: 0.15),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepBtn(
                    icon: Icons.remove_rounded,
                    enabled: value >= 5,
                    onTap: onDecrement,
                    color: accent,
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Text(
                          value.toString(),
                          key: ValueKey(value),
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Poppins',
                            color: accent,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('itens por nível',
                          style: TextStyle(
                              fontSize: 10,
                              color: subColor,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _StepBtn(
                    icon: Icons.add_rounded,
                    enabled: value < 500,
                    onTap: onIncrement,
                    color: accent,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Name Card ─────────────────────────────────────────────────────────────────

class _NameCard extends StatelessWidget {
  final bool isDark;
  final bool enabled;
  final TextEditingController ctrl;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  const _NameCard({
    required this.isDark,
    required this.enabled,
    required this.ctrl,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor =
        isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);
    const color = Color(0xFF7C3AED);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: enabled ? Border.all(color: color.withValues(alpha: 0.4)) : null,
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
                      color: color.withValues(
                          alpha: enabled
                              ? (isDark ? 0.25 : 0.15)
                              : (isDark ? 0.1 : 0.06)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.badge_outlined, size: 17, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nome personalizado',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: enabled ? color : textColor,
                            )),
                        Text('Opcional · Ex: Armário da Cozinha',
                            style: TextStyle(
                                fontSize: 11,
                                color: subColor,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: enabled,
                    onChanged: (_) => onToggle(),
                    activeTrackColor: color,
                  ),
                ],
              ),
            ),
          ),
          if (enabled) ...[
            Container(
              height: 1,
              margin:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              color: color.withValues(alpha: 0.15),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
              child: CasaTextField(
                label: '',
                hint: 'Ex: Armário da Cozinha, Estante Fria...',
                controller: ctrl,
                prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                textInputAction: TextInputAction.done,
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Stepper Button ────────────────────────────────────────────────────────────

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;

  const _StepBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.35)
                : Colors.grey.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 24,
          color: enabled ? color : Colors.grey.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
