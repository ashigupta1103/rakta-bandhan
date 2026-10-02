import 'package:flutter/material.dart';

import '../demo/demo.dart';
import '../services/backend.dart';
import '../services/usernames.dart';
import '../widgets/username_field.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

/// Existing members choose a name once; My Page uses the same editor later.
class UsernameScreen extends StatefulWidget {
  final String? currentUsername;
  final DateTime? changedAt;
  final bool requiredChoice;
  const UsernameScreen({super.key, this.currentUsername, this.changedAt, this.requiredChoice = false});
  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  late final _name = TextEditingController(text: widget.currentUsername ?? '');
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final invalid = validateUsername(name);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (Demo.on) {
        demoUsername = name;
      } else {
        await Backend.instance.changeUsername(name);
      }
      if (!mounted) return;
      if (widget.requiredChoice) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (_) => false);
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = Backend.authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = usernameChangeAllowedAt(widget.changedAt);
    final locked = allowed != null && allowed.isAfter(DateTime.now());
    return PopScope(
      canPop: !widget.requiredChoice,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.requiredChoice ? 'Choose your username' : 'Your username'),
          automaticallyImplyLeading: !widget.requiredChoice,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Your @username is visible to signed-in members on posts and chats. You can change it once every 30 days.'),
            const SizedBox(height: 24),
            UsernameField(controller: _name, currentUsername: widget.currentUsername),
            if (locked) Text('You can change it again on ${allowed.day}/${allowed.month}/${allowed.year}.'),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _saving || locked ? null : _save, child: Text(_saving ? 'Saving…' : 'Save username')),
            if (widget.requiredChoice)
              TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        await Backend.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                        }
                      },
                child: const Text('Sign out'),
              ),
            if (widget.requiredChoice) TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())), child: const Text('Account settings')),
          ],
        ),
      ),
    );
  }
}
