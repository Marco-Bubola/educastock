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
      backgroundColor: AppColors.background,
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
              return _EmptyLocations(onAdd: () => _showLocationForm(context, ref));
            }
            return _LocationsList(
              items: items,
              onAdd: () => _showLocationForm(context, ref),
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
        onPressed: () => _showLocationForm(context, ref),
        backgroundColor: AppColors.brandPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Nova Localização'),
        elevation: 4,
      ),
    );
  }

  void _showLocationForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationFormSheet(ref: ref),
    );
  }
}

// ─── Lista de localizações ──────────────────────────────────────────────────

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
    // Agrupar por seção
    final Map<String, List<StorageLocation>> grouped = {};
    for (final loc in items) {
      grouped.putIfAbsent(loc.section, () => []).add(loc);
    }
    final sections = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
      children: [
        // Card de resumo
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandPrimary600, AppColors.brandPrimary700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary600.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${items.length} localização${items.length != 1 ? 'ões' : ''}',
                      style: AppTypography.headingMedium.copyWith(color: Colors.white),
                    ),
                    Text(
                      '${sections.length} seção${sections.length != 1 ? 'ões' : ''} cadastrada${sections.length != 1 ? 's' : ''}',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Por seção
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary100,
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
                  child: Divider(color: AppColors.neutral100, height: 1),
                ),
              ],
            ),
          ),
          ...grouped[section]!.map(
            (loc) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _LocationCard(
                location: loc,
                onDeactivate: () => onDeactivate(loc),
              ),
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.neutral100),
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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary100,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(Icons.shelves, color: AppColors.secondaryBlue600, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prateleira ${location.shelf}',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.neutral900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      if ((location.room ?? '').isNotEmpty) ...[
                        const Icon(Icons.door_back_door_outlined,
                            size: 12, color: AppColors.neutral500),
                        const SizedBox(width: 3),
                        Text(
                          location.room!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.neutral500),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      if ((location.level ?? '').isNotEmpty) ...[
                        const Icon(Icons.layers_outlined,
                            size: 12, color: AppColors.neutral500),
                        const SizedBox(width: 3),
                        Text(
                          'Nível ${location.level}',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.neutral500),
                        ),
                      ],
                      if ((location.room ?? '').isEmpty &&
                          (location.level ?? '').isEmpty)
                        Text(
                          'Seção ${location.section}',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.neutral500),
                        ),
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

// ─── Estado vazio ───────────────────────────────────────────────────────────

class _EmptyLocations extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyLocations({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_location_alt_rounded,
                  size: 44, color: AppColors.brandPrimary600),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Nenhuma localização cadastrada',
              style: AppTypography.headingMedium.copyWith(color: AppColors.neutral900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Cadastre seções e prateleiras para organizar\no estoque e facilitar o armazenamento.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            // Exemplos de como organizar
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary100,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.brandPrimary100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exemplos de organização:',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.brandPrimary700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ExampleRow(icon: Icons.shelves, text: 'Seção A • Prateleira 1 • Depósito Principal'),
                  _ExampleRow(icon: Icons.shelves, text: 'Seção B • Prateleira 2 • Nível Superior'),
                  _ExampleRow(icon: Icons.shelves, text: 'Seção C • Prateleira 1 • Almoxarifado'),
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

class _ExampleRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ExampleRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.brandPrimary500),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(color: AppColors.brandPrimary600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Formulário (Bottom Sheet) ──────────────────────────────────────────────

class _LocationFormSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _LocationFormSheet({required this.ref});

  @override
  ConsumerState<_LocationFormSheet> createState() => _LocationFormSheetState();
}

class _LocationFormSheetState extends ConsumerState<_LocationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _sectionCtrl = TextEditingController();
  final _shelfCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _sectionCtrl.dispose();
    _shelfCtrl.dispose();
    _levelCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    await widget.ref.read(locationsNotifierProvider.notifier).createLocation(
          section: _sectionCtrl.text.trim(),
          shelf: _shelfCtrl.text.trim(),
          level: _levelCtrl.text.trim(),
          room: _roomCtrl.text.trim(),
        );

    setState(() => _saving = false);
    final state = widget.ref.read(locationsNotifierProvider);
    if (!mounted) return;
    state.when(
      data: (_) {
        Navigator.pop(context);
        showCasaSnackbar(
          context,
          message: 'Localização cadastrada com sucesso!',
          isSuccess: true,
        );
      },
      error: (e, _) => showCasaSnackbar(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      ),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, bottom + AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Cabeçalho
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary100,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: const Icon(Icons.add_location_alt_rounded,
                      color: AppColors.brandPrimary600, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nova Localização',
                        style: AppTypography.headingMedium
                            .copyWith(color: AppColors.neutral900)),
                    Text('Preencha a estrutura do espaço',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.neutral500)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Campos obrigatórios
            Text(
              'CAMPOS OBRIGATÓRIOS',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.neutral500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: CasaTextField(
                    label: 'Seção *',
                    hint: 'Ex: A',
                    controller: _sectionCtrl,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.grid_view_rounded, size: 18),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: CasaTextField(
                    label: 'Prateleira *',
                    hint: 'Ex: 1',
                    controller: _shelfCtrl,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.shelves, size: 18),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Campos opcionais
            Text(
              'DETALHES OPCIONAIS',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.neutral500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: CasaTextField(
                    label: 'Nível',
                    hint: 'Ex: Superior',
                    controller: _levelCtrl,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.layers_outlined, size: 18),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: CasaTextField(
                    label: 'Sala / Depósito',
                    hint: 'Ex: Depósito A',
                    controller: _roomCtrl,
                    textInputAction: TextInputAction.done,
                    prefixIcon: const Icon(Icons.door_back_door_outlined, size: 18),
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Botão salvar
            CasaButton(
              label: 'Salvar Localização',
              icon: Icons.add_location_alt_rounded,
              onPressed: _saving ? null : _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
