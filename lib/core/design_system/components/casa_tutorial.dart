import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// Re-export tutorial_coach_mark types for use in design_system
export 'package:tutorial_coach_mark/tutorial_coach_mark.dart'
    show ShapeLightFocus, ContentAlign, TargetFocus, TargetContent, TutorialCoachMark;

/// Global flag — true while a coach-mark overlay is active.
/// AppBars and TabBars watch this to hide themselves during tutorials.
final ValueNotifier<bool> tutorialActiveNotifier = ValueNotifier<bool>(false);

// ─── Design tokens ──────────────────────────────────────────────────────────
const _kSkyBlue = Color(0xFF38BDF8);
const _kSkyBlueSoft = Color(0xFF7DD3FC);
const _kPurple = Color(0xFFA78BFA);
const _kGold = Color(0xFFFBBF24);
const _kTextHigh = Colors.white;
const _kTextMid = Color(0xE6FFFFFF); // 90% white
const _kTextLow = Color(0x99FFFFFF); // 60% white

class TutorialStep {
  final GlobalKey key;
  final String title;
  final String description;
  final IconData icon;
  final ShapeLightFocus shape;
  final ContentAlign align;
  final double verticalOffset;
  final double paddingFocus;
  final List<String> hints;

  const TutorialStep({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    this.shape = ShapeLightFocus.RRect,
    this.align = ContentAlign.bottom,
    this.verticalOffset = 0,
    this.paddingFocus = 8.0,
    this.hints = const [],
  });
}

// ─── Estado da barra inferior (compartilhado com OverlayEntry) ──────────────
class _BarState {
  final int stepIndex;
  final int totalSteps;
  final IconData stepIcon;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  const _BarState({
    required this.stepIndex,
    required this.totalSteps,
    required this.stepIcon,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
  });
}

final ValueNotifier<_BarState?> _barStateNotifier = ValueNotifier<_BarState?>(null);

