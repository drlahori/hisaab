import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lock.dart';

// ---------------- PIN pad ----------------

class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onComplete, this.length = 4});

  final ValueChanged<String> onComplete;
  final int length;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';

  void _tap(String d) {
    if (_digits.length >= widget.length) return;
    setState(() => _digits += d);
    if (_digits.length == widget.length) {
      final value = _digits;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _digits = '');
        widget.onComplete(value);
      });
    }
  }

  void _back() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AspectRatio(
              aspectRatio: 1.4,
              child: label.isEmpty && child == null
                  ? const SizedBox()
                  : TextButton(
                      style: TextButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                      onPressed: onTap ?? () => _tap(label),
                      child: child ??
                          Text(label,
                              style: TextStyle(fontSize: 26, color: scheme.onSurface)),
                    ),
            ),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < widget.length; i++)
            Container(
              margin: const EdgeInsets.all(8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _digits.length ? scheme.primary : null,
                border: Border.all(color: scheme.primary, width: 2),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(children: [
          Row(children: [key('1'), key('2'), key('3')]),
          Row(children: [key('4'), key('5'), key('6')]),
          Row(children: [key('7'), key('8'), key('9')]),
          Row(children: [
            key(''),
            key('0'),
            key('⌫',
                onTap: _back,
                child: Icon(Icons.backspace_outlined, color: scheme.onSurface)),
          ]),
        ]),
      ),
    ]);
  }
}

// ---------------- Pattern pad ----------------

class PatternPad extends StatefulWidget {
  const PatternPad({super.key, required this.onComplete});

  final ValueChanged<List<int>> onComplete;

  @override
  State<PatternPad> createState() => _PatternPadState();
}

class _PatternPadState extends State<PatternPad> {
  final List<int> _sel = [];
  Offset? _finger;
  double _size = 300;

  Offset _center(int i) => Offset((i % 3 + 0.5) * _size / 3, (i ~/ 3 + 0.5) * _size / 3);

  void _hit(Offset p) {
    for (var i = 0; i < 9; i++) {
      if (!_sel.contains(i) && (p - _center(i)).distance < _size / 8) {
        // Include a dot jumped over in a straight line (e.g. 1 -> 3 passes 2).
        if (_sel.isNotEmpty) {
          final a = _sel.last;
          final mid = (a + i) ~/ 2;
          final straight = (a + i).isEven &&
              ((a % 3 + i % 3) / 2 == mid % 3) &&
              ((a ~/ 3 + i ~/ 3) / 2 == mid ~/ 3);
          if (straight && mid != a && mid != i && !_sel.contains(mid)) _sel.add(mid);
        }
        _sel.add(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      _size = math.min(c.maxWidth, 320);
      return SizedBox(
        width: _size,
        height: _size,
        child: GestureDetector(
          onPanStart: (d) => setState(() {
            _sel.clear();
            _finger = d.localPosition;
            _hit(d.localPosition);
          }),
          onPanUpdate: (d) => setState(() {
            _finger = d.localPosition;
            _hit(d.localPosition);
          }),
          onPanEnd: (_) {
            final result = List<int>.of(_sel);
            setState(() {
              _sel.clear();
              _finger = null;
            });
            if (result.isNotEmpty) widget.onComplete(result);
          },
          child: CustomPaint(
            painter: _PatternPainter(
              sel: List<int>.of(_sel),
              finger: _finger,
              size: _size,
              dot: scheme.onSurfaceVariant,
              line: scheme.primary,
            ),
          ),
        ),
      );
    });
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.sel,
    required this.finger,
    required this.size,
    required this.dot,
    required this.line,
  });

  final List<int> sel;
  final Offset? finger;
  final double size;
  final Color dot;
  final Color line;

  Offset _c(int i) => Offset((i % 3 + 0.5) * size / 3, (i ~/ 3 + 0.5) * size / 3);

