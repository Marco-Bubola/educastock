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
        title: 'Localizações',
        subtitle: 'Seções e prateleiras do estoque',
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
                  title: 'Localizações do Estoque',
                  description: 'Lista de todos os locais físicos onde os produtos são armazenados na instituição. Cada lote de estoque pode ser associado a uma localização específica.',
                  icon: Icons.shelves,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Ex: "Prateleira A-1", "Depósito", "Cozinha", "Sala 3"',
                    'Localizações ajudam a encontrar produtos fisicamente',
                    'Toque para editar o nome de uma localização',
                    'Desative localizações que não são mais usadas',
                  ],
                ),
                TutorialStep(
                  key: _keyLocationFAB,
                  title: 'Nova Localização',
                  description: 'Crie uma nova localização física para organizar onde os produtos são armazenados. Seja específico para facilitar o trabalho de toda a equipe.',
                  icon: Icons.add_location_alt_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Use nomes curtos e descritivos',
                    'Pense nas divisões físicas do seu espaço',
                    'Ex: por sala, por prateleira, por tipo de armazenamento',
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
        key: _keyLocationFAB,
        onPressed: () => context.push(AppRoutes.locationCreate),
        backgroundColor: AppColors.brandPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Nova Localização'),
        elevation: 6,
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Map<String, List<StorageLocation>> grouped = {};
    for (final loc in items) {
      grouped.putIfAbsent(loc.section, () => []).add(loc);
    }
    final sections = grouped.keys.toList()..sort();
    final withCapacity = items.where((l) => l.productsPerLevel != null).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
      children: [
        // ── Banner de resumo ──
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary600.withValues(alpha: 0.4),
                blurRadius: 18,
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
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.warehouse_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${items.length} localização${items.length != 1 ? 'ões' : ''}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sections.length} seção${sections.length != 1 ? 'ões' : ''} • $withCapacity com capacidade definida',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Indicador de seções
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${sections.length} seções',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        for (final section in sections) ...[
          _SectionHeader(section: section, count: grouped[section]!.length, isDark: isDark),
          const SizedBox(height: AppSpacing.sm),
          ...grouped[section]!.map((loc) => Padding(
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

class _SectionHeader extends StatelessWidget {
  final String section;
  final int count;
  final bool isDark;
  const _SectionHeader({required this.section, required this.count, required this.isDark});

  Color _accentFor(String s) {
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

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(section);
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            'Seção $section',
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
            '$count item${count != 1 ? 'ns' : ''}',
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
    ];
    return colors[s.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(location.section);
    final cardBg = isDark ? const Color(0xFF1A2234) : Colors.white;
    final headerBg = isDark
        ? const Color(0xFF141B2D)
        : accent.withValues(alpha: 0.06);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFFADB5BD) : const Color(0xFF6B7280);
    final hasName = (location.locationName ?? '').isNotEmpty;
    final hasLevel = (location.level ?? '').isNotEmpty;
    final hasRoom = (location.room ?? '').isNotEmpty;
    final hasCapacity = location.productsPerLevel != null;

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
            color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header colorido com seção + prateleira ──
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(
                bottom: BorderSide(
                  color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Badge de seção grande
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      location.section.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Seção + prateleira
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasName)
                        Text(
                          location.locationName!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          'Seção ${location.section} · Prateleira ${location.shelf}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            fontFamily: 'Poppins',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.grid_view_rounded,
                              size: 12, color: accent),
                          const SizedBox(width: 3),
                          Text(
                            'Seção ${location.section}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.layers_rounded,
                              size: 12, color: subColor),
                          const SizedBox(width: 3),
                          Text(
                            'Prateleira ${location.shelf}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Botão desativar
                GestureDetector(
                  onTap: onDeactivate,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.danger600.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.danger600.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.danger600,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Detalhes adicionais ──
          if (hasLevel || hasRoom || hasCapacity)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (hasLevel)
                    _InfoChip(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'Nível ${location.level}',
                      color: AppColors.success600,
                      isDark: isDark,
                    ),
                  if (hasRoom)
                    _InfoChip(
                      icon: Icons.meeting_room_rounded,
                      label: location.room!,
                      color: const Color(0xFF7C3AED),
                      isDark: isDark,
                    ),
                  if (hasCapacity)
                    _InfoChip(
                      icon: Icons.inventory_2_rounded,
                      label: '${location.productsPerLevel} prod/nível',
                      color: AppColors.warning600,
                      isDark: isDark,
                    ),
                ],
              ),
            ),

          // ── Data de criação ──
          Padding(
            padding: EdgeInsets.fromLTRB(
                14, (hasLevel || hasRoom || hasCapacity) ? 4 : 10, 14, 12),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 11, color: subColor.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  _formatDate(location.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: subColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success600.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Ativo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _InfoChip({
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
          color: color.withValues(alpha: isDark ? 0.25 : 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
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
          const Icon(Icons.inventory_2_rounded, size: 12, color: AppColors.brandPrimary600),
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
