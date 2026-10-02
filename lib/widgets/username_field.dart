import 'dart:async';

import 'package:flutter/material.dart';

import '../demo/demo.dart';
import '../services/backend.dart';
import '../services/usernames.dart';

class UsernameField extends StatefulWidget {
  final TextEditingController controller;
  final String? currentUsername;
  const UsernameField({super.key, required this.controller, this.currentUsername});

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  Timer? _timer;
  String? _status;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  void _changed() {
    _timer?.cancel();
    final value = widget.controller.text.trim();
    final invalid = validateUsername(value);
    setState(() {
      _status = value.isEmpty ? null : invalid ?? 'Checking availability…';
      _error = invalid != null;
    });
    if (invalid != null) return;
    _timer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final available = value == widget.currentUsername || Demo.on || await Backend.instance.usernameAvailable(value);
        if (!mounted || widget.controller.text.trim() != value) return;
        setState(() {
          _status = available ? 'Available' : 'Already taken. Choose another.';
          _error = !available;
        });
      } catch (_) {
        if (mounted && widget.controller.text.trim() == value) {
          setState(() {
            _status = 'Could not check availability. Try again when connected.';
            _error = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    autocorrect: false,
    textCapitalization: TextCapitalization.none,
    maxLength: 20,
    decoration: InputDecoration(
      labelText: 'Username',
      prefixText: '@',
      helperText: _error ? null : _status ?? '3–20 lowercase letters, numbers or _. Start with a letter.',
      helperMaxLines: 2,
      errorText: _error ? _status : null,
      errorMaxLines: 2,
    ),
  );
}
