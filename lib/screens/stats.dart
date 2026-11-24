import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';
import 'budgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _Slice {
  _Slice(this.label, this.emoji, this.value, this.color);
  final String label;
  final String emoji;
  final double value;
  final Color color;
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  TxType _type = TxType.expense;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.inMonth(_month);
        final income = AppStore.sum(list, TxType.income);
        final expense = AppStore.sum(list, TxType.expense);

        final totals = <String?, double>{};
        for (final t in list.where((t) => t.type == _type)) {
          totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
        }
        final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final total = _type == TxType.income ? income : expense;
        final slices = <_Slice>[
          for (var i = 0; i < entries.length; i++)
            _Slice(
              store.category(entries[i].key)?.name ?? 'Uncategorised',
              store.category(entries[i].key)?.emoji ?? '❔',
              entries[i].value,
              kChartColors[i % kChartColors.length],
            ),
        ];

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: MonthSwitcher(month: _month, onChanged: (m) => setState(() => _month = m)),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SummaryBar(income: income, expense: expense),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SegmentedButton<TxType>(
                  segments: const [
                    ButtonSegment(value: TxType.income, label: Text('Income')),
                    ButtonSegment(value: TxType.expense, label: Text('Expense')),
                  ],
                  selected: {_type},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
              ),
              if (slices.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(text: 'No data for this month.', icon: Icons.pie_chart_outline),
                )
              else ...[
                SizedBox(
                  height: 220,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      slices.map((s) => s.value).toList(),
                      slices.map((s) => s.color).toList(),
                      Theme.of(context).colorScheme.surface,
                    ),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_type == TxType.income ? 'Income' : 'Expenses',
                            style: Theme.of(context).textTheme.labelMedium),
                        Text(money(total), style: Theme.of(context).textTheme.titleMedium),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final s in slices)
                  ListTile(
                    dense: true,
                    leading: Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${(s.value / total * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    title: Text('${s.emoji}  ${s.label}'),
                    trailing: Text(money(s.value)),
                  ),
              ],
              if (_type == TxType.expense) ...[
                const Divider(height: 32),
                _BudgetSection(month: _month, list: list),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BudgetSection extends StatelessWidget {
  const _BudgetSection({required this.month, required this.list});

  final DateTime month;
  final List<Txn> list;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var totalBudget = 0.0;
    var totalSpent = 0.0;
    for (final c in store.categoriesOf(TxType.expense)) {
      final budget = store.budgets[c.id];
      if (budget == null) continue;
      final spent = AppStore.sum(list.where((t) => t.categoryId == c.id), TxType.expense);
      totalBudget += budget;
      totalSpent += spent;
      rows.add(_BudgetBar(label: '${c.emoji}  ${c.name}', budget: budget, spent: spent));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text('Budget', style: Theme.of(context).textTheme.titleMedium),
          trailing: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BudgetsScreen()),
            ),
            child: const Text('Set budgets'),
          ),
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No budgets yet. Set a monthly limit for any expense category.'),
          )
        else ...[
          _BudgetBar(label: 'Total', budget: totalBudget, spent: totalSpent, bold: true),
          ...rows,
        ],
      ],
    );
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({
    required this.label,
    required this.budget,
    required this.spent,
    this.bold = false,
  });

  final String label;
  final double budget;
  final double spent;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final ratio = budget <= 0 ? 0.0 : spent / budget;
    final over = ratio > 1;
    final left = budget - spent;
    final style = bold ? const TextStyle(fontWeight: FontWeight.w600) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: style)),
          Text(money(budget), style: style),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            color: over ? kExpense : Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Text('Spent ${money(spent)}', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(
            over ? 'Over by ${money(-left)}' : 'Left ${money(left)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: over ? kExpense : null),
          ),
        ]),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors, this.gap);

  final List<double> values;
  final List<Color> colors;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    const stroke = 34.0;
    final radius = math.min(size.width, size.height) / 2 - stroke / 2 - 4;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
      if (values.length > 1) {
        final sep = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = gap;
        final a = start;
        final inner = radius - stroke / 2;
        final outer = radius + stroke / 2;
        final c = rect.center;
        canvas.drawLine(
          c + Offset(math.cos(a) * inner, math.sin(a) * inner),
          c + Offset(math.cos(a) * outer, math.sin(a) * outer),
          sep,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colors != colors || old.gap != gap;
}
