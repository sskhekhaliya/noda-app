import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../core/theme/app_typography.dart';
import '../core/theme/app_theme.dart';
import '../providers/study_provider.dart';
import '../widgets/common/noda_markdown.dart';
import '../providers/settings_provider.dart';
import '../providers/tts_provider.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  String? _exitTrigger; // 'left', 'right', or null
  bool _hasSpokenInitial = false;

  @override
  void initState() {
    super.initState();
    // Start initial speech after mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      final state = ref.read(studyProvider);
      if (settings.autoplayTts && state.currentCard != null && !_hasSpokenInitial) {
        _hasSpokenInitial = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && ref.read(settingsProvider).autoplayTts) {
            ref.read(ttsProvider.notifier).speak(state.currentCard!.front);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyProvider);
    final notifier = ref.read(studyProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final tts = ref.watch(ttsProvider);

    // Autoplay TTS - New Card (Front)
    ref.listen(studyProvider, (previous, next) {
      if (next.currentCard != null && next.currentCard?.id != (previous?.currentCard?.id)) {
        ref.read(ttsProvider.notifier).stop();
        if (settings.autoplayTts) {
          ref.read(ttsProvider.notifier).speak(next.currentCard!.front);
        }
      }
    });

    // Autoplay TTS - Flip (Back)
    ref.listen(studyProvider.select((s) => s.isFlipped), (previous, next) {
      if (next == true && state.currentCard != null) {
        ref.read(ttsProvider.notifier).stop();
        if (settings.autoplayTts) {
          ref.read(ttsProvider.notifier).speak(state.currentCard!.back);
        }
      } else if (next == false) {
        ref.read(ttsProvider.notifier).stop();
      }
    });

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(ttsProvider.notifier).stop();
            Navigator.pop(context);
          },
        ),
        title: Text(state.parentTitle, style: AppTypography.headingSmall()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              settings.autoplayTts ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: settings.autoplayTts ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            tooltip: settings.autoplayTts ? 'Turn Sound Off' : 'Turn Sound On',
            onPressed: () {
              ref.read(settingsProvider.notifier).setAutoplayTts(!settings.autoplayTts);
              if (!settings.autoplayTts && state.currentCard != null) {
                ref.read(ttsProvider.notifier).speak(state.currentCard!.front);
              } else if (settings.autoplayTts) {
                ref.read(ttsProvider.notifier).stop();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                      ),
                      child: child,
                    ),
                  );
                },
                child: state.isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : state.currentCard == null
                        ? _DoneScreen(
                            onClose: () => Navigator.pop(context),
                            onRetake: () {
                              if (state.startNodeId == 'GLOBAL') {
                                notifier.startGlobalSession();
                              } else {
                                notifier.startSession(
                                  state.startNodeId,
                                  state.parentTitle,
                                  isShuffle: state.isShuffle,
                                );
                              }
                            },
                          )
                    : _SwipableCard(
                        key: ValueKey((state.currentCard?.id ?? "")),
                        isFlipped: state.isFlipped,
                        exitTrigger: _exitTrigger,
                        topicName: state.nodeTitles[(state.currentCard?.parentId ?? "")] ?? '',
                        score: (state.currentCard?.score ?? 0),
                        front: _CardSide(
                          content: (state.currentCard?.front ?? ""),
                          topicName: state.nodeTitles[(state.currentCard?.parentId ?? "")] ?? '',
                          score: (state.currentCard?.score ?? 0),
                          isBack: false,
                          color: colorScheme.surfaceContainerLowest,
                        ),
                        back: _CardSide(
                          content: (state.currentCard?.back ?? ""),
                          topicName: state.nodeTitles[(state.currentCard?.parentId ?? "")] ?? '',
                          score: (state.currentCard?.score ?? 0),
                          isBack: true,
                          color: colorScheme.surfaceContainerHigh,
                        ),
                        onFlip: notifier.flip,
                        onSwipeLeft: () {
                          ref.read(ttsProvider.notifier).stop();
                          setState(() => _exitTrigger = null);
                          notifier.vote(false);
                        },
                        onSwipeRight: () {
                          ref.read(ttsProvider.notifier).stop();
                          setState(() => _exitTrigger = null);
                          notifier.vote(true);
                        },
                      ),
              ),
            ),
            if (state.currentCard != null) ...[
              const SizedBox(height: 48),
              AnimatedCrossFade(
                firstChild: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: notifier.flip,
                    icon: const Icon(Icons.flip_camera_android_rounded),
                    label: const Text('FLIP CARD'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                secondChild: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _VoteButton(
                            onPressed: () => setState(() => _exitTrigger = 'left'),
                            label: 'REPEAT',
                            icon: Icons.arrow_back_rounded,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _VoteButton(
                            onPressed: () => setState(() => _exitTrigger = 'right'),
                            label: 'MASTER',
                            icon: Icons.arrow_forward_rounded,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Swipe Right to Master • Left to Repeat',
                      style: AppTypography.caption(
                        color: Theme.of(context).extension<NodaThemeExtension>()?.textSecondary ?? Colors.grey,
                      ),
                    ),
                  ],
                ),
                crossFadeState: state.isFlipped ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoneScreen extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onRetake;

  const _DoneScreen({required this.onClose, required this.onRetake});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 64, color: colorScheme.primary),
            ),
            const SizedBox(height: 32),
            Text(
              'Mastery Achieved',
              style: AppTypography.headingLarge(),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ve synchronized your knowledge.',
              style: AppTypography.bodyMedium(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: onRetake,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                  child: const Text('RETAKE', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipableCard extends StatefulWidget {
  final bool isFlipped;
  final String? exitTrigger;
  final String topicName;
  final int score;
  final Widget front;
  final Widget back;
  final VoidCallback onFlip;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const _SwipableCard({
    super.key,
    required this.isFlipped,
    this.exitTrigger,
    required this.topicName,
    required this.score,
    required this.front,
    required this.back,
    required this.onFlip,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<_SwipableCard> createState() => _SwipableCardState();
}

class _SwipableCardState extends State<_SwipableCard> with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  double _dragOffset = 0;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _swipeAnimation = Tween<double>(begin: 0, end: 0).animate(_swipeController);
  }

  @override
  void didUpdateWidget(_SwipableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exitTrigger != null && widget.exitTrigger != oldWidget.exitTrigger) {
      _runExitAnimation(widget.exitTrigger == 'right');
    }
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _runExitAnimation(bool isRight) {
    if (_isExiting) return;
    setState(() => _isExiting = true);
    
    final target = isRight ? 600.0 : -600.0;
    _swipeAnimation = Tween<double>(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeInQuint));
    
    _swipeController.forward().then((_) {
      if (isRight) {
        widget.onSwipeRight();
      } else {
        widget.onSwipeLeft();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _swipeAnimation,
      builder: (context, child) {
        final currentOffset = _isExiting ? _swipeAnimation.value : _dragOffset;
        final rotation = (currentOffset / 20) * (math.pi / 180); // Slight rotation while swiping

        return GestureDetector(
          onTap: _isExiting ? null : widget.onFlip,
          onHorizontalDragUpdate: (details) {
            if (!widget.isFlipped || _isExiting) return;
            setState(() => _dragOffset += details.delta.dx);
          },
          onHorizontalDragEnd: (details) {
            if (!widget.isFlipped || _isExiting) return;
            if (_dragOffset > 100) {
              _runExitAnimation(true);
            } else if (_dragOffset < -100) {
              _runExitAnimation(false);
            } else {
              setState(() => _dragOffset = 0);
            }
          },
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: widget.isFlipped ? 180 : 0),
            duration: const Duration(milliseconds: 400),
            builder: (context, double val, child) {
              final isBack = val > 90;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..setTranslationRaw(currentOffset, 0.0, 0.0)
                  ..rotateZ(rotation)
                  ..rotateY(val * math.pi / 180),
                child: isBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: widget.back,
                      )
                    : widget.front,
              );
            },
          ),
        );
      },
    );
  }
}

class _CardSide extends StatelessWidget {
  final String content;
  final String topicName;
  final int score;
  final bool isBack;
  final Color color;

  const _CardSide({
    required this.content,
    required this.topicName,
    required this.score,
    required this.isBack,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Topic name at top
          Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    topicName.toUpperCase(),
                    style: AppTypography.caption(
                      color: colorScheme.primary,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                Text(
                  score >= 50 ? 'MASTERED' : 'SCORE: $score',
                  style: AppTypography.caption(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  ).copyWith(
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
              child: SingleChildScrollView(
                child: NodaMarkdown(
                  data: content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final Color color;

  const _VoteButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        side: BorderSide(color: color.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        foregroundColor: color,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }
}





