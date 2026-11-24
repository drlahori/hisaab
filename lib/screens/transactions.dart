import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';

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

  @override
  Widget build(BuildContext context) {
    final yearly = _tabs.index == 2;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final List<Txn> shown;
        if (yearly) {
          shown = store.txns.where((t) => t.date.year == _month.year).toList();
        } else {
          shown = store.inMonth(_month);
        }
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: MonthSwitcher(
              month: _month,
              yearOnly: yearly,
              onChanged: (m) => setState(() => _month = m),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'Daily'), Tab(text: 'Calendar'), Tab(text: 'Monthly')],
            ),
          ),
          body: Column(children: [
            SummaryBar(
              income: AppStore.sum(shown, TxType.income),
              expense: AppStore.sum(shown, TxType.expense),
            ),
            const Divider(height: 1),
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
          floatingActionButton: FloatingActionButton(
            heroTag: 'fab-transactions',
            onPressed: () => openTxnEditor(context, date: _defaultDate),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
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
                  for (final t in list) TxnTile(txn: t),
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
