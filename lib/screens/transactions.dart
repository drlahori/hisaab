import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';
import '../style.dart';
import 'calculator.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  DateTime get _defaultDate {
    final now = DateTime.now();
    if (now.year == _month.year && now.month == _month.month) return now;
    return DateTime(_month.year, _month.month, 1);
  }

  void _search() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
      );

  void _shift(int step) {
    final yearly = _tabs.index == 2;
    setState(() => _month = DateTime(_month.year, _month.month + (yearly ? 12 * step : step)));
  }

  String get _periodLabel => _tabs.index == 2
      ? '${_month.year}'
      : DateFormat('MMMM yyyy').format(_month);

  /// Expenses for the last 7 days of the period (ending today in the current month).
  List<double> _week(List<Txn> list) {
    final now = DateTime.now();
    final end = (now.year == _month.year && now.month == _month.month)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(_month.year, _month.month + 1, 0);
    final out = List<double>.filled(7, 0);
    for (final t in list) {
      if (t.type != TxType.expense) continue;
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      final diff = end.difference(d).inDays;
      if (diff >= 0 && diff < 7) out[6 - diff] += t.amount;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final yearly = _tabs.index == 2;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = hs;
        final List<Txn> shown;
        if (yearly) {
          shown = store.txns.where((t) => t.date.year == _month.year).toList();
        } else {
          shown = store.inMonth(_month);
        }
        final income = AppStore.sum(shown, TxType.income);
        final expense = AppStore.sum(shown, TxType.expense);
        final header = switch (s.id) {
          'midnight' => _MidnightHeader(
              label: _periodLabel, yearly: yearly, income: income, expense: expense,
              onPrev: () => _shift(-1), onNext: () => _shift(1), onSearch: _search),
          'bold' => _BoldHeader(
              label: yearly ? '${_month.year}' : DateFormat('MMM yyyy').format(_month),
              yearly: yearly, income: income, expense: expense, week: _week(shown),
              onPrev: () => _shift(-1), onNext: () => _shift(1), onSearch: _search),
          _ => _CleanHeader(
              label: _periodLabel, yearly: yearly, income: income, expense: expense,
              onPrev: () => _shift(-1), onNext: () => _shift(1), onSearch: _search,
              onCalc: () => openCalculator(context)),
        };
        return Scaffold(
          backgroundColor: s.bg,
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              header,
              _TabPicker(controller: _tabs),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    DailyList(txns: shown),
                    _CalendarView(month: _month, txns: shown),
                    _MonthlyView(
                      year: _month.year,
                      onPick: (m) {
                        setState(() => _month = m);
                        _tabs.animateTo(0);
                      },
                    ),
                  ],
                ),
              ),
            ]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab-transactions',
            onPressed: () => openTxnEditor(context, date: _defaultDate),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        );
      },
    );
  }
}

// ---------------- style headers ----------------

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.outlined = false, this.square = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final s = hs;
    final shape = square
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: s.cardBorder))
        : CircleBorder(side: outlined ? BorderSide(color: s.text, width: 1.5) : BorderSide.none);
    return Material(
      color: outlined ? Colors.transparent : s.card,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: s.text, semanticLabel: label),
        ),
      ),
    );
  }
}

class _CleanHeader extends StatelessWidget {
  const _CleanHeader({
    required this.label, required this.yearly, required this.income, required this.expense,
    required this.onPrev, required this.onNext, required this.onSearch, required this.onCalc,
  });

  final String label;
  final bool yearly;
  final double income, expense;
  final VoidCallback onPrev, onNext, onSearch, onCalc;

  @override
  Widget build(BuildContext context) {
    final s = hs;
    Widget tile(String t, double v) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(money(v),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Assalam-o-Alaikum', style: TextStyle(fontSize: 13, color: s.sub)),
              Row(children: [
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: s.text)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Previous',
                  icon: Icon(Icons.chevron_left, color: s.sub),
                  onPressed: onPrev,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Next',
                  icon: Icon(Icons.chevron_right, color: s.sub),
                  onPressed: onNext,
                ),
              ]),
            ]),
          ),
          _RoundButton(icon: Icons.calculate_outlined, label: 'Calculator', onTap: onCalc, square: true),
          const SizedBox(width: 8),
          _RoundButton(icon: Icons.search, label: 'Search', onTap: onSearch, square: true),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: s.accent, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(yearly ? 'Balance this year' : 'Balance this month',
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(money(income - expense),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 14),
            Row(children: [tile('Income', income), const SizedBox(width: 10), tile('Expenses', expense)]),
          ]),
        ),
      ]),
    );
  }
}

