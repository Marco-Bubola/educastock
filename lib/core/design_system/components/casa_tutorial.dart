import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

// Re-export tutorial_coach_mark types for use in design_system
export 'package:tutorial_coach_mark/tutorial_coach_mark.dart'
    show ShapeLightFocus, ContentAlign, TargetFocus, TargetContent, TutorialCoachMark;

/// Global flag — true while a coach-mark overlay is active.
/// AppBars and TabBars watch this to hide themselves during tutorials.
final ValueNotifier<bool> tutorialActiveNotifier = ValueNotifier<bool>(false);

// Design constants — fully explicit, no theme/MediaQuery dependency
const _kBorder = Color(0xFF1D5FA8);
const _kSkyBlue = Color(0xFF38BDF8);
const _kSkyBlueSoft = Color(0xFF7DD3FC);
const _kTextHigh = Colors.white;
const _kTextMid = Color(0xCCFFFFFF);   // 80% white
const _kTextLow = Color(0x80FFFFFF);   // 50% white
const _kCardRadius = 22.0;
const _kCardWidth = 328.0;

class TutorialStep {
  final GlobalKey key;
  final String title;
  final String description;
  final IconData icon;
  final ShapeLightFocus shape;
  final ContentAlign align;
  final double verticalOffset;
  final double paddingFocus;
  /// Optional bullet-point hints shown below the main description
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

void showCasaTutorial({
  required BuildContext context,
  required List<TutorialStep> steps,
  VoidCallback? onFinish,
  VoidCallback? onSkip,
}) {
  if (steps.isEmpty) return;
  tutorialActiveNotifier.value = true;

  // Scroll to a step's target widget before showing it.
  // Uses `alignmentPolicy: explicit` so it ALWAYS repositions to the top
  // even if the element is already partially visible.
  Future<void> scrollTo(int index) async {
    if (index < 0 || index >= steps.length) return;
    final ctx = steps[index].key.currentContext;
    if (ctx == null) return;
    try {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
        alignment: 0.05,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      // Extra buffer so the scroll settles before coach mark repositions
      await Future<void>.delayed(const Duration(milliseconds: 120));
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
          // Wrap in Material+Directionality so no ancestor is needed
          builder: (ctx, controller) => Material(
            type: MaterialType.transparency,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Transform.translate(
                offset: Offset(0, step.verticalOffset),
                child: _TutorialCard(
                  step: step,
                  stepIndex: i,
                  totalSteps: steps.length,
                  onNext: () {
                    handleNext(controller, i + 1);
                  },
                  onPrevious: i > 0
                      ? () {
                          handlePrevious(controller, i - 1);
                        }
                      : null,
                  onSkip: () {
                    controller.skip();
                    onSkip?.call();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }).toList();

  final coachMark = TutorialCoachMark(
    targets: targets,
    colorShadow: const Color(0xFF050D1A),
    opacityShadow: 0.92,
    hideSkip: true,
    focusAnimationDuration: const Duration(milliseconds: 350),
    unFocusAnimationDuration: const Duration(milliseconds: 220),
    pulseAnimationDuration: const Duration(milliseconds: 900),
    pulseEnable: true,
    onFinish: () {
      tutorialActiveNotifier.value = false;
      onFinish?.call();
    },
    onSkip: () {
      tutorialActiveNotifier.value = false;
      onSkip?.call();
      return true;
    },
  );

  // Scroll to step 0 first, then show the tutorial
  scrollTo(0).then((_) => coachMark.show(context: context));
}

// ─────────────────────────────────────────────────────────────────────────────
// Card widget – fully self-contained, zero external dependencies
// ─────────────────────────────────────────────────────────────────────────────
class _TutorialCard extends StatelessWidget {
  final TutorialStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onSkip;

  const _TutorialCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex == totalSteps - 1;

    return SizedBox(
      width: _kCardWidth,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF060F1E), Color(0xFF0A1628), Color(0xFF0D1F3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(color: _kSkyBlue.withValues(alpha: 0.30), width: 1),
          boxShadow: [
            BoxShadow(
              color: _kSkyBlue.withValues(alpha: 0.20),
              blurRadius: 34,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Faixa topo com gradiente azul ──────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1D5FA8).withValues(alpha: 0.95),
                      const Color(0xFF0F3060).withValues(alpha: 0.85),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícone em círculo
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kSkyBlue.withValues(alpha: 0.15),
                        border: Border.all(
                          color: _kSkyBlue.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(step.icon, color: _kSkyBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _kTextHigh,
                              height: 1.2,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Barra de progresso
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: (stepIndex + 1) / totalSteps,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_kSkyBlue, _kSkyBlueSoft],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _kSkyBlue.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            '${stepIndex + 1}/$totalSteps',
                            style: TextStyle(
                              fontSize: 10,
                              color: _kSkyBlue.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onSkip,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close_rounded,
                                    size: 12, color: _kTextLow),
                                SizedBox(width: 4),
                                Text(
                                  'Pular',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _kTextLow,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Corpo ──────────────────────────────────────────────────────
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'O que fazer',
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          color: _kSkyBlue.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kTextMid,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (step.hints.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _kSkyBlue.withValues(alpha: 0.25),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dicas rápidas',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                            color: _kSkyBlue.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...step.hints.map(
                          (h) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 5, right: 8),
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _kSkyBlue,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    h,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _kTextMid,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
                // ── Navegação ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

                child: Row(
                  children: [
                    if (onPrevious != null)
                      _NavBtn(
                        label: 'Anterior',
                        icon: Icons.arrow_back_ios_new_rounded,
                        isPrimary: false,
                        onTap: onPrevious!,
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    _NavBtn(
                      label: isLast ? '✓ Concluir' : 'Próximo',
                      icon: isLast ? null : Icons.arrow_forward_ios_rounded,
                      isPrimary: true,
                      onTap: onNext,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NavBtn({
    required this.label,
    required this.isPrimary,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF1D5FA8), Color(0xFF38BDF8)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : _kBorder.withValues(alpha: 0.55),
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: _kSkyBlue.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPrimary && icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(icon, size: 12, color: _kSkyBlue),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPrimary ? _kTextHigh : _kSkyBlue,
              ),
            ),
            if (isPrimary && icon != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(icon, size: 12, color: _kTextHigh),
              ),
          ],
        ),
      ),
    );
  }
}
