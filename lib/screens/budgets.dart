import 'package:flutter/material.dart';

import '../common.dart';
import '../models.dart';
import '../store.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cats = store.categoriesOf(TxType.expense);
        final total = store.budgets.values.fold<double>(0, (a, b) => a + b);
        return Scaffold(
          appBar: AppBar(title: const Text('Monthly budgets')),
          body: ListView(children: [
            ListTile(
              title: const Text('Total monthly budget'),
              trailing: Text(money(total),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            for (final c in cats)
              ListTile(
                leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(c.name),
                trailing: Text(
                  store.budgets[c.id] == null ? 'Not set' : money(store.budgets[c.id]!),
                ),
                onTap: () async {
                  final current = store.budgets[c.id];
                  final v = await promptText(
                    context,
                    'Budget for ${c.name}',
                    initial: current == null ? '' : amountText(current),
                    hint: 'Monthly amount (0 to remove)',
                    number: true,
                  );
                  if (v == null) return;
                  store.setBudget(c.id, parseAmount(v) ?? 0);
                },
              ),
          ]),
        );
      },
    );
  }
}
