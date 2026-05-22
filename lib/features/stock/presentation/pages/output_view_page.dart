import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';

const _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF0F2444), Color(0xFF1A3A6B), Color(0xFF1D5FA8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Helpers de localização ───────────────────────────────────────────────────

/// Interpreta "NomeLoc • Secao A • Prateleira 2 • Nivel 3 • Sala X"
Map<String, String?> _parseLocation(String? raw) {
  if (raw == null || raw.trim().isEmpty) return {};
  final parts = raw.split('•').map((p) => p.trim()).where((p) => p.isNotEmpty);
  String? name, section, shelf, level, room;
  for (final p in parts) {
    if (p.startsWith('Secao ')) {
      section = p.substring(6).trim();
    } else if (p.startsWith('Prateleira ')) {
      shelf = p.substring(11).trim();
    } else if (p.startsWith('Nivel ')) {
      level = p.substring(6).trim();
    } else if (p.startsWith('Sala ')) {
      room = p.substring(5).trim();
    } else {
      name ??= p;
    }
  }
  return {'name': name, 'section': section, 'shelf': shelf, 'level': level, 'room': room};
}

Color _sectionColor(String? section) {
  if (section == null || section.isEmpty) return const Color(0xFF64748B);
  const palette = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFFDC2626),
  ];
  return palette[section.codeUnitAt(0) % palette.length];
}

/// Gera uma chave única de localização para agrupamento
String _locationKey(Map<String, String?> loc) {
  final parts = [
    if (loc['section'] != null) 'S${loc['section']}',
    if (loc['shelf'] != null) 'P${loc['shelf']}',
    if (loc['level'] != null) 'N${loc['level']}',
    if (loc['room'] != null) 'R${loc['room']}',
    if (loc['name'] != null) loc['name']!,
  ];
  return parts.isEmpty ? 'sem_local' : parts.join('-');
}

