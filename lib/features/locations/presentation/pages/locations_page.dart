import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/locations_provider.dart';
import '../../domain/entities/storage_location.dart';

final _keyLocationFAB = GlobalKey();
final _keyLocationsList = GlobalKey();

class LocationsPage extends ConsumerWidget {
  const LocationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final locations = ref.watch(activeLocationsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: ModernProfileAppBar(
        title: 'Depósito',
        subtitle: 'Prateleiras e armários',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyLocationsList,
                  title: 'Prateleiras do Depósito',
                  description:
                      'Lista de todas as prateleiras e armários onde os produtos são armazenados. Cada lote de estoque é associado a uma localização específica.',
                  icon: Icons.shelves,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Ex: "Prateleira A · Nível 1", "Armário B · Nível 2"',
                    'Localizações ajudam a encontrar produtos fisicamente',
                    'Desative localizações que não são mais usadas',
                  ],
                ),
                TutorialStep(
                  key: _keyLocationFAB,
                  title: 'Nova Localização',
                  description:
                      'Cadastre uma prateleira/armário e o nível específico para organizar onde os produtos ficam guardados.',
                  icon: Icons.add_location_alt_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Escolha a prateleira (A, B, C...) e o nível (1, 2, 3...)',
                    'Defina quantos itens cabem por nível',
                    'Crie quantas localizações precisar',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: locations.when(
          data: (items) {
            if (items.isEmpty) {
              return _EmptyLocations(
                  onAdd: () => context.push(AppRoutes.locationCreate));
            }
            return KeyedSubtree(
              key: _keyLocationsList,
              child: _LocationsList(
                items: items,
                onAdd: () => context.push(AppRoutes.locationCreate),
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
              ),
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 5,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
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
        key: _keyLocationFAB,
        onPressed: () => context.push(AppRoutes.locationCreate),
        backgroundColor: AppColors.brandPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Localização'),
        elevation: 6,
      ),
    );
  }
}

// ─── Lista principal ──────────────────────────────────────────────────────────

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Agrupa por prateleira (groupKey usa shelf para novos dados, section para legado)
    final Map<String, List<StorageLocation>> grouped = {};
    for (final loc in items) {
      grouped.putIfAbsent(loc.groupKey, () => []).add(loc);
    }
    final groups = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
      children: [
        // ── Banner depósito ──
        _DepositBanner(total: items.length, groups: groups.length),
        const SizedBox(height: AppSpacing.xl),

        for (final group in groups) ...[
          _GroupHeader(groupKey: group, count: grouped[group]!.length, isDark: isDark),
          const SizedBox(height: AppSpacing.sm),
          ...grouped[group]!.map((loc) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _LocationCard(
                  location: loc,
                  onDeactivate: () => onDeactivate(loc),
                  isDark: isDark,
                ),
              )),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

// ─── Banner ───────────────────────────────────────────────────────────────────

class _DepositBanner extends StatelessWidget {
  final int total;
  final int groups;

  const _DepositBanner({required this.total, required this.groups});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary600.withValues(alpha: 0.38),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.warehouse_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Depósito da ONG',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total localização${total != 1 ? 'ões' : ''} · $groups prateleira${groups != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$total spots',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Group Header ─────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String groupKey;
  final int count;
  final bool isDark;

  const _GroupHeader(
      {required this.groupKey, required this.count, required this.isDark});

  Color _accentFor(String s) {
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

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(groupKey);
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            'Prateleira $groupKey',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.35), Colors.transparent],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$count nível${count != 1 ? 'eis' : ''}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Location Card ────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final StorageLocation location;
  final VoidCallback onDeactivate;
  final bool isDark;

  const _LocationCard({
    required this.location,
    required this.onDeactivate,
    required this.isDark,
  });

  Color _accentFor(String s) {
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

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(location.groupKey);
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor =
        isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);

    final hasName = (location.locationName ?? '').isNotEmpty;
    final hasLevel = (location.level ?? '').isNotEmpty;
    final hasCapacity = location.productsPerLevel != null;

    final badgeChar = (location.groupKey.isNotEmpty
            ? location.groupKey
            : location.shelf.isNotEmpty
                ? location.shelf
                : '?')[0]
        .toUpperCase();

    final title = hasName
        ? location.locationName!
        : 'Prateleira ${location.groupKey}';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.1 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Barra lateral colorida com badge ──
            Container(
              width: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Text(
                  badgeChar,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    height: 1,
                  ),
                ),
              ),
            ),
            // ── Conteúdo ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                              fontFamily: 'Poppins',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Botão desativar
                        GestureDetector(
                          onTap: onDeactivate,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.danger600.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color:
                                    AppColors.danger600.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger600,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        if (hasLevel)
                          _Chip(
                            icon: Icons.layers_rounded,
                            label: 'Nível ${location.level}',
                            color: AppColors.secondaryBlue600,
                            isDark: isDark,
                          )
                        else
                          _Chip(
                            icon: Icons.layers_rounded,
                            label: 'Nível ?',
                            color: subColor,
                            isDark: isDark,
                          ),
                        if (hasCapacity)
                          _Chip(
                            icon: Icons.inventory_2_rounded,
                            label: '${location.productsPerLevel} itens',
                            color: AppColors.warning600,
                            isDark: isDark,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 10,
                            color: subColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 3),
                        Text(
                          _fmtDate(location.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: subColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                AppColors.success600.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.success600,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'Ativo',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: color.withValues(alpha: isDark ? 0.25 : 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

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
                  colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600
                  ],
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
              child:
                  const Icon(Icons.shelves, size: 44, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Nenhuma localização cadastrada',
                style: AppTypography.headingMedium
                    .copyWith(color: cs.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cadastre as prateleiras e armários do depósito\npara organizar onde cada produto é guardado.',
              style: AppTypography.bodyMedium
                  .copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color:
                    AppColors.brandPrimary600.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                    color: AppColors.brandPrimary600
                        .withValues(alpha: 0.2)),
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
                  _ExRow('Prateleira A · Nível 1 · 30 itens'),
                  _ExRow('Prateleira A · Nível 2 · 30 itens'),
                  _ExRow('Armário B · Nível 1 · 20 itens'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            CasaButton(
              label: 'Cadastrar primeira localização',
              icon: Icons.add_rounded,
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
          const Icon(Icons.shelves,
              size: 12, color: AppColors.brandPrimary600),
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
