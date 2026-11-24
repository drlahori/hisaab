import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../common.dart';

// ---------------- maths ----------------

/// Evaluates expressions using + - × ÷ and %. "200+10%" = 220, "50%" = 0.5.
class _Parser {
  _Parser(this.s);
  final String s;
  int i = 0;

  static double eval(String input) {
    final p = _Parser(input.replaceAll(',', ''));
    final v = p._expr();
    if (p.i != p.s.length) throw const FormatException('Bad expression');
    if (v.isNaN || v.isInfinite) throw const FormatException('Cannot divide by zero');
    return v;
  }

  String? get _peek => i < s.length ? s[i] : null;

  double _expr() {
    var left = _term().$1;
    while (_peek == '+' || _peek == '-') {
      final op = s[i++];
      final (right, percent) = _term();
      final r = percent ? left * right : right;
      left = op == '+' ? left + r : left - r;
    }
    return left;
  }

  (double, bool) _term() {
    var (left, percent) = _factor();
    while (_peek == '×' || _peek == '÷') {
      final op = s[i++];
      final (right, _) = _factor();
      left = op == '×' ? left * right : left / right;
      percent = false;
    }
    return (left, percent);
  }

  (double, bool) _factor() {
    var v = _unary();
    var percent = false;
    while (_peek == '%') {
      i++;
      v /= 100;
      percent = true;
    }
    return (v, percent);
  }

  double _unary() {
    if (_peek == '-') {
      i++;
      return -_unary();
    }
    final start = i;
    while (i < s.length && (RegExp(r'[0-9.]').hasMatch(s[i]))) {
      i++;
    }
    if (start == i) throw const FormatException('Number expected');
    final v = double.tryParse(s.substring(start, i));
    if (v == null) throw const FormatException('Bad number');
    return v;
  }
}

final _fmt = NumberFormat('#,##0.########');

String _show(double v) => _fmt.format(v);

/// Adds commas to the numbers inside an expression for display.
String prettyExpr(String e) => e.replaceAllMapped(RegExp(r'\d+(\.\d*)?'), (m) {
      final parts = m.group(0)!.split('.');
      final ints = NumberFormat('#,##0').format(int.tryParse(parts[0]) ?? 0);
      return parts.length > 1 ? '$ints.${parts[1]}' : ints;
    });

// ---------------- history ----------------

class CalcEntry {
  CalcEntry(this.expr, this.result, this.at);
  final String expr;
  final double result;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'expr': expr, 'result': result, 'at': at.toIso8601String()};

  static CalcEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final r = j['result'];
    if (r is! num) return null;
    return CalcEntry((j['expr'] as String?) ?? '', r.toDouble(),
        DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now());
  }
}

class CalcHistory extends ChangeNotifier {
  final List<CalcEntry> items = []; // newest first
  bool _loaded = false;

  Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/hisaab_calc_history.json');

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString());
        if (list is List) {
          items
            ..clear()
            ..addAll(list.map(CalcEntry.fromJson).whereType<CalcEntry>());
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void add(CalcEntry e) {
    items.insert(0, e);
    if (items.length > 300) items.removeRange(300, items.length);
    notifyListeners();
    _save();
  }

  void clear() {
    items.clear();
    notifyListeners();
    _save();
  }
}

final calcHistory = CalcHistory();

/// Opens the calculator. If [pickAmount] is true, returns the chosen amount.
Future<double?> openCalculator(BuildContext context,
    {double? initial, bool pickAmount = false}) {
  return Navigator.of(context).push<double>(MaterialPageRoute(
    builder: (_) => CalculatorScreen(initial: initial, pickAmount: pickAmount),
  ));
}

