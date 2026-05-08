import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/stock_movement.dart';
import '../controllers/stock_provider.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _search = '';
  String? _filterReason; // null = todos
  DateTimeRange? _filterDateRange;

  static const _reasonColors = <String, List<Color>>{
    'uso': [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    'receita': [Color(0xFF7C3AED), Color(0xFF6D28D9)],
    'validade': [Color(0xFFD97706), Color(0xFFB45309)],
    'avaria': [Color(0xFFDC2626), Color(0xFFB91C1C)],
    'doacao': [Color(0xFF059669), Color(0xFF047857)],
    'outro': [Color(0xFF6B7280), Color(0xFF4B5563)],
  };

  static const _reasonLabels = <String, String>{
    'uso': 'Distribuição',
    'receita': 'Receita',
    'validade': 'Vencimento',
    'avaria': 'Avaria',
    'doacao': 'Doação',
    'outro': 'Outro',
  };

  static const _reasonIcons = <String, IconData>{
    'uso': Icons.outbound_rounded,
    'receita': Icons.menu_book_rounded,
    'validade': Icons.hourglass_disabled_rounded,
    'avaria': Icons.broken_image_outlined,
    'doacao': Icons.volunteer_activism_rounded,
    'outro': Icons.more_horiz_rounded,
  };

  int get _activeFilterCount =>
      (_filterReason != null ? 1 : 0) + (_filterDateRange != null ? 1 : 0);

  void _showFilterModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? tempReason = _filterReason;
    DateTimeRange? tempRange = _filterDateRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bg = isDark ? const Color(0xFF111827) : Colors.white;
          final textPrimary =
              isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
          final textSub =
              isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
          final borderColor =
              isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
          final pillBg =
              isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);

          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 8,
                left: 20,
                right: 20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Filtrar Histórico',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    if (tempReason != null || tempRange != null)
                      TextButton(
                        onPressed: () => setModalState(() {
                          tempReason = null;
                          tempRange = null;
                        }),
                        child: const Text(
                          'Limpar',
                          style: TextStyle(
                            color: Color(0xFF7C3AED),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'MOTIVO',
                  style: TextStyle(
                    color: textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ModalChip(
                      label: 'Todos',
                      icon: Icons.select_all_rounded,
                      selected: tempReason == null,
                      activeColor: const Color(0xFF7C3AED),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () => setModalState(() => tempReason = null),
                    ),
                    ..._reasonLabels.entries.map((e) => _ModalChip(
                          label: e.value,
                          icon: _reasonIcons[e.key]!,
                          selected: tempReason == e.key,
                          activeColor: _reasonColors[e.key]![0],
                          isDark: isDark,
                          pillBg: pillBg,
                          borderColor: borderColor,
                          onTap: () =>
                              setModalState(() => tempReason = e.key),
                        )),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'PERÍODO',
                  style: TextStyle(
                    color: textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DateRangeChip(
                      label: 'Hoje',
                      icon: Icons.today_rounded,
                      active: tempRange != null &&
                          _isSameDayRange(tempRange!,
                              DateTimeRange(start: _todayDate, end: _todayDate)),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () => setModalState(() {
                        final t = _todayDate;
                        tempRange = DateTimeRange(start: t, end: t);
                      }),
                    ),
                    _DateRangeChip(
                      label: '7 dias',
                      icon: Icons.date_range_rounded,
                      active: tempRange != null &&
                          _isSameDayRange(tempRange!, _last7Days),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () =>
                          setModalState(() => tempRange = _last7Days),
                    ),
                    _DateRangeChip(
                      label: '30 dias',
                      icon: Icons.calendar_month_rounded,
                      active: tempRange != null &&
                          _isSameDayRange(tempRange!, _last30Days),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () =>
                          setModalState(() => tempRange = _last30Days),
                    ),
                    _DateRangeChip(
                      label: 'Personalizado',
                      icon: Icons.edit_calendar_rounded,
                      active: tempRange != null &&
                          !_isSameDayRange(tempRange!, _last7Days) &&
                          !_isSameDayRange(tempRange!, _last30Days) &&
                          !_isSameDayRange(tempRange!,
                              DateTimeRange(start: _todayDate, end: _todayDate)),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: tempRange,
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.fromSeed(
                                seedColor: const Color(0xFF7C3AED),
                                brightness: isDark
                                    ? Brightness.dark
                                    : Brightness.light,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => tempRange = picked);
                        }
                      },
                    ),
                    if (tempRange != null)
                      _DateRangeChip(
                        label: 'Sem filtro',
                        icon: Icons.close_rounded,
                        active: false,
                        isDark: isDark,
                        pillBg: isDark
                            ? const Color(0xFF2D1515)
                            : const Color(0xFFFFEBEB),
                        borderColor: isDark
                            ? const Color(0xFF5C2020)
                            : const Color(0xFFFFCDD2),
                        onTap: () =>
                            setModalState(() => tempRange = null),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterReason = tempReason;
                        _filterDateRange = tempRange;
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Aplicar Filtros',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  DateTime get _todayDate {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTimeRange get _last7Days => DateTimeRange(
      start: _todayDate.subtract(const Duration(days: 6)), end: _todayDate);

  DateTimeRange get _last30Days => DateTimeRange(
      start: _todayDate.subtract(const Duration(days: 29)), end: _todayDate);

  bool _isSameDayRange(DateTimeRange a, DateTimeRange b) =>
      _sameDay(a.start, b.start) && _sameDay(a.end, b.end);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Hoje';
    if (d == today.subtract(const Duration(days: 1))) return 'Ontem';
    return DateFormat('EEEE, d \'de\' MMMM', 'pt_BR').format(dt);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final movementsAsync = ref.watch(stockMovementsProvider);

    final bg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
    final textSub =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: ModernProfileAppBar(
        title: 'Histórico',
        subtitle: 'Registro completo de saídas',
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar CSV',
            onPressed: () {
              final movAsync = ref.read(stockMovementsProvider);
              movAsync.whenData((all) async {
                var filtered = all
                    .where((m) =>
                        m.type == MovementType.saida ||
                        m.type == MovementType.descarte)
                    .toList();
                if (_filterReason != null) {
                  filtered = filtered
                      .where((m) => m.reasonCode == _filterReason)
                      .toList();
                }
                if (_filterDateRange != null) {
                  final start = _filterDateRange!.start;
                  final end = DateTime(
                      _filterDateRange!.end.year,
                      _filterDateRange!.end.month,
                      _filterDateRange!.end.day,
                      23, 59, 59);
                  filtered = filtered
                      .where((m) =>
                          m.performedAt.isAfter(
                              start.subtract(const Duration(seconds: 1))) &&
                          m.performedAt.isBefore(
                              end.add(const Duration(seconds: 1))))
                      .toList();
                }
                if (_search.isNotEmpty) {
                  final q = _search.toLowerCase();
                  filtered = filtered
                      .where((m) =>
                          m.productName.toLowerCase().contains(q) ||
                          m.performedByName.toLowerCase().contains(q))
                      .toList();
                }
                await _exportCsv(context, filtered);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Header de stats ────────────────────────────────────────────────
          _buildHeader(isDark, textPrimary, textSub, cardBg, borderColor,
              movementsAsync),

            // ─── Search + Filtros ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        style: TextStyle(color: textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Buscar por produto ou responsável…',
                          hintStyle: TextStyle(color: textSub, fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: textSub, size: 20),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: textSub, size: 18),
                                  onPressed: () =>
                                      setState(() => _search = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Botão de Filtro
                  GestureDetector(
                    onTap: _showFilterModal,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _activeFilterCount > 0
                            ? const Color(0xFF7C3AED)
                            : cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _activeFilterCount > 0
                              ? const Color(0xFF7C3AED)
                              : borderColor,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: _activeFilterCount > 0
                                ? Colors.white
                                : textSub,
                            size: 20,
                          ),
                          if (_activeFilterCount > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF7C3AED),
                                      width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    '$_activeFilterCount',
                                    style: const TextStyle(
                                      color: Color(0xFF7C3AED),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Lista ─────────────────────────────────────────────────────
            Expanded(
              child: movementsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5)),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 52, color: textSub),
                      const SizedBox(height: 12),
                      Text('Erro ao carregar histórico',
                          style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(e.toString(),
                          style:
                              TextStyle(color: textSub, fontSize: 12),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
                data: (allMovements) {
                  // Filtra apenas saídas/descartes
                  var outputs = allMovements
                      .where((m) =>
                          m.type == MovementType.saida ||
                          m.type == MovementType.descarte)
                      .toList();

                  // Filtro de motivo
                  if (_filterReason != null) {
                    outputs = outputs
                        .where((m) => m.reasonCode == _filterReason)
                        .toList();
                  }

                  // Filtro de período
                  if (_filterDateRange != null) {
                    final start = _filterDateRange!.start;
                    final end = DateTime(_filterDateRange!.end.year,
                        _filterDateRange!.end.month, _filterDateRange!.end.day, 23, 59, 59);
                    outputs = outputs
                        .where((m) =>
                            m.performedAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
                            m.performedAt.isBefore(end.add(const Duration(seconds: 1))))
                        .toList();
                  }

                  // Filtro de texto
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    outputs = outputs
                        .where((m) =>
                            m.productName
                                .toLowerCase()
                                .contains(q) ||
                            m.performedByName
                                .toLowerCase()
                                .contains(q))
                        .toList();
                  }

                  if (outputs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 60, color: textSub),
                          const SizedBox(height: 14),
                          Text('Nenhuma saída encontrada',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                              'Tente ajustar os filtros ou aguarde\nnovas movimentações',
                              style: TextStyle(
                                  color: textSub, fontSize: 13),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }

                  // Agrupa por sessão (mesmo performedAt + performedBy)
                  final sessionMap =
                      <String, List<StockMovement>>{};
                  for (final m in outputs) {
                    final key =
                        '${m.performedAt.toIso8601String()}|${m.performedBy}';
                    sessionMap.putIfAbsent(key, () => []).add(m);
                  }
                  final sessions = sessionMap.values.toList()
                    ..sort((a, b) => b.first.performedAt
                        .compareTo(a.first.performedAt));

                  // Agrupa por dia
                  final dayMap =
                      <String, List<List<StockMovement>>>{};
                  for (final s in sessions) {
                    final day = _dayLabel(s.first.performedAt);
                    dayMap.putIfAbsent(day, () => []).add(s);
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      // Summary banner when filters active
                      if (_filterReason != null ||
                          _filterDateRange != null ||
                          _search.isNotEmpty)
                        _SummaryBanner(
                          movements: outputs,
                          textPrimary: textPrimary,
                          textSub: textSub,
                          cardBg: cardBg,
                          borderColor: borderColor,
                        ),
                      for (final entry in dayMap.entries) ...[
                        _DayDivider(
                            label: entry.key,
                            isDark: isDark,
                            textSub: textSub),
                        ...entry.value.map((s) => _SessionCard(
                              movements: s,
                              isDark: isDark,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              reasonColors: _reasonColors,
                              reasonLabels: _reasonLabels,
                              reasonIcons: _reasonIcons,
                              formatTime: _formatTime,
                            )),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildHeader(
    bool isDark,
    Color textPrimary,
    Color textSub,
    Color cardBg,
    Color borderColor,
    AsyncValue<List<StockMovement>> movementsAsync,
  ) {
    final today = DateTime.now();

    int totalToday = 0;
    int totalWeek = 0;
    int totalAll = 0;

    movementsAsync.whenData((all) {
      final outputs = all.where((m) =>
          m.type == MovementType.saida || m.type == MovementType.descarte);
      for (final m in outputs) {
        totalAll++;
        final d = m.performedAt;
        if (d.year == today.year &&
            d.month == today.month &&
            d.day == today.day) {
          totalToday++;
        }
        final weekAgo = today.subtract(const Duration(days: 7));
        if (d.isAfter(weekAgo)) totalWeek++;
      }
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.3 : 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Histórico de Saídas',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Registro completo de distribuições',
                    style: TextStyle(
                      color: Color(0xFFDDD6FE),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatBadge(
                  label: 'Hoje',
                  value: '$totalToday',
                  icon: Icons.today_rounded),
              const SizedBox(width: 10),
              _StatBadge(
                  label: '7 dias',
                  value: '$totalWeek',
                  icon: Icons.date_range_rounded),
              const SizedBox(width: 10),
              _StatBadge(
                  label: 'Total',
                  value: '$totalAll',
                  icon: Icons.all_inclusive_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stat badge no header ──────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBadge(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chips do modal de filtro ──────────────────────────────────────────────

class _ModalChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final bool isDark;
  final Color pillBg;
  final Color borderColor;
  final VoidCallback onTap;

  const _ModalChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.isDark,
    required this.pillBg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? activeColor : pillBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? activeColor : borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF374151)),
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool isDark;
  final Color pillBg;
  final Color borderColor;
  final VoidCallback onTap;

  const _DateRangeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.isDark,
    required this.pillBg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF4F46E5);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? activeColor : pillBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? activeColor : borderColor,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF374151)),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Separador de dia ──────────────────────────────────────────────────────

class _DayDivider extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color textSub;

  const _DayDivider(
      {required this.label,
      required this.isDark,
      required this.textSub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textSub,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de sessão ────────────────────────────────────────────────────────

class _SessionCard extends StatefulWidget {
  final List<StockMovement> movements;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Map<String, List<Color>> reasonColors;
  final Map<String, String> reasonLabels;
  final Map<String, IconData> reasonIcons;
  final String Function(DateTime) formatTime;

  const _SessionCard({
    required this.movements,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.reasonColors,
    required this.reasonLabels,
    required this.reasonIcons,
    required this.formatTime,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final first = widget.movements.first;
    final reasonKey = first.reasonCode ?? 'outro';
    final colors = widget.reasonColors[reasonKey] ?? widget.reasonColors['outro']!;
    final totalQty = widget.movements.fold<int>(0, (s, m) => s + m.quantity);
    final timeStr = widget.formatTime(first.performedAt);
    final firstName = first.performedByName.split(' ').first;
    final isDark = widget.isDark;
    final onCard = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final divColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);

    final preview = widget.movements.take(4).toList();
    final extra = widget.movements.length > 4 ? widget.movements.length - 4 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          // ── Barra colorida no topo ───────────────────────────────────
          Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
          ),

          // ── Conteúdo principal ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha 1: hora + responsável + total
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors[0].withValues(alpha: isDark ? 0.18 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: colors[0]),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: colors[0],
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 13, color: subColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              firstName,
                              style: TextStyle(color: subColor, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Badge total
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.borderColor),
                      ),
                      child: Text(
                        '$totalQty un',
                        style: TextStyle(
                          color: onCard,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Linha 2: pills dos primeiros 4 produtos
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...preview.map((m) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1F2937)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: widget.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_rounded,
                                  size: 11, color: colors[0]),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 110),
                                child: Text(
                                  m.productName,
                                  style: TextStyle(
                                    color: onCard,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colors[0].withValues(
                                      alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '×${m.quantity}',
                                  style: TextStyle(
                                    color: colors[0],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (extra > 0)
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: colors[0].withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+$extra mais',
                            style: TextStyle(
                              color: colors[0],
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Linha 3: expandir se tiver mais de 4
                if (widget.movements.length > 4) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                              size: 16, color: subColor),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _expanded ? 'Ocultar todos' : 'Ver todos ${widget.movements.length} produtos',
                          style: TextStyle(
                            color: subColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Lista expandida ──────────────────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, thickness: 1, color: divColor),
            ...widget.movements.skip(4).map((m) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colors[0].withValues(
                                  alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(Icons.inventory_2_rounded,
                                size: 15, color: colors[0]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m.productName,
                              style: TextStyle(
                                color: onCard,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors[0].withValues(
                                  alpha: isDark ? 0.18 : 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '×${m.quantity}',
                              style: TextStyle(
                                color: colors[0],
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: divColor),
                  ],
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Export CSV function ──────────────────────────────────────────────────

Future<void> _exportCsv(
    BuildContext context, List<StockMovement> movements) async {
  final buffer = StringBuffer();
  buffer.writeln('Data,Produto,Tipo,Motivo,Quantidade,Usuário,Observação');
  final fmt = DateFormat('dd/MM/yyyy HH:mm');
  for (final m in movements) {
    buffer.writeln([
      '"${fmt.format(m.performedAt)}"',
      '"${m.productName.replaceAll('"', '""')}"',
      '"${m.type.name}"',
      '"${m.reasonCode ?? ''}"',
      '${m.quantity}',
      '"${m.performedByName}"',
      '"${(m.activity ?? '').replaceAll('"', '""')}"',
    ].join(','));
  }
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/historico_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(buffer.toString());
  await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Histórico EducaStock');
  if (!context.mounted) return;
  showCasaSnackbar(context, message: 'CSV exportado!', isSuccess: true);
}

// ─── Summary banner ───────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final List<StockMovement> movements;
  final Color textPrimary;
  final Color textSub;
  final Color cardBg;
  final Color borderColor;

  const _SummaryBanner({
    required this.movements,
    required this.textPrimary,
    required this.textSub,
    required this.cardBg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final totalMoves = movements.length;
    final totalEntrada = movements
        .where((m) => m.type == MovementType.entrada)
        .fold<int>(0, (sum, m) => sum + m.quantity);
    final totalSaida = movements
        .where((m) => m.type == MovementType.saida)
        .fold<int>(0, (sum, m) => sum + m.quantity);
    final totalDescarte =
        movements.where((m) => m.type == MovementType.descarte).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryMini(
              label: 'Registros',
              value: '$totalMoves',
              icon: Icons.list_rounded,
              color: AppColors.brandPrimary600,
              textPrimary: textPrimary,
              textSub: textSub,
            ),
            _SummaryMini(
              label: 'Entradas',
              value: '$totalEntrada un.',
              icon: Icons.add_circle_outline_rounded,
              color: AppColors.success600,
              textPrimary: textPrimary,
              textSub: textSub,
            ),
            _SummaryMini(
              label: 'Saídas',
              value: '$totalSaida un.',
              icon: Icons.outbound_rounded,
              color: AppColors.secondaryBlue600,
              textPrimary: textPrimary,
              textSub: textSub,
            ),
            _SummaryMini(
              label: 'Descartes',
              value: '$totalDescarte',
              icon: Icons.delete_outline_rounded,
              color: AppColors.danger600,
              textPrimary: textPrimary,
              textSub: textSub,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color textPrimary;
  final Color textSub;

  const _SummaryMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.textPrimary,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text(label,
                    style: TextStyle(color: textSub, fontSize: 10)),
              ],
            ),
          ],
        ),
      );
}