  @override
  void paint(Canvas canvas, Size s) {
    final lp = Paint()
      ..color = line
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var k = 1; k < sel.length; k++) {
      canvas.drawLine(_c(sel[k - 1]), _c(sel[k]), lp);
    }
    if (sel.isNotEmpty && finger != null) canvas.drawLine(_c(sel.last), finger!, lp);
    for (var i = 0; i < 9; i++) {
      final on = sel.contains(i);
      canvas.drawCircle(_c(i), on ? 14 : 8, Paint()..color = on ? line : dot);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => true;
}

// ---------------- Lock screen (shown over the whole app) ----------------

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.onUnlocked});

  /// If null, unlocks the app. Otherwise called on success (used for "verify").
  final VoidCallback? onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _error;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _try(String secret) {
    if (appLock.check(secret)) {
      if (widget.onUnlocked != null) {
        widget.onUnlocked!();
      } else {
        appLock.unlock();
      }
      return;
    }
    final until = appLock.blockedUntil;
    setState(() {
      if (until != null && DateTime.now().isBefore(until)) {
        _error = 'Too many tries. Wait 30 seconds.';
        _timer?.cancel();
        _timer = Timer(until.difference(DateTime.now()), () {
          if (mounted) setState(() => _error = null);
        });
      } else {
        _error = appLock.type == 'pin' ? 'Wrong PIN' : 'Wrong pattern';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPin = appLock.type == 'pin';
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/icons/teal.png', width: 72, height: 72),
              const SizedBox(height: 16),
              Text('Hisaab is locked', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(isPin ? 'Enter your PIN' : 'Draw your pattern',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              SizedBox(
                height: 32,
                child: Center(
                  child: Text(_error ?? '', style: TextStyle(color: scheme.error)),
                ),
              ),
              if (isPin)
                PinPad(onComplete: (v) => _try('pin:$v'))
              else
                PatternPad(onComplete: (d) => _try('pattern:${patternKey(d)}')),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------- Settings: choose / change / remove lock ----------------

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key});

  Future<bool> _verify(BuildContext context) async {
    if (!appLock.enabled) return true;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('Confirm it\'s you')),
        body: LockScreen(onUnlocked: () => Navigator.pop(ctx, true)),
      ),
    ));
    return ok ?? false;
  }

  Future<void> _choose(BuildContext context, String type) async {
    if (type == appLock.type) return;
    if (!await _verify(context)) return;
    if (!context.mounted) return;
    if (type == 'off') {
      await appLock.disable();
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _LockSetup(type: type)),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(type == 'pin' ? 'PIN lock is on' : 'Pattern lock is on'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appLock,
      builder: (context, _) {
        Widget option(String type, String title, String subtitle, IconData icon) => ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: appLock.type == type ? const Icon(Icons.check) : null,
              onTap: () => _choose(context, type),
            );
        return Scaffold(
          appBar: AppBar(title: const Text('App lock')),
          body: ListView(children: [
            option('off', 'Off', 'Anyone with your phone can open Hisaab', Icons.lock_open),
            option('pin', 'PIN', '4-digit code', Icons.pin_outlined),
            option('pattern', 'Pattern', 'Connect at least 4 dots', Icons.pattern),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Hisaab locks when you open it, and again if you leave it for more than '
                '30 seconds. If you forget your PIN or pattern, the only way back in is to '
                'reinstall the app and restore a backup, so keep auto backup on. '
                'Fingerprint and Face ID will come in a later update.',
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _LockSetup extends StatefulWidget {
  const _LockSetup({required this.type});
  final String type;

  @override
  State<_LockSetup> createState() => _LockSetupState();
}

class _LockSetupState extends State<_LockSetup> {
  String? _first;
  String? _error;
  int _round = 0; // forces the pad to reset

  bool get _isPin => widget.type == 'pin';

  Future<void> _entered(String secret) async {
    if (_first == null) {
      setState(() {
        _first = secret;
        _error = null;
        _round++;
      });
      return;
    }
    if (secret != _first) {
      setState(() {
        _first = null;
        _error = _isPin ? 'PINs didn\'t match. Try again.' : 'Patterns didn\'t match. Try again.';
        _round++;
      });
      return;
    }
    await appLock.set(widget.type, secret);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _isPin
        ? (_first == null ? 'Choose a 4-digit PIN' : 'Enter the PIN again')
        : (_first == null ? 'Draw a pattern' : 'Draw the pattern again');
    return Scaffold(
      appBar: AppBar(title: Text(_isPin ? 'Set PIN' : 'Set pattern')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(
              height: 32,
              child: Center(child: Text(_error ?? '', style: TextStyle(color: scheme.error))),
            ),
            if (_isPin)
              PinPad(key: ValueKey(_round), onComplete: (v) => _entered('pin:$v'))
            else
              PatternPad(
                key: ValueKey(_round),
                onComplete: (d) {
                  if (d.length < 4) {
                    setState(() => _error = 'Connect at least 4 dots');
                    return;
                  }
                  _entered('pattern:${patternKey(d)}');
                },
              ),
          ]),
        ),
      ),
    );
  }
}
