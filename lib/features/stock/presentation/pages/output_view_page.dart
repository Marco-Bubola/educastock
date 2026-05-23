import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';

const _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF0D1F3C), Color(0xFF163C6E), Color(0xFF1A5BAD)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Helpers de localização ───────────────────────────────────────────────────

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

// ─── Tema helpers ─────────────────────────────────────────────────────────────

extension _ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get pageBg => isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
  Color get cardBg => isDark ? const Color(0xFF111827) : Colors.white;
  Color get textPrimary => isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
  Color get textSub => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
  Color get borderCol => isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
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
        backgroundColor: context.pageBg,
        bottomNavigationBar: _BottomBar(isDark: context.isDark),
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

// ─── Bottom bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool isDark;
  const _BottomBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text('Concluir e fechar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
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
      expandedHeight: 148,
      backgroundColor: const Color(0xFF0D1F3C),
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: _kHeaderGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Badge de sucesso
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Saída registrada',
                              style: AppTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
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
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatPill(label: '$totalItems lote${totalItems != 1 ? 's' : ''}', icon: Icons.layers_outlined),
                      const SizedBox(width: 8),
                      _StatPill(label: '$totalConsumed un. distribuída${totalConsumed != 1 ? 's' : ''}', icon: Icons.output_rounded),
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
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: const Color(0xFF0D1F3C),
          child: TabBar(
            controller: tabController,
            indicatorColor: const Color(0xFF60A5FA),
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.50),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    final isDark = context.isDark;
    final cardBg = context.cardBg;
    final textPrimary = context.textPrimary;
    final textSub = context.textSub;
    final borderColor = context.borderCol;

    final createdAtRaw = output['createdAt'] as String?;
    final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final totalConsumed = movements.fold<int>(0, (s, m) => s + ((m['consumed'] as num?)?.toInt() ?? 0));

    final distinctProducts = <String>{};
    for (final m in movements) {
      final pid = m['productId'] as String?;
      if (pid != null) distinctProducts.add(pid);
    }

    final reasonCode = output['reasonCode'] as String? ?? 'outro';
    final reasonLabel = _reasonLabels[reasonCode] ?? (output['reason'] as String? ?? 'Distribuição');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        // ── Header card ──
        Container(
          decoration: BoxDecoration(
            gradient: _kHeaderGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A5BAD).withValues(alpha: isDark ? 0.3 : 0.20),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                    ),
                    child: const Icon(Icons.output_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saída FEFO',
                            style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                        Text(reasonLabel,
                            style: AppTypography.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.75))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 16),
              _InfoRow(label: 'ID da saída', value: output['outputId'] ?? '-',
                  valueColor: Colors.white, labelColor: Colors.white60, selectable: true),
              const SizedBox(height: 6),
              _InfoRow(label: 'Responsável', value: output['performedByName'] ?? '-',
                  valueColor: Colors.white, labelColor: Colors.white60),
              const SizedBox(height: 6),
              if (createdAt != null)
                _InfoRow(label: 'Data/hora', value: fmt.format(createdAt),
                    valueColor: Colors.white, labelColor: Colors.white60),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Stats row ──
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.inventory_2_outlined,
                label: 'Produtos',
                value: '${distinctProducts.length}',
                color: AppColors.brandPrimary600,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.layers_outlined,
                label: 'Lotes',
                value: '${movements.length}',
                color: AppColors.info600,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.output_rounded,
                label: 'Unidades',
                value: '$totalConsumed',
                color: AppColors.success600,
                isDark: isDark,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── FEFO info ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning600.withValues(alpha: isDark ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.warning600.withValues(alpha: 0.30)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.warning600.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppColors.warning600, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Critério FEFO aplicado',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.warning600, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
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

        const SizedBox(height: 20),

        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A5BAD), Color(0xFF163C6E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text('Itens desta saída',
                style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w800, color: textPrimary)),
          ],
        ),
        const SizedBox(height: 10),
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
            isDark: isDark,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSub: textSub,
            borderColor: borderColor,
          );
        }),
      ],
    );
  }
}

