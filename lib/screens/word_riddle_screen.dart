import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/rb_icon.dart';
import '../widgets/rb_ui.dart';

/// A short word-riddle game for the 90-day recovery period: six stages,
/// each a little harder, all about blood, giving and community. Optional,
/// offline, and nothing to win — no points, streaks or rewards.
class WordRiddleScreen extends StatefulWidget {
  const WordRiddleScreen({super.key});

  @override
  State<WordRiddleScreen> createState() => _WordRiddleScreenState();
}

typedef _Riddle = ({String clue, String answer, String afterword});

class _WordRiddleScreenState extends State<WordRiddleScreen> {
  static const List<_Riddle> _stages = [
    (clue: 'I run through every one of us, and one person can share me with another. What am I?', answer: 'BLOOD', afterword: 'One donation can help someone through surgery, an accident or childbirth.'),
    (clue: 'I give without being asked twice, and I roll up my sleeve to do it.', answer: 'DONOR', afterword: 'Every name in Rakta Bandhan’s donor list chose to be here.'),
    (clue: '“Rakta” means blood. “Bandhan” means the thing that ties people together.', answer: 'BOND', afterword: 'Rakta Bandhan — a bond made of blood.'),
    (clue: 'I’m the pale-gold liquid part of blood, carrying the cells along.', answer: 'PLASMA', afterword: 'It makes up a little over half of your blood.'),
    (clue: 'Red cells pick me up in the lungs and deliver me everywhere else.', answer: 'OXYGEN', afterword: 'That delivery job is what red cells are for.'),
    (clue: 'Many people, one purpose — strangers who look after each other.', answer: 'COMMUNITY', afterword: 'That’s what every match on Rakta Bandhan is.'),
  ];

  int _stage = 0;
  int _revealed = 0;
  bool _solved = false;
  bool _wrong = false;
  final _input = TextEditingController();
  final _focus = FocusNode();

  _Riddle get _r => _stages[_stage];
  bool get _finished => _stage >= _stages.length;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _check() {
    if (_input.text.toUpperCase() == _r.answer) {
      HapticFeedback.lightImpact();
      setState(() {
        _solved = true;
        _wrong = false;
      });
      _focus.unfocus();
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _wrong = true);
    }
  }

  void _hint() {
    if (_revealed >= _r.answer.length - 1) return;
    setState(() {
      _revealed++;
      _wrong = false;
      final start = _r.answer.substring(0, _revealed);
      if (!_input.text.toUpperCase().startsWith(start)) _input.text = start;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    });
    _focus.requestFocus();
  }

  void _next() {
    setState(() {
      _stage++;
      _revealed = 0;
      _solved = false;
      _wrong = false;
      _input.clear();
    });
    if (!_finished) _focus.requestFocus();
  }

  void _restart() {
    setState(() {
      _stage = 0;
      _revealed = 0;
      _solved = false;
      _wrong = false;
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmPageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(tooltip: 'Back', icon: const RbIcon(RbGlyph.back, color: AppColors.ink), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Word riddles', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.ink)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          _progress(),
          const SizedBox(height: 18),
          if (_finished) _done() else _riddleCard(),
        ],
      ),
    );
  }

  Widget _progress() => Row(
        children: [
          for (var i = 0; i < _stages.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 5,
                decoration: BoxDecoration(
                  color: i < _stage || (i == _stage && _solved) ? AppColors.brandRed : (i == _stage ? AppColors.red300 : AppColors.warmBorder),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ],
      );

  Widget _riddleCard() {
    final len = _r.answer.length;
    return RbCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Stage ${_stage + 1} of ${_stages.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.goldDeep)),
          const SizedBox(height: 10),
          Text(_r.clue, style: AppTextStyles.display(fontSize: 20, color: AppColors.ink, height: 1.35)),
          const SizedBox(height: 20),
          _LetterSlots(
            controller: _input,
            focusNode: _focus,
            length: len,
            enabled: !_solved,
            wrong: _wrong,
            solved: _solved,
            onChanged: () => setState(() => _wrong = false),
            onSubmit: _check,
          ),
          const SizedBox(height: 8),
          Text(
            _solved ? 'Correct.' : (_wrong ? 'Not quite — try again, or take a hint.' : '$len letters'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _solved ? AppColors.successText : (_wrong ? AppColors.red700 : AppColors.ink2)),
          ),
          if (_solved) ...[
            const SizedBox(height: 10),
            Text(_r.afterword, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.45)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _next, child: Text(_stage == _stages.length - 1 ? 'Finish' : 'Next riddle')),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _revealed >= len - 1 ? null : _hint,
                    icon: const RbIcon(RbGlyph.eye, size: 16),
                    label: const Text('Hint'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: _input.text.length == len ? _check : null, child: const Text('Check'))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _done() => RbCard(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
        child: Column(
          children: [
            const RbIcon(RbGlyph.heart, size: 34, color: AppColors.brandRed),
            const SizedBox(height: 12),
            Text('All six solved', style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text('Thanks for spending a few minutes with us while you recover.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.45)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _restart, child: const Text('Play again'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.maybePop(context), child: const Text('Done'))),
              ],
            ),
          ],
        ),
      );
}

/// Letter boxes over one hidden text field (same approach as the sign-in
/// code boxes), letters only, upper-cased.
class _LetterSlots extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool enabled;
  final bool wrong;
  final bool solved;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  const _LetterSlots({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.enabled,
    required this.wrong,
    required this.solved,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? focusNode.requestFocus : null,
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            // Keep the real input in the semantics tree (screen readers).
            alwaysIncludeSemantics: true,
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')), LengthLimitingTextInputFormatter(length)],
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
          IgnorePointer(
            child: ListenableBuilder(
              listenable: Listenable.merge([controller, focusNode]),
              builder: (context, _) {
                final text = controller.text.toUpperCase();
                return LayoutBuilder(
                  builder: (context, box) {
                    final w = ((box.maxWidth - (length - 1) * 6) / length).clamp(22.0, 44.0);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: w,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: solved ? AppColors.successBg : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: solved
                                    ? AppColors.successText
                                    : wrong
                                        ? AppColors.brandRed
                                        : (focusNode.hasFocus && i == text.length.clamp(0, length - 1))
                                            ? AppColors.ink
                                            : AppColors.warmBorder,
                                width: focusNode.hasFocus && i == text.length.clamp(0, length - 1) ? 1.6 : 1,
                              ),
                            ),
                            child: Text(i < text.length ? text[i] : '', style: AppTextStyles.display(fontSize: 22, color: AppColors.ink)),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
