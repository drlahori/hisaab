import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/models.dart';

void main() {
  test('transaction survives a JSON round trip', () {
    final t = Txn(
      id: 'a',
      type: TxType.transfer,
      date: DateTime(2026, 11, 24),
      amount: 1500,
      accountId: 'x',
      toAccountId: 'y',
    );
    final back = Txn.fromJson(t.toJson());
    expect(back.type, TxType.transfer);
    expect(back.amount, 1500);
    expect(back.toAccountId, 'y');
  });
}