// ---------------- screen ----------------

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, this.initial, this.pickAmount = false});

  final double? initial;
  final bool pickAmount;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expr = '';
  String? _error;

  static const _ops = ['+', '-', '×', '÷'];

  @override
  void initState() {
    super.initState();
    calcHistory.load();
    final v = widget.initial;
    if (v != null && v != 0) _expr = _raw(v);
  }

  String _raw(double v) => NumberFormat('0.########').format(v);

  double? get _preview {
    if (_expr.isEmpty) return null;
    var e = _expr;
    while (e.isNotEmpty && (_ops.contains(e[e.length - 1]) || e.endsWith('.'))) {
      e = e.substring(0, e.length - 1);
    }
    if (e.isEmpty) return null;
    try {
      return _Parser.eval(e);
    } catch (_) {
      return null;
    }
  }

  String get _currentNumber {
    final m = RegExp(r'[0-9.]*$').firstMatch(_expr);
    return m?.group(0) ?? '';
  }

  void _tap(String k) {
    setState(() {
      _error = null;
      final last = _expr.isEmpty ? '' : _expr[_expr.length - 1];
      switch (k) {
        case 'C':
          _expr = '';
        case '⌫':
          if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
        case '=':
          _equals();
        case '.':
          if (_currentNumber.contains('.')) return;
          _expr += (_currentNumber.isEmpty ? '0.' : '.');
        case '%':
          if (_expr.isEmpty || _ops.contains(last) || last == '%') return;
          _expr += '%';
        case '+' || '-' || '×' || '÷':
          if (_expr.isEmpty) {
            if (k == '-') _expr = '-';
            return;
          }
          if (_ops.contains(last)) {
            if (_expr.length == 1) return; // a lone leading minus
            _expr = _expr.substring(0, _expr.length - 1) + k;
          } else {
            _expr += k;
          }
        default: // digits and 00
          if (last == '%') return;
          if (k == '00' && _currentNumber.isEmpty) {
            _expr += '0';
          } else if (_currentNumber == '0') {
            _expr = _expr.substring(0, _expr.length - 1) + (k == '00' ? '0' : k);
          } else {
            _expr += k;
          }
      }
    });
  }

  void _equals() {
    if (_expr.isEmpty) return;
    try {
      final v = _Parser.eval(_expr);
      if (RegExp(r'[+\-×÷%]').hasMatch(_expr.substring(1))) {
        calcHistory.add(CalcEntry(_expr, v, DateTime.now()));
      }
      _expr = _raw(v);
    } on FormatException catch (e) {
      _error = e.message;
    }
  }

  void _useAmount() {
    final v = _preview;
    if (v == null || v <= 0) {
      toast(context, 'The result must be more than zero');
      return;
    }
    if (RegExp(r'[+\-×÷%]').hasMatch(_expr.substring(1))) {
      calcHistory.add(CalcEntry(_expr, v, DateTime.now()));
    }
    Navigator.pop(context, double.parse(v.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        actions: [
          ListenableBuilder(
            listenable: calcHistory,
            builder: (context, _) => IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: calcHistory.items.isEmpty
                  ? null
                  : () async {
                      final ok = await confirm(context, 'Clear calculator history?',
                          'All saved calculations will be removed.',
                          action: 'Clear');
                      if (ok) calcHistory.clear();
                    },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          // History
          Expanded(
            child: ListenableBuilder(
              listenable: calcHistory,
              builder: (context, _) {
                if (calcHistory.items.isEmpty) {
                  return const EmptyState(
                      text: 'Your calculations will be saved here.', icon: Icons.history);
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: calcHistory.items.length,
                  itemBuilder: (context, i) {
                    final e = calcHistory.items[i];
                    return ListTile(
                      dense: true,
                      title: Text(prettyExpr(e.expr),
                          textAlign: TextAlign.right,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      subtitle: Text(
                        '= ${_show(e.result)}',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      leading: Text(DateFormat('d MMM\nh:mm a').format(e.at),
                          style: Theme.of(context).textTheme.labelSmall),
                      onTap: () => setState(() {
                        _expr = _raw(e.result);
                        _error = null;
                      }),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Display
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _expr.isEmpty ? '0' : prettyExpr(_expr),
                  style: Theme.of(context).textTheme.headlineMedium,
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _error ?? (preview == null ? ' ' : '= ${_show(preview)}'),
                style: TextStyle(
                  fontSize: 18,
                  color: _error != null ? kExpense : scheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
          // Keypad
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(children: [
              _row(['C', '⌫', '%', '÷']),
              _row(['7', '8', '9', '×']),
              _row(['4', '5', '6', '-']),
              _row(['1', '2', '3', '+']),
              _row(['00', '0', '.', '=']),
            ]),
          ),
          if (widget.pickAmount)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                icon: const Icon(Icons.check),
                label: Text(preview == null ? 'Use amount' : 'Use ${money(preview)}'),
                onPressed: _useAmount,
              ),
            ),
        ]),
      ),
    );
  }

  Widget _row(List<String> keys) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      for (final k in keys)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              height: 58,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: k == '='
                      ? scheme.primary
                      : (_ops.contains(k) || k == '%' || k == 'C' || k == '⌫')
                          ? scheme.secondaryContainer
                          : scheme.surfaceContainerHighest,
                  foregroundColor: k == '=' ? scheme.onPrimary : scheme.onSurface,
                ),
                onPressed: () => _tap(k),
                child: k == '⌫'
                    ? const Icon(Icons.backspace_outlined)
                    : Text(k == '-' ? '−' : k, style: const TextStyle(fontSize: 24)),
              ),
            ),
          ),
        ),
    ]);
  }
}
