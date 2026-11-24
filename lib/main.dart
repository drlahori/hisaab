import 'package:flutter/material.dart';

import 'backup.dart';
import 'drive.dart';
import 'lock.dart';
import 'screens/lock_screens.dart';
import 'screens/accounts.dart';
import 'screens/calculator.dart';
import 'screens/settings.dart';
import 'screens/stats.dart';
import 'screens/transactions.dart';
import 'store.dart';
import 'style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  await appLock.load();
  await drive.load();
  runApp(const HisaabApp());
  maybeAutoBackup();
}

class HisaabApp extends StatelessWidget {
  const HisaabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'Hisaab',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(hs),
        themeMode: ThemeMode.light,
        home: const HomeShell(),
        builder: (context, child) => ListenableBuilder(
          listenable: appLock,
          builder: (context, _) => Stack(children: [
            if (child != null) child,
            if (appLock.locked) const Positioned.fill(child: LockScreen()),
          ]),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      appLock.onPaused();
    } else if (state == AppLifecycleState.resumed) {
      appLock.onResumed();
      maybeAutoBackup();
    }
  }

  static const _pages = <Widget>[
    TransactionsScreen(),
    StatsScreen(),
    AccountsScreen(),
    CalculatorScreen(),
    SettingsScreen(),
  ];

  static const _tabs = <(IconData, IconData, String)>[
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Records'),
    (Icons.pie_chart_outline, Icons.pie_chart, 'Stats'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Accounts'),
    (Icons.calculate_outlined, Icons.calculate, 'Calc'),
    (Icons.more_horiz, Icons.more_horiz, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final s = hs;
    return Scaffold(
      backgroundColor: s.bg,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          height: 68,
          decoration: BoxDecoration(
            color: s.nav,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Row(children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == _index,
                  button: true,
                  label: _tabs[i].$3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _index = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(i == _index ? _tabs[i].$2 : _tabs[i].$1,
                            size: 22, color: i == _index ? Colors.white : s.navOff),
                        const SizedBox(height: 4),
                        Text(
                          _tabs[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == _index ? FontWeight.w700 : FontWeight.w500,
                            color: i == _index ? Colors.white : s.navOff,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