class _MidnightHeader extends StatelessWidget {
  const _MidnightHeader({
    required this.label, required this.yearly, required this.income, required this.expense,
    required this.onPrev, required this.onNext, required this.onSearch,
  });

  final String label;
  final bool yearly;
  final double income, expense;
  final VoidCallback onPrev, onNext, onSearch;

  @override
  Widget build(BuildContext context) {
    final s = hs;
    Widget chip(String t, double v, IconData icon, Color c, Color bg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: s.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: s.cardBorder),
            ),
            child: Row(children: [
              CircleAvatar(radius: 16, backgroundColor: bg, child: Icon(icon, size: 16, color: c)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: TextStyle(fontSize: 11, color: s.sub)),
                  FittedBox(
                    child: Text(money(v), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: s.text)),
                  ),
                ]),
              ),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        Row(children: [
          _RoundButton(icon: Icons.chevron_left, label: 'Previous', onTap: onPrev),
          Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: s.text)),
          ),
          _RoundButton(icon: Icons.chevron_right, label: 'Next', onTap: onNext),
          const SizedBox(width: 8),
          _RoundButton(icon: Icons.search, label: 'Search', onTap: onSearch),
        ]),
        const SizedBox(height: 18),
        Text(yearly ? 'NET THIS YEAR' : 'NET THIS MONTH',
            style: TextStyle(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600, color: s.sub)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: s.accent, width: 4))),
          child: FittedBox(
            child: Text(money(income - expense),
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: s.text, letterSpacing: -1)),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          chip('Income', income, Icons.arrow_upward, s.inc, const Color(0xFFDCFCE7)),
          const SizedBox(width: 10),
          chip('Expenses', expense, Icons.arrow_downward, s.exp, const Color(0xFFFFEDD5)),
        ]),
      ]),
    );
  }
}

class _BoldHeader extends StatelessWidget {
  const _BoldHeader({
    required this.label, required this.yearly, required this.income, required this.expense, required this.week,
    required this.onPrev, required this.onNext, required this.onSearch,
  });

  final String label;
  final bool yearly;
  final double income, expense;
  final List<double> week;
  final VoidCallback onPrev, onNext, onSearch;

  @override
  Widget build(BuildContext context) {
    final s = hs;
    final maxW = week.fold<double>(0, (a, b) => b > a ? b : a);
    Widget tile(String t, double v, Color bg, Color ink) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink)),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(money(v),
                    style: TextStyle(fontFamily: s.headFont, fontSize: 20, fontWeight: FontWeight.w700, color: ink)),
              ),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hisaab', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: s.sub)),
              Text(label,
                  style: TextStyle(fontFamily: s.headFont, fontSize: 30, fontWeight: FontWeight.w700, color: s.text)),
            ]),
          ),
          _RoundButton(icon: Icons.chevron_left, label: 'Previous', onTap: onPrev, outlined: true),
          const SizedBox(width: 8),
          _RoundButton(icon: Icons.chevron_right, label: 'Next', onTap: onNext, outlined: true),
          const SizedBox(width: 8),
          _RoundButton(icon: Icons.search, label: 'Search', onTap: onSearch, outlined: true),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(color: s.text, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(yearly ? 'Total this year' : 'Total this month',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFD6D3D1))),
                FittedBox(
                  child: Text(money(income - expense),
                      style: TextStyle(fontFamily: s.headFont, fontSize: 30, fontWeight: FontWeight.w700, color: s.bg)),
                ),
              ]),
            ),
            Semantics(
              label: 'Spending over the last 7 days',
              child: SizedBox(
                height: 44,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 7; i++)
                    Container(
                      margin: const EdgeInsets.only(left: 5),
                      width: 8,
                      height: maxW <= 0 ? 6 : 6 + 38 * (week[i] / maxW),
                      decoration: BoxDecoration(
                        color: i == 6 ? s.accent : const Color(0xFF78716C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          tile('Income', income, const Color(0xFFD9F5E3), const Color(0xFF14532D)),
          const SizedBox(width: 10),
          tile('Expenses', expense, const Color(0xFFFFE1D6), const Color(0xFF7C2D12)),
        ]),
      ]),
    );
  }
}

/// Daily / Calendar / Monthly switch, drawn in the chosen style.
class _TabPicker extends StatelessWidget {
  const _TabPicker({required this.controller});

  final TabController controller;

  static const _labels = ['Daily', 'Calendar', 'Monthly'];