// ─── Página principal ─────────────────────────────────────────────────────────

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
              _LotesTab(movements: movements),
              _LocalizacoesTab(movements: movements),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sliver AppBar ────────────────────────────────────────────────────────────

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
                      _StatPill(label: '$totalItems lote${totalItems != 1 ? 's' : ''}', icon: Icons.layers_outlined),
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

        // ── FEFO info ──
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
                      'Os lotes foram selecionados automaticamente por ordem de vencimento. Retire os itens na ordem indicada na aba Lotes.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.warning600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        Text('Itens desta saída', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.neutral700)),
        const SizedBox(height: AppSpacing.sm),
        ...movements.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;
          final expiry = m['expiryDate'] as String?;
          final expiryDt = expiry != null ? DateTime.tryParse(expiry) : null;
          final daysLeft = expiryDt?.difference(DateTime.now()).inDays;
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
                  style: AppTypography.bodySmall.copyWith(
                    color: urgentColor,
                    fontWeight: daysLeft != null && daysLeft! <= 7 ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab 2: Lotes ─────────────────────────────────────────────────────────────

class _LotesTab extends StatelessWidget {
  final List<Map<String, dynamic>> movements;
  const _LotesTab({required this.movements});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (movements.isEmpty) {
      return const CasaEmptyState(icon: Icons.inventory_2_outlined, title: 'Sem lotes', description: 'Nenhum lote registrado nesta saída.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: movements.length,
      itemBuilder: (_, i) {
        final m = movements[i];
        final expiry = m['expiryDate'] as String?;
        final expiryDt = expiry != null ? DateTime.tryParse(expiry) : null;
        final daysLeft = expiryDt?.difference(DateTime.now()).inDays;
        final after = (m['after'] as num?)?.toInt() ?? 0;
        final consumed = (m['consumed'] as num?)?.toInt() ?? 0;
        final before = (m['before'] as num?)?.toInt() ?? 0;
        final locationRaw = m['shelfLocation'] as String?;
        final loc = _parseLocation(locationRaw);

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

        final sectionColor = _sectionColor(loc['section']);
        final hasLocation = loc.isNotEmpty && loc.values.any((v) => v != null);

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
              // ── Header ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                decoration: BoxDecoration(
                  color: urgency.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card + 2)),
                ),
                child: Row(
                  children: [
                    // Índice de ordem
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: urgency.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${i + 1}', style: AppTypography.labelSmall.copyWith(color: urgency, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
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

              // ── Corpo ──
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    // Lote + Validade
                    Row(
                      children: [
                        Expanded(
                          child: _FieldTile(
                            icon: Icons.qr_code_2_rounded,
                            label: 'Lote',
                            value: m['batchId'] as String? ?? '-',
                            monospace: true,
                          ),
                        ),
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

                    // Localização visual
                    if (hasLocation) ...[
                      _LocationAddressRow(loc: loc, sectionColor: sectionColor),
                      const SizedBox(height: AppSpacing.sm),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _FieldTile(
                              icon: Icons.place_outlined,
                              label: 'Localização',
                              value: 'Não informada',
                              valueColor: AppColors.neutral500,
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    // Quantidade a retirar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.output_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Text('Retirar desta localização:', style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
                          const Spacer(),
                          Text(
                            '$consumed unidade${consumed != 1 ? 's' : ''}',
                            style: AppTypography.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Barra de estoque
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

// ─── Widget de endereço de localização ───────────────────────────────────────

class _LocationAddressRow extends StatelessWidget {
  final Map<String, String?> loc;
  final Color sectionColor;
  const _LocationAddressRow({required this.loc, required this.sectionColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sectionColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: sectionColor.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          // Ícone de localização colorido
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: sectionColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.place_rounded, color: sectionColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loc['name'] != null)
                  Text(loc['name']!, style: AppTypography.labelSmall.copyWith(color: AppColors.neutral700, fontWeight: FontWeight.w700)),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (loc['section'] != null)
                      _AddrChip(label: 'Seção ${loc['section']}', color: sectionColor),
                    if (loc['shelf'] != null)
                      _AddrChip(label: 'Prateleira ${loc['shelf']}', color: const Color(0xFF0891B2)),
                    if (loc['level'] != null)
                      _AddrChip(label: 'Nível ${loc['level']}', color: const Color(0xFF7C3AED)),
                    if (loc['room'] != null)
                      _AddrChip(label: 'Sala ${loc['room']}', color: const Color(0xFF059669)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddrChip extends StatelessWidget {
  final String label;
  final Color color;
  const _AddrChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(label, style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;
  const _FieldTile({required this.icon, required this.label, required this.value, this.valueColor, this.monospace = false});

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
              Text(
                value,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.neutral900,
                  fontFamily: monospace ? 'monospace' : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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

    // Agrupar por localização parseada
    final Map<String, _LocationGroup> groups = {};
    for (final m in movements) {
      final raw = m['shelfLocation'] as String?;
      final loc = _parseLocation(raw);
      final key = loc.isEmpty ? 'sem_local' : _locationKey(loc);
      groups.putIfAbsent(key, () => _LocationGroup(raw: raw, loc: loc, items: [])).items.add(m);
    }

    if (groups.isEmpty) {
      return const CasaEmptyState(icon: Icons.place_outlined, title: 'Sem localizações', description: 'Nenhuma localização registrada.');
    }

    final hasAnyLocation = groups.values.any((g) => g.loc.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // ── Banner ──
        if (hasAnyLocation)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.route_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Siga a ordem abaixo para retirar os itens. Os lotes estão organizados por vencimento (FEFO).',
                    style: AppTypography.bodySmall.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

        // ── Grupos por localização ──
        ...groups.entries.toList().asMap().entries.map((mapEntry) {
          final stepIndex = mapEntry.key;
          final group = mapEntry.value.value;
          return _LocationGroupCard(
            stepIndex: stepIndex + 1,
            group: group,
            cs: cs,
          );
        }),
      ],
    );
  }
}

class _LocationGroup {
  final String? raw;
  final Map<String, String?> loc;
  final List<Map<String, dynamic>> items;
  _LocationGroup({required this.raw, required this.loc, required this.items});
}

class _LocationGroupCard extends StatelessWidget {
  final int stepIndex;
  final _LocationGroup group;
  final ColorScheme cs;

  const _LocationGroupCard({
    required this.stepIndex,
    required this.group,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final loc = group.loc;
    final isNoLocation = loc.isEmpty;
    final sectionColor = isNoLocation ? AppColors.neutral500 : _sectionColor(loc['section']);
    final section = loc['section'];
    final shelf = loc['shelf'];
    final level = loc['level'];
    final room = loc['room'];
    final name = loc['name'];
    final totalConsumed = group.items.fold<int>(0, (s, m) => s + ((m['consumed'] as num?)?.toInt() ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        border: Border.all(
          color: isNoLocation
              ? const Color(0xFFD1D5DB)
              : sectionColor.withValues(alpha: 0.30),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: sectionColor.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header da localização ──
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isNoLocation ? AppColors.neutral100 : sectionColor.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card + 4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Número do passo
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: isNoLocation
                        ? null
                        : LinearGradient(
                            colors: [sectionColor, sectionColor.withValues(alpha: 0.75)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isNoLocation ? AppColors.neutral500 : null,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isNoLocation
                        ? []
                        : [BoxShadow(color: sectionColor.withValues(alpha: 0.30), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Center(
                    child: Text('$stepIndex', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNoLocation)
                        Text('Sem localização definida', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.neutral700))
                      else ...[
                        if (name != null)
                          Text(name, style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.neutral900)),
                        // ── Endereço em chips ──
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (section != null)
                              _AddrChip(label: 'Seção $section', color: sectionColor),
                            if (shelf != null)
                              _AddrChip(label: 'Prateleira $shelf', color: const Color(0xFF0891B2)),
                            if (level != null)
                              _AddrChip(label: 'Nível $level', color: const Color(0xFF7C3AED)),
                            if (room != null)
                              _AddrChip(label: 'Sala $room', color: const Color(0xFF059669)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sectionColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${group.items.length} lote${group.items.length != 1 ? 's' : ''}',
                        style: AppTypography.labelSmall.copyWith(color: sectionColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalConsumed un.',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.neutral700, fontWeight: FontWeight.w600, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Diagrama visual de prateleira/nível ──
          if (!isNoLocation && (shelf != null || level != null))
            _ShelfDiagram(section: section, shelf: shelf, level: level, sectionColor: sectionColor),

          // ── Itens nesta localização ──
          ...group.items.asMap().entries.map((ie) {
            final isLast = ie.key == group.items.length - 1;
            final m = ie.value;
            final expiry = m['expiryDate'] as String?;
            final expiryDt = expiry != null ? DateTime.tryParse(expiry) : null;
            final daysLeft = expiryDt?.difference(DateTime.now()).inDays;
            final consumed = (m['consumed'] as num?)?.toInt() ?? 0;

            Color urgency = AppColors.success600;
            if (daysLeft != null) {
              if (daysLeft <= 0) {
                urgency = AppColors.neutral500;
              } else if (daysLeft <= 7) {
                urgency = AppColors.danger600;
              } else if (daysLeft <= 30) {
                urgency = AppColors.warning600;
              }
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: urgency.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: urgency.withValues(alpha: 0.20)),
                        ),
                        child: Center(child: Icon(Icons.inventory_2_outlined, size: 18, color: urgency)),
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
                                Icon(Icons.qr_code_2_rounded, size: 11, color: AppColors.neutral500),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    m['batchId'] as String? ?? '-',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.neutral500,
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (expiryDt != null)
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 11, color: urgency),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Val: ${DateFormat('dd/MM/yyyy').format(expiryDt)}',
                                    style: AppTypography.bodySmall.copyWith(color: urgency, fontWeight: daysLeft != null && daysLeft <= 7 ? FontWeight.w700 : FontWeight.normal, fontSize: 10),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Text(
                          '$consumed un.',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: cs.outlineVariant.withValues(alpha: 0.4)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Diagrama visual de prateleira / nível ────────────────────────────────────

class _ShelfDiagram extends StatelessWidget {
  final String? section;
  final String? shelf;
  final String? level;
  final Color sectionColor;

  const _ShelfDiagram({
    required this.section,
    required this.shelf,
    required this.level,
    required this.sectionColor,
  });

  @override
  Widget build(BuildContext context) {
    // Tenta parsear o nível como número; se não conseguir usa string
    final levelNum = level != null ? int.tryParse(level!) : null;
    const maxLevels = 4; // número máximo de níveis a mostrar no diagrama
    final targetLevel = (levelNum != null && levelNum >= 1 && levelNum <= maxLevels) ? levelNum : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: sectionColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: sectionColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Seção badge
          if (section != null) ...[
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: sectionColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      section!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text('Seção', style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500, fontSize: 9)),
              ],
            ),
            // Seta
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right_rounded, color: sectionColor.withValues(alpha: 0.50), size: 18),
            ),
          ],

          // Prateleira badge
          if (shelf != null) ...[
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0891B2).withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.view_week_outlined, size: 14, color: Color(0xFF0891B2)),
                      const SizedBox(width: 4),
                      Text(shelf!, style: const TextStyle(color: Color(0xFF0891B2), fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text('Prateleira', style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500, fontSize: 9)),
              ],
            ),
          ],

          // Seta + nível
          if (level != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right_rounded, color: const Color(0xFF7C3AED).withValues(alpha: 0.50), size: 18),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers_outlined, size: 14, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 4),
                      Text(level!, style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text('Nível', style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500, fontSize: 9)),
              ],
            ),
          ],

          const Spacer(),

          // Mini visualização vertical de níveis
          if (targetLevel != null)
            _MiniLevelStack(targetLevel: targetLevel, totalLevels: maxLevels, color: const Color(0xFF7C3AED)),
        ],
      ),
    );
  }
}

/// Pilha vertical mostrando qual nível está destacado
class _MiniLevelStack extends StatelessWidget {
  final int targetLevel;
  final int totalLevels;
  final Color color;
  const _MiniLevelStack({required this.targetLevel, required this.totalLevels, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Níveis de cima para baixo
        for (int lvl = totalLevels; lvl >= 1; lvl--)
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: lvl == targetLevel ? color : color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: lvl == targetLevel ? color : color.withValues(alpha: 0.20),
                width: lvl == targetLevel ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lvl == targetLevel)
                  const Icon(Icons.arrow_left_rounded, size: 12, color: Colors.white),
                Text(
                  'N$lvl',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: lvl == targetLevel ? Colors.white : color.withValues(alpha: 0.40),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