const _reasonLabels = <String, String>{
  'uso': 'Uso / Distribuição',
  'receita': 'Receita',
  'validade': 'Vencimento',
  'avaria': 'Avaria',
  'doacao': 'Doação',
  'outro': 'Outro',
};

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
          child: Text(label, style: AppTypography.bodySmall.copyWith(color: labelColor ?? context.textSub)),
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
  final bool isDark;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: isDark ? 0.18 : 0.10), color.withValues(alpha: isDark ? 0.08 : 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.headingSmall.copyWith(color: color, fontWeight: FontWeight.w800)),
          Text(label, style: AppTypography.labelSmall.copyWith(color: color.withValues(alpha: 0.85))),
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
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSub;
  final Color borderColor;

  const _QuickItemRow({
    required this.index,
    required this.productName,
    required this.batchId,
    required this.consumed,
    required this.expiryDt,
    required this.daysLeft,
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSub,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final urgentColor = daysLeft != null && daysLeft! <= 7 ? AppColors.danger600 : AppColors.neutral500;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A5BAD), Color(0xFF163C6E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(productName,
                    style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700, color: textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Lote: $batchId',
                    style: AppTypography.bodySmall.copyWith(color: textSub),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
                  color: AppColors.success600.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$consumed un.',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.success600, fontWeight: FontWeight.w700),
                ),
              ),
              if (expiryDt != null) ...[
                const SizedBox(height: 3),
                Text(
                  DateFormat('dd/MM/yy').format(expiryDt!),
                  style: AppTypography.bodySmall.copyWith(
                    color: urgentColor,
                    fontWeight: daysLeft != null && daysLeft! <= 7 ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 10,
                  ),
                ),
              ],
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
    final isDark = context.isDark;
    final cardBg = context.cardBg;
    final textPrimary = context.textPrimary;
    final textSub = context.textSub;

    if (movements.isEmpty) {
      return const CasaEmptyState(icon: Icons.inventory_2_outlined, title: 'Sem lotes', description: 'Nenhum lote registrado nesta saída.');
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: urgency.withValues(alpha: 0.28), width: 1.5),
            boxShadow: isDark
                ? []
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: urgency.withValues(alpha: isDark ? 0.12 : 0.07),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: urgency.withValues(alpha: isDark ? 0.22 : 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: AppTypography.labelSmall.copyWith(color: urgency, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        m['productName'] as String? ?? '-',
                        style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w800, color: textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgency.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(urgencyIcon, color: urgency, size: 12),
                          const SizedBox(width: 4),
                          Text(urgencyLabel,
                              style: AppTypography.labelSmall.copyWith(color: urgency, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Corpo ──
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _FieldTile(
                            icon: Icons.qr_code_2_rounded,
                            label: 'Lote',
                            value: m['batchId'] as String? ?? '-',
                            monospace: true,
                            textPrimary: textPrimary,
                            textSub: textSub,
                          ),
                        ),
                        Expanded(
                          child: _FieldTile(
                            icon: Icons.calendar_today_outlined,
                            label: 'Validade',
                            value: expiryDt != null ? DateFormat('dd/MM/yyyy').format(expiryDt) : 'Sem validade',
                            valueColor: daysLeft != null && daysLeft <= 7 ? AppColors.danger600 : null,
                            textPrimary: textPrimary,
                            textSub: textSub,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (hasLocation) ...[
                      _LocationAddressRow(loc: loc, sectionColor: sectionColor, isDark: isDark),
                      const SizedBox(height: 10),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _FieldTile(
                              icon: Icons.place_outlined,
                              label: 'Localização',
                              value: 'Não informada',
                              valueColor: textSub,
                              textPrimary: textPrimary,
                              textSub: textSub,
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Quantidade a retirar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A5BAD), Color(0xFF2563EB)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark
                            ? []
                            : [BoxShadow(color: const Color(0xFF1A5BAD).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.output_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          Text('Retirar desta localização:',
                              style: AppTypography.bodySmall.copyWith(color: Colors.white70)),
                          const Spacer(),
                          Text(
                            '$consumed unidade${consumed != 1 ? 's' : ''}',
                            style: AppTypography.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    _StockProgressBar(before: before, after: after, consumed: consumed, isDark: isDark, textSub: textSub),
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
  final bool isDark;
  const _LocationAddressRow({required this.loc, required this.sectionColor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sectionColor.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sectionColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: sectionColor.withValues(alpha: isDark ? 0.20 : 0.12),
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
                  Text(loc['name']!,
                      style: AppTypography.labelSmall.copyWith(
                          color: context.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(label,
          style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;
  final Color textPrimary;
  final Color textSub;

  const _FieldTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
    required this.textPrimary,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: textSub),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.bodySmall.copyWith(color: textSub)),
              Text(
                value,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? textPrimary,
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
  final bool isDark;
  final Color textSub;

  const _StockProgressBar({
    required this.before,
    required this.after,
    required this.consumed,
    required this.isDark,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    final pct = before > 0 ? (after / before).clamp(0.0, 1.0) : 0.0;
    final barColor = after <= 0
        ? AppColors.neutral500
        : (pct < 0.2 ? AppColors.danger600 : AppColors.brandPrimary500);
    final trackBg = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Estoque restante no lote', style: AppTypography.bodySmall.copyWith(color: textSub)),
            Text(
              after <= 0 ? 'Esgotado' : '$after restam',
              style: AppTypography.labelSmall.copyWith(color: barColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: trackBg,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Antes: $before  ·  Retirado: $consumed  ·  Após: $after',
          style: AppTypography.bodySmall.copyWith(color: textSub, fontSize: 10),
        ),
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
    final isDark = context.isDark;
    final cardBg = context.cardBg;
    final textPrimary = context.textPrimary;
    final textSub = context.textSub;
    final borderColor = context.borderCol;

    final Map<String, _LocationGroup> groups = {};
    for (final m in movements) {
      final raw = m['shelfLocation'] as String?;
      final loc = _parseLocation(raw);
      final key = loc.isEmpty ? 'sem_local' : _locationKey(loc);
      groups.putIfAbsent(key, () => _LocationGroup(raw: raw, loc: loc, items: [])).items.add(m);
    }

    if (groups.isEmpty) {
      return const CasaEmptyState(
          icon: Icons.place_outlined,
          title: 'Sem localizações',
          description: 'Nenhuma localização registrada.');
    }

    final hasAnyLocation = groups.values.any((g) => g.loc.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        if (hasAnyLocation)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF163C6E), Color(0xFF1A5BAD)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? []
                  : [BoxShadow(color: const Color(0xFF1A5BAD).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.route_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Siga a ordem abaixo para retirar os itens. Os lotes estão organizados por vencimento (FEFO).',
                    style: AppTypography.bodySmall.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

        ...groups.entries.toList().asMap().entries.map((mapEntry) {
          final stepIndex = mapEntry.key;
          final group = mapEntry.value.value;
          return _LocationGroupCard(
            stepIndex: stepIndex + 1,
            group: group,
            isDark: isDark,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSub: textSub,
            borderColor: borderColor,
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
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSub;
  final Color borderColor;

  const _LocationGroupCard({
    required this.stepIndex,
    required this.group,
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSub,
    required this.borderColor,
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNoLocation ? borderColor : sectionColor.withValues(alpha: 0.30),
          width: 1.5,
        ),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: sectionColor.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header da localização ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isNoLocation
                  ? (isDark ? const Color(0xFF1F2937) : const Color(0xFFF8FAFC))
                  : sectionColor.withValues(alpha: isDark ? 0.12 : 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
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
                        : [BoxShadow(color: sectionColor.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Center(
                    child: Text('$stepIndex',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNoLocation)
                        Text('Sem localização definida',
                            style: AppTypography.labelMedium.copyWith(
                                fontWeight: FontWeight.w700, color: textPrimary))
                      else ...[
                        if (name != null)
                          Text(name,
                              style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w800, color: textPrimary)),
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
                        color: sectionColor.withValues(alpha: isDark ? 0.18 : 0.10),
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
                      style: AppTypography.labelSmall.copyWith(color: textSub, fontWeight: FontWeight.w600, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Diagrama visual ──
          if (!isNoLocation && (shelf != null || level != null))
            _ShelfDiagram(section: section, shelf: shelf, level: level, sectionColor: sectionColor, isDark: isDark),

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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: urgency.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: urgency.withValues(alpha: 0.22)),
                        ),
                        child: Center(child: Icon(Icons.inventory_2_outlined, size: 18, color: urgency)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['productName'] as String? ?? '-',
                              style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700, color: textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 11, color: textSub),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    m['batchId'] as String? ?? '-',
                                    style: AppTypography.bodySmall.copyWith(
                                        color: textSub, fontFamily: 'monospace', fontSize: 10),
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
                                    style: AppTypography.bodySmall.copyWith(
                                      color: urgency,
                                      fontWeight: daysLeft != null && daysLeft <= 7 ? FontWeight.w700 : FontWeight.normal,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A5BAD), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isDark
                              ? []
                              : [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
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
                  Divider(height: 1, indent: 14, endIndent: 14, color: borderColor),
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
  final bool isDark;

  const _ShelfDiagram({
    required this.section,
    required this.shelf,
    required this.level,
    required this.sectionColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final levelNum = level != null ? int.tryParse(level!) : null;
    const maxLevels = 4;
    final targetLevel = (levelNum != null && levelNum >= 1 && levelNum <= maxLevels) ? levelNum : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sectionColor.withValues(alpha: isDark ? 0.07 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sectionColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                    child: Text(section!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 3),
                Text('Seção', style: AppTypography.bodySmall.copyWith(color: context.textSub, fontSize: 9)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right_rounded, color: sectionColor.withValues(alpha: 0.50), size: 18),
            ),
          ],
          if (shelf != null) ...[
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withValues(alpha: 0.12),
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
                Text('Prateleira', style: AppTypography.bodySmall.copyWith(color: context.textSub, fontSize: 9)),
              ],
            ),
          ],
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
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
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
                Text('Nível', style: AppTypography.bodySmall.copyWith(color: context.textSub, fontSize: 9)),
              ],
            ),
          ],
          const Spacer(),
          if (targetLevel != null)
            _MiniLevelStack(targetLevel: targetLevel, totalLevels: maxLevels, color: const Color(0xFF7C3AED)),
        ],
      ),
    );
  }
}

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
        for (int lvl = totalLevels; lvl >= 1; lvl--)
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: lvl == targetLevel ? color : color.withValues(alpha: 0.07),
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