  @override
  Widget build(BuildContext context) {
    final s = hs;
    final current = controller.index;
    switch (s.id) {
      case 'midnight':
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            for (var i = 0; i < 3; i++) ...[
              ChoiceChip(
                label: Text(_labels[i]),
                selected: current == i,
                showCheckmark: false,
                onSelected: (_) => controller.animateTo(i),
                selectedColor: s.accent,
                backgroundColor: s.bg,
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w700, color: current == i ? s.onAccent : s.text),
                shape: StadiumBorder(side: BorderSide(color: current == i ? s.accent : const Color(0xFFCFC8BA))),
              ),
              const SizedBox(width: 8),
            ],
          ]),
        );
      case 'bold':
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
          child: Row(children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(right: 22),
                child: InkWell(
                  onTap: () => controller.animateTo(i),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 4, top: 6),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: current == i ? s.accent : Colors.transparent, width: 3)),
                    ),
                    child: Text(_labels[i],
                        style: TextStyle(
                            fontFamily: s.headFont,
                            fontSize: 16,
                            fontWeight: current == i ? FontWeight.w700 : FontWeight.w600,
                            color: current == i ? s.text : s.sub)),
                  ),
                ),
              ),
          ]),
        );
      default:
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: s.chip, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Material(
                  color: current == i ? s.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => controller.animateTo(i),
                    child: SizedBox(
                      height: 36,
                      child: Center(
                        child: Text(_labels[i],
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: current == i ? FontWeight.w600 : FontWeight.w500,
                                color: current == i ? s.text : s.sub)),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        );
    }
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({required this.month, required this.txns});

  final DateTime month;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first
    final cells = ((lead + daysInMonth + 6) ~/ 7) * 7;
    final byDay = <int, List<Txn>>{};
    for (final t in txns) {
      byDay.putIfAbsent(t.date.day, () => []).add(t);
    }
    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      children: [
        Row(children: [
          for (final n in names)
            Expanded(
              child: Center(
                child: Text(n, style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.62,
          ),
          itemBuilder: (context, i) {
            final day = i - lead + 1;
            if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
            final list = byDay[day] ?? const <Txn>[];
            final inc = AppStore.sum(list, TxType.income);
            final exp = AppStore.sum(list, TxType.expense);
            final isToday =
                now.year == month.year && now.month == month.month && now.day == day;
            return InkWell(
              onTap: () => _showDay(context, DateTime(month.year, month.month, day), list),
              child: Container(
                margin: const EdgeInsets.all(1),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant, width: 0.5),
                  color: isToday ? scheme.primaryContainer : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$day', style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    if (inc > 0) _tiny(inc, kIncome),
                    if (exp > 0) _tiny(exp, kExpense),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _tiny(double v, Color c) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(NumberFormat.compact().format(v),
            style: TextStyle(fontSize: 10, color: c)),
      );

  void _showDay(BuildContext context, DateTime day, List<Txn> list) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text(DateFormat('EEEE, d MMM yyyy').format(day)),
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: () {
                  Navigator.pop(ctx);
                  openTxnEditor(context, date: day);
                },
              ),
            ),
            const Divider(height: 1),
            if (list.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Text('Nothing on this day.'))
            else
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final t in list)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TxnTile(txn: t)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _MonthlyView extends StatelessWidget {
  const _MonthlyView({required this.year, required this.onPick});

  final int year;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lastMonth = year == now.year ? now.month : 12;
    final months = [for (var m = lastMonth; m >= 1; m--) DateTime(year, m)];
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: months.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = months[i];
        final list = store.inMonth(m);
        final inc = AppStore.sum(list, TxType.income);
        final exp = AppStore.sum(list, TxType.expense);
        return ListTile(
          title: Text(DateFormat('MMMM').format(m)),
          subtitle: Text('Total ${money(inc - exp)}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money(inc), style: const TextStyle(color: kIncome)),
              Text(money(exp), style: const TextStyle(color: kExpense)),
            ],
          ),
          onTap: () => onPick(m),
        );
      },
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = _q.toLowerCase().trim();
        final results = q.isEmpty
            ? <Txn>[]
            : store.txns.where((t) {
                final hay = [
                  t.note,
                  store.category(t.categoryId)?.name ?? '',
                  store.account(t.accountId)?.name ?? '',
                  store.account(t.toAccountId)?.name ?? '',
                  NumberFormat('0.##').format(t.amount),
                ].join(' ').toLowerCase();
                return hay.contains(q);
              }).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search notes, categories, accounts, amounts',
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          body: Column(children: [
            if (results.isNotEmpty)
              SummaryBar(
                income: AppStore.sum(results, TxType.income),
                expense: AppStore.sum(results, TxType.expense),
              ),
            Expanded(
              child: q.isEmpty
                  ? const EmptyState(text: 'Type to search', icon: Icons.search)
                  : DailyList(txns: results),
            ),
          ]),
        );
      },
    );
  }
}
