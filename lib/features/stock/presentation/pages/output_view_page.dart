import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';

const _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF0F2444), Color(0xFF1A3A6B), Color(0xFF1D5FA8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class OutputViewPage extends StatefulWidget {
  final Map<String, dynamic> output;
  const OutputViewPage({super.key, required this.output});

  @override
  State<OutputViewPage> createState() => _OutputViewPageState();
}

class _OutputViewPageState extends State<OutputViewPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movements = (widget.output['movements'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final createdAtRaw = widget.output['createdAt'] as String?;
    final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;
    final totalConsumed = movements.fold<int>(0, (s, m) => s + ((m['consumed'] as num?)?.toInt() ?? 0));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFF6FF),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            _OutputSliverAppBar(
              tabController: _tabController,
              createdAt: createdAt,
              totalItems: movements.length,
              totalConsumed: totalConsumed,
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _ResumoTab(output: widget.output, movements: movements),
              _ItensTab(movements: movements),
              _LocalizacoesTab(movements: movements),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sliver AppBar with gradient + tabs ──────────────────────────────────────

class _OutputSliverAppBar extends StatelessWidget {
  final TabController tabController;
  final DateTime? createdAt;
  final int totalItems;
  final int totalConsumed;

  const _OutputSliverAppBar({
    required this.tabController,
    required this.createdAt,
    required this.totalItems,
    required this.totalConsumed,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy • HH:mm');
    return SliverAppBar(
      pinned: true,
      expandedHeight: 130,
      backgroundColor: const Color(0xFF0F2444),
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: _kHeaderGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Saída registrada',
                              style: AppTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (createdAt != null)
                        Text(
                          fmt.format(createdAt!),
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.70),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatPill(label: '$totalItems produto${totalItems != 1 ? 's' : ''}', icon: Icons.inventory_2_outlined),
                      const SizedBox(width: 8),
                      _StatPill(label: '$totalConsumed unidade${totalConsumed != 1 ? 's' : ''}', icon: Icons.output_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        collapseMode: CollapseMode.pin,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(46),
        child: Container(
          color: const Color(0xFF0F2444),
          child: TabBar(
            controller: tabController,
            indicatorColor: const Color(0xFF60A5FA),
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
            labelStyle: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: AppTypography.labelSmall,
            tabs: const [
              Tab(icon: Icon(Icons.summarize_outlined, size: 18), text: 'Resumo'),
              Tab(icon: Icon(Icons.inventory_outlined, size: 18), text: 'Lotes'),
              Tab(icon: Icon(Icons.place_outlined, size: 18), text: 'Localizações'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.80), size: 13),
          const SizedBox(width: 5),
          Text(label, style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Tab 1: Resumo ────────────────────────────────────────────────────────────

class _ResumoTab extends StatelessWidget {
  final Map<String, dynamic> output;
  final List<Map<String, dynamic>> movements;

  const _ResumoTab({required this.output, required this.movements});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final createdAtRaw = output['createdAt'] as String?;
    final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final totalConsumed = movements.fold<int>(0, (s, m) => s + ((m['consumed'] as num?)?.toInt() ?? 0));

    // Group by product to count distinct products
    final distinctProducts = <String>{};
    for (final m in movements) {
      final pid = m['productId'] as String?;
      if (pid != null) distinctProducts.add(pid);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── Header card ──
        Container(
          decoration: BoxDecoration(
            gradient: _kHeaderGradient,
            borderRadius: BorderRadius.circular(AppRadius.card + 4),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.output_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saída FEFO', style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                        Text(
                          output['reason'] ?? output['reasonCode'] ?? 'Distribuição',
                          style: AppTypography.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(label: 'ID da saída', value: output['outputId'] ?? '-', valueColor: Colors.white, labelColor: Colors.white60, selectable: true),
              const SizedBox(height: AppSpacing.xs),
              _InfoRow(label: 'Responsável', value: output['performedByName'] ?? '-', valueColor: Colors.white, labelColor: Colors.white60),
              const SizedBox(height: AppSpacing.xs),
              if (createdAt != null)
                _InfoRow(label: 'Data/hora', value: fmt.format(createdAt), valueColor: Colors.white, labelColor: Colors.white60),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Stats row ──
        Row(
          children: [
            Expanded(child: _StatCard(icon: Icons.inventory_2_outlined, label: 'Produtos', value: '${distinctProducts.length}', color: AppColors.brandPrimary600)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _StatCard(icon: Icons.layers_outlined, label: 'Lotes', value: '${movements.length}', color: AppColors.info600)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _StatCard(icon: Icons.output_rounded, label: 'Unidades', value: '$totalConsumed', color: AppColors.success600)),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── FEFO instruction ──
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warning600.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.warning600.withValues(alpha: 0.30)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.warning600, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Critério FEFO aplicado', style: AppTypography.labelSmall.copyWith(color: AppColors.warning600, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Os lotes foram selecionados automaticamente por ordem de vencimento (First Expired, First Out). Retire os itens na ordem indicada na aba Lotes.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.warning600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ── Quick list ──
        Text('Itens desta saída', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.neutral700)),
        const SizedBox(height: AppSpacing.sm),
        ...movements.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;
          final expiry = m['expiryDate'] as String?;
          final expiryDt = expiry != null ? DateTime.tryParse(expiry) : null;
          final daysLeft = expiryDt != null ? expiryDt.difference(DateTime.now()).inDays : null;
          return _QuickItemRow(
            index: idx + 1,
            productName: m['productName'] as String? ?? '-',
            batchId: m['batchId'] as String? ?? '-',
            consumed: (m['consumed'] as num?)?.toInt() ?? 0,
            expiryDt: expiryDt,
            daysLeft: daysLeft,
            cs: cs,
          );
        }),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;
  final bool selectable;
  const _InfoRow({required this.label, required this.value, this.labelColor, this.valueColor, this.selectable = false});

  @override
  Widget build(BuildContext context) {
    final vStyle = AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700, color: valueColor);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: AppTypography.bodySmall.copyWith(color: labelColor ?? AppColors.neutral500)),
        ),
        Expanded(
          child: selectable
              ? SelectableText(value, style: vStyle)
              : Text(value, style: vStyle),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: AppTypography.headingSmall.copyWith(color: color, fontWeight: FontWeight.w800)),
          Text(label, style: AppTypography.labelSmall.copyWith(color: color.withValues(alpha: 0.80))),
        ],
      ),
    );
  }
}

class _QuickItemRow extends StatelessWidget {
  final int index;
  final String productName;
  final String batchId;
  final int consumed;
  final DateTime? expiryDt;
  final int? daysLeft;
  final ColorScheme cs;
  const _QuickItemRow({
    required this.index,
    required this.productName,
    required this.batchId,
    required this.consumed,
    required this.expiryDt,
    required this.daysLeft,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final urgentColor = daysLeft != null && daysLeft! <= 7 ? AppColors.danger600 : AppColors.neutral500;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: AppColors.brandPrimary100, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('$index', style: AppTypography.labelSmall.copyWith(color: AppColors.brandPrimary700, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName, style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Lote: $batchId', style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$consumed un.', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700)),
              if (expiryDt != null)
                Text(
                  DateFormat('dd/MM/yy').format(expiryDt!),
                  style: AppTypography.bodySmall.copyWith(color: urgentColor, fontWeight: daysLeft != null && daysLeft! <= 7 ? FontWeight.w700 : FontWeight.normal),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab 2: Lotes / Itens ────────────────────────────────────────────────────

class _ItensTab extends StatelessWidget {
  final List<Map<String, dynamic>> movements;
  const _ItensTab({required this.movements});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (movements.isEmpty) {
      return const CasaEmptyState(icon: Icons.inventory_2_outlined, title: 'Sem itens', description: 'Nenhum item registrado nesta saída.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: movements.length,
      itemBuilder: (_, i) {
        final m = movements[i];
        final expiry = m['expiryDate'] as String?;
        final expiryDt = expiry != null ? DateTime.tryParse(expiry) : null;
        final daysLeft = expiryDt != null ? expiryDt.difference(DateTime.now()).inDays : null;
        final after = (m['after'] as num?)?.toInt() ?? 0;
        final consumed = (m['consumed'] as num?)?.toInt() ?? 0;
        final before = (m['before'] as num?)?.toInt() ?? 0;
        final location = m['shelfLocation'] as String?;

        Color urgency = AppColors.success600;
        String urgencyLabel = 'OK';
        IconData urgencyIcon = Icons.check_circle_outline_rounded;
        if (daysLeft != null) {
          if (daysLeft <= 0) {
            urgency = AppColors.neutral500;
            urgencyLabel = 'Vencido';
            urgencyIcon = Icons.block_rounded;
          } else if (daysLeft <= 7) {
            urgency = AppColors.danger600;
            urgencyLabel = '$daysLeft dias';
            urgencyIcon = Icons.warning_rounded;
          } else if (daysLeft <= 30) {
            urgency = AppColors.warning600;
            urgencyLabel = '$daysLeft dias';
            urgencyIcon = Icons.schedule_rounded;
          } else {
            urgencyLabel = '$daysLeft dias';
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.card + 2),
            border: Border.all(color: urgency.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header strip ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                decoration: BoxDecoration(
                  color: urgency.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card + 2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m['productName'] as String? ?? '-',
                        style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgency.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(urgencyIcon, color: urgency, size: 13),
                          const SizedBox(width: 4),
                          Text(urgencyLabel, style: AppTypography.labelSmall.copyWith(color: urgency, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Body ──
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _FieldTile(icon: Icons.qr_code_2_rounded, label: 'Lote', value: m['batchId'] as String? ?? '-')),
                        Expanded(
                          child: _FieldTile(
                            icon: Icons.calendar_today_outlined,
                            label: 'Validade',
                            value: expiryDt != null ? DateFormat('dd/MM/yyyy').format(expiryDt) : 'Sem validade',
                            valueColor: daysLeft != null && daysLeft <= 7 ? AppColors.danger600 : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _FieldTile(
                            icon: Icons.place_outlined,
                            label: 'Localização',
                            value: location?.isNotEmpty == true ? location! : 'Não informada',
                            valueColor: location?.isNotEmpty == true ? AppColors.brandPrimary600 : null,
                          ),
                        ),
                        Expanded(
                          child: _FieldTile(
                            icon: Icons.output_rounded,
                            label: 'Retirar',
                            value: '$consumed unidade${consumed != 1 ? 's' : ''}',
                            valueColor: AppColors.brandPrimary700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // ── Stock bar ──
                    _StockProgressBar(before: before, after: after, consumed: consumed),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _FieldTile({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.neutral500),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500)),
              Text(value, style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700, color: valueColor ?? AppColors.neutral900), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockProgressBar extends StatelessWidget {
  final int before;
  final int after;
  final int consumed;
  const _StockProgressBar({required this.before, required this.after, required this.consumed});

  @override
  Widget build(BuildContext context) {
    final pct = before > 0 ? (after / before).clamp(0.0, 1.0) : 0.0;
    final barColor = after <= 0 ? AppColors.neutral500 : (pct < 0.2 ? AppColors.danger600 : AppColors.brandPrimary500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Estoque restante no lote', style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500)),
            Text(after <= 0 ? 'Esgotado' : '$after restam', style: AppTypography.labelSmall.copyWith(color: barColor, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.neutral100,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 4),
        Text('Antes: $before → Retirado: $consumed → Após: $after', style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500, fontSize: 10)),
      ],
    );
  }
}

// ─── Tab 3: Localizações ─────────────────────────────────────────────────────

class _LocalizacoesTab extends StatelessWidget {
  final List<Map<String, dynamic>> movements;
  const _LocalizacoesTab({required this.movements});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Group by location
    final Map<String, List<Map<String, dynamic>>> byLocation = {};
    for (final m in movements) {
      final loc = (m['shelfLocation'] as String?)?.isNotEmpty == true
          ? m['shelfLocation'] as String
          : 'Sem localização';
      byLocation.putIfAbsent(loc, () => []).add(m);
    }

    if (byLocation.isEmpty) {
      return const CasaEmptyState(icon: Icons.place_outlined, title: 'Sem localizações', description: 'Nenhuma localização registrada.');
    }

    final hasLocation = byLocation.keys.any((k) => k != 'Sem localização');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (hasLocation)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.brandPrimary100,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.brandPrimary500.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: AppColors.brandPrimary700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Retire os itens nos endereços indicados abaixo. Os lotes estão ordenados por vencimento (FEFO).',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.brandPrimary700),
                  ),
                ),
              ],
            ),
          ),
        ...byLocation.entries.toList().asMap().entries.map((entry) {
          final locationName = entry.value.key;
          final items = entry.value.value;
          final isNoLocation = locationName == 'Sem localização';

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.card + 2),
              border: Border.all(
                color: isNoLocation
                    ? AppColors.neutral500.withValues(alpha: 0.20)
                    : AppColors.brandPrimary500.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Location header ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                  decoration: BoxDecoration(
                    color: isNoLocation
                        ? AppColors.neutral100
                        : AppColors.brandPrimary100,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card + 2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isNoLocation ? Icons.help_outline_rounded : Icons.place_rounded,
                        color: isNoLocation ? AppColors.neutral500 : AppColors.brandPrimary700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationName,
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isNoLocation ? AppColors.neutral700 : AppColors.brandPrimary700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isNoLocation
                              ? AppColors.neutral500.withValues(alpha: 0.12)
                              : AppColors.brandPrimary600.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${items.length} lote${items.length != 1 ? 's' : ''}',
                          style: AppTypography.labelSmall.copyWith(
                            color: isNoLocation ? AppColors.neutral500 : AppColors.brandPrimary600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Items in this location ──
                ...items.asMap().entries.map((ie) {
                  final isLast = ie.key == items.length - 1;
                  final m = ie.value;
                  final expiry = m['expiryDate'] as String?;
                  final expiryDt = expiry != null ? DateTime.tryParse(expiry) : null;
                  final daysLeft = expiryDt != null ? expiryDt.difference(DateTime.now()).inDays : null;
                  final consumed = (m['consumed'] as num?)?.toInt() ?? 0;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.brandPrimary700),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['productName'] as String? ?? '-',
                                    style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.qr_code_2_rounded, size: 12, color: AppColors.neutral500),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          m['batchId'] as String? ?? '-',
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandPrimary600.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$consumed un.',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.brandPrimary700,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (expiryDt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Val: ${DateFormat('dd/MM/yy').format(expiryDt)}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: daysLeft != null && daysLeft <= 7 ? AppColors.danger600 : AppColors.neutral500,
                                      fontWeight: daysLeft != null && daysLeft <= 7 ? FontWeight.w700 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: cs.outlineVariant.withValues(alpha: 0.4)),
                    ],
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}
