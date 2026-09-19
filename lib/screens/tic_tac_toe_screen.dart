import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// "Play a round of XO" — the Cooldown screen's "while you wait" entry per
/// the final artifact: "A small thing to pass the time. Nothing to win."
/// A plain local two-player-on-one-device tic-tac-toe — no score is kept,
/// nothing is saved, nothing touches Firestore. The design names the game
/// by its universally-understood rules and explicitly frames it as
/// decorative, not a scored feature, so no leaderboard or win-streak is
/// added here.
class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  List<String?> _board = List.filled(9, null);
  bool _xTurn = true;
  List<int>? _winningLine;

  static const _lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  String? get _winner {
    for (final line in _lines) {
      final a = _board[line[0]], b = _board[line[1]], c = _board[line[2]];
      if (a != null && a == b && b == c) {
        _winningLine = line;
        return a;
      }
    }
    return null;
  }

  bool get _isDraw => _board.every((c) => c != null) && _winner == null;

  void _tap(int index) {
    if (_board[index] != null || _winner != null) return;
    setState(() => _board[index] = _xTurn ? 'X' : 'O');
    _xTurn = !_xTurn;
  }

  void _reset() {
    setState(() {
      _board = List.filled(9, null);
      _xTurn = true;
      _winningLine = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final winner = _winner;
    final draw = _isDraw;
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm), onPressed: () => Navigator.pop(context)),
                  const Text('A round of XO', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        winner != null ? '$winner wins' : (draw ? "It's a draw" : (_xTurn ? "X's turn" : "O's turn")),
                        style: AppTextStyles.display(fontSize: 22, color: AppColors.ink),
                      ),
                      const SizedBox(height: 6),
                      const Text('A small thing to pass the time. Nothing to win.', style: TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                      const SizedBox(height: 24),
                      AspectRatio(
                        aspectRatio: 1,
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 9,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                          itemBuilder: (context, i) {
                            final mark = _board[i];
                            final isWinning = _winningLine?.contains(i) ?? false;
                            return GestureDetector(
                              onTap: () => _tap(i),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isWinning ? AppColors.goldTint : Colors.white,
                                  border: Border.all(color: AppColors.warmBorder),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  mark ?? '',
                                  style: AppTextStyles.display(fontSize: 36, color: mark == 'X' ? AppColors.brandRed : AppColors.goldDeep),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(onPressed: _reset, child: const Text('Play again')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