void showCasaTutorial({
  required BuildContext context,
  required List<TutorialStep> steps,
  VoidCallback? onFinish,
  VoidCallback? onSkip,
}) {
  if (steps.isEmpty) return;
  tutorialActiveNotifier.value = true;

  Future<void> scrollTo(int index) async {
    if (index < 0 || index >= steps.length) return;
    final ctx = steps[index].key.currentContext;
    if (ctx == null) return;
    try {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
        alignment: 0.20, // posiciona o alvo na parte superior da tela
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      await Future<void>.delayed(const Duration(milliseconds: 140));
    } catch (_) {}
  }

  bool isTransitioning = false;

  Future<void> handleNext(TutorialCoachMarkController ctrl, int nextIndex) async {
    if (isTransitioning) return;
    isTransitioning = true;
    await scrollTo(nextIndex);
    isTransitioning = false;
    ctrl.next();
  }

  Future<void> handlePrevious(TutorialCoachMarkController ctrl, int prevIndex) async {
    if (isTransitioning) return;
    isTransitioning = true;
    await scrollTo(prevIndex);
    isTransitioning = false;
    ctrl.previous();
  }

  // OverlayEntry reference (assinado depois)
  OverlayEntry? bottomBarEntry;

  void cleanupOverlay() {
    bottomBarEntry?.remove();
    bottomBarEntry = null;
    _barStateNotifier.value = null;
  }

  final targets = steps.asMap().entries.map((entry) {
    final i = entry.key;
    final step = entry.value;
    return TargetFocus(
      keyTarget: step.key,
      shape: step.shape,
      paddingFocus: step.paddingFocus,
      enableOverlayTab: false,
      enableTargetTab: false,
      contents: [
        TargetContent(
          align: step.align,
          builder: (ctx, controller) {
            // Sincroniza o estado dos botões com o step atual
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _barStateNotifier.value = _BarState(
                stepIndex: i,
                totalSteps: steps.length,
                stepIcon: step.icon,
                onPrevious: i > 0
                    ? () => handlePrevious(controller, i - 1)
                    : null,
                onNext: () => handleNext(controller, i + 1),
                onSkip: () {
                  cleanupOverlay();
                  controller.skip();
                  onSkip?.call();
                },
                isLast: i == steps.length - 1,
              );
            });
            return Material(
              type: MaterialType.transparency,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Transform.translate(
                  offset: Offset(0, step.verticalOffset),
                  child: _TutorialContent(step: step),
                ),
              ),
            );
          },
        ),
      ],
    );
  }).toList();

  final coachMark = TutorialCoachMark(
    targets: targets,
    colorShadow: const Color(0xFF050B17),
    opacityShadow: 0.94,
    hideSkip: true,
    focusAnimationDuration: const Duration(milliseconds: 380),
    unFocusAnimationDuration: const Duration(milliseconds: 240),
    pulseAnimationDuration: const Duration(milliseconds: 900),
    pulseEnable: true,
    onFinish: () {
      cleanupOverlay();
      tutorialActiveNotifier.value = false;
      onFinish?.call();
    },
    onSkip: () {
      cleanupOverlay();
      tutorialActiveNotifier.value = false;
      return true;
    },
  );

  // Scroll para o primeiro alvo, depois mostra o tutorial e insere a barra fixa
  scrollTo(0).then((_) {
    if (!context.mounted) return;
    coachMark.show(context: context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      bottomBarEntry = OverlayEntry(
        builder: (_) => const _FixedBottomBar(),
      );
      Overlay.of(context, rootOverlay: true).insert(bottomBarEntry!);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// Conteúdo flutuante por step — SEM CARD, elementos "voando"
// ═══════════════════════════════════════════════════════════════════════════
class _TutorialContent extends StatefulWidget {
  final TutorialStep step;
  const _TutorialContent({required this.step});

  @override
  State<_TutorialContent> createState() => _TutorialContentState();
}

class _TutorialContentState extends State<_TutorialContent>
    with TickerProviderStateMixin {
  late final AnimationController _entryAnim;
  late final AnimationController _iconPulse;

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _iconPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    _iconPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = (screenWidth - 24).clamp(280.0, 460.0);

    return SizedBox(
      width: maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ícone flutuante com pulse + glow ─────────────────────────
          AnimatedBuilder(
            animation: _iconPulse,
            builder: (_, __) {
              final t = _iconPulse.value;
              final pulseScale = 1.0 + t * 0.08;
              return Center(
                child: _FloatingEntry(
                  anim: _entryAnim,
                  delay: 0,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kSkyBlue.withValues(alpha: 0.35),
                          _kSkyBlue.withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: _kSkyBlue.withValues(alpha: 0.70),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kSkyBlue.withValues(alpha: 0.40 + 0.15 * t),
                          blurRadius: 20 + 10 * t,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Transform.scale(
                      scale: pulseScale,
                      child: Icon(widget.step.icon, color: _kSkyBlueSoft, size: 30),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // ── Título grande, sem fundo ─────────────────────────────────
          _FloatingEntry(
            anim: _entryAnim,
            delay: 0.08,
            child: Text(
              widget.step.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _kTextHigh,
                height: 1.15,
                letterSpacing: -0.5,
                shadows: [
                  Shadow(
                    color: Color(0xCC000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Descrição com label "COMO USAR" ─────────────────────────
          _FloatingEntry(
            anim: _entryAnim,
            delay: 0.16,
            child: _SectionLabel(
              label: 'COMO USAR',
              color: _kSkyBlue,
            ),
          ),
          const SizedBox(height: 8),
          _FloatingEntry(
            anim: _entryAnim,
            delay: 0.20,
            child: Text(
              widget.step.description,
              style: const TextStyle(
                fontSize: 14,
                color: _kTextMid,
                height: 1.55,
                fontWeight: FontWeight.w400,
                shadows: [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),

          // ── Dicas flutuantes com mini ícones ────────────────────────
          if (widget.step.hints.isNotEmpty) ...[
            const SizedBox(height: 18),
            _FloatingEntry(
              anim: _entryAnim,
              delay: 0.28,
              child: _SectionLabel(
                label: 'DICAS RÁPIDAS',
                color: _kPurple,
              ),
            ),
            const SizedBox(height: 10),
            ...widget.step.hints.asMap().entries.map((e) {
              final idx = e.key;
              final hint = e.value;
              return _FloatingEntry(
                anim: _entryAnim,
                delay: 0.34 + idx * 0.06,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HintPill(text: hint),
                ),
              );
            }),
          ],

          // Espaço pra não colidir com a barra de botões fixa
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Mini-widgets — section labels, hints, animação de entrada
// ═══════════════════════════════════════════════════════════════════════════

class _FloatingEntry extends StatelessWidget {
  final AnimationController anim;
  final double delay;
  final Widget child;

  const _FloatingEntry({
    required this.anim,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) {
        final raw = (anim.value - delay).clamp(0.0, 1.0);
        final t = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            color: color,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HintPill extends StatelessWidget {
  final String text;
  const _HintPill({required this.text});

  @override
  Widget build(BuildContext context) {
    // Detecta se o texto começa com emoji (heurística: primeiro char fora do ASCII básico)
    final hasEmoji = text.isNotEmpty && text.runes.first > 0x2300;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _kPurple.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasEmoji) ...[
            Container(
              margin: const EdgeInsets.only(top: 5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPurple,
                boxShadow: [
                  BoxShadow(
                    color: _kPurple.withValues(alpha: 0.7),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextHigh,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Barra fixa no rodapé — sempre visível, sobre o backdrop do coach mark
// ═══════════════════════════════════════════════════════════════════════════

class _FixedBottomBar extends StatelessWidget {
  const _FixedBottomBar();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ValueListenableBuilder<_BarState?>(
        valueListenable: _barStateNotifier,
        builder: (_, state, __) {
          if (state == null) return const SizedBox.shrink();
          return Material(
            type: MaterialType.transparency,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: _BottomBarContent(state: state),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BottomBarContent extends StatelessWidget {
  final _BarState state;
  const _BottomBarContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xE60A1428),
            Color(0xE60D1F3D),
            Color(0xE60F2B52),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _kSkyBlue.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _kSkyBlue.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Barra superior: contador + dots de progresso + pular ──
          Row(
            children: [
              // Contador estilo "level X / Y"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _kSkyBlue.withValues(alpha: 0.20),
                      _kSkyBlue.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _kSkyBlue.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(state.stepIcon, size: 12, color: _kSkyBlueSoft),
                    const SizedBox(width: 5),
                    Text(
                      '${state.stepIndex + 1} / ${state.totalSteps}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kTextHigh,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Dots de progresso
              Expanded(
                child: Row(
                  children: List.generate(state.totalSteps, (i) {
                    final done = i <= state.stepIndex;
                    final current = i == state.stepIndex;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                            right: i < state.totalSteps - 1 ? 4 : 0),
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: done
                              ? const LinearGradient(
                                  colors: [_kSkyBlue, _kSkyBlueSoft])
                              : null,
                          color: done
                              ? null
                              : Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: current
                              ? [
                                  BoxShadow(
                                    color: _kSkyBlue.withValues(alpha: 0.7),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 10),
              // Botão Pular
              GestureDetector(
                onTap: state.onSkip,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 12, color: _kTextLow),
                      SizedBox(width: 4),
                      Text(
                        'Fechar',
                        style: TextStyle(
                          fontSize: 11,
                          color: _kTextLow,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Barra inferior: Anterior + Próximo ─────────────────────
          Row(
            children: [
              if (state.onPrevious != null)
                Expanded(
                  child: _ActionBtn(
                    label: 'Anterior',
                    icon: Icons.arrow_back_ios_new_rounded,
                    isPrimary: false,
                    onTap: state.onPrevious!,
                  ),
                )
              else
                const Spacer(),
              if (state.onPrevious != null) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _ActionBtn(
                  label: state.isLast ? 'Concluir' : 'Próximo',
                  icon: state.isLast
                      ? Icons.check_rounded
                      : Icons.arrow_forward_ios_rounded,
                  isPrimary: true,
                  iconRight: !state.isLast,
                  onTap: state.onNext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final bool iconRight;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
    this.iconRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF1D5FA8), _kSkyBlue, _kGold],
                  stops: [0.0, 0.6, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? Colors.white.withValues(alpha: 0.20)
                : _kSkyBlue.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: _kSkyBlue.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!iconRight)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  icon,
                  size: 14,
                  color: isPrimary ? _kTextHigh : _kSkyBlueSoft,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isPrimary ? _kTextHigh : _kSkyBlueSoft,
                letterSpacing: 0.2,
              ),
            ),
            if (iconRight)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  icon,
                  size: 14,
                  color: isPrimary ? _kTextHigh : _kSkyBlueSoft,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
