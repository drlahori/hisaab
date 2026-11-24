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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  await appLock.load();
  await drive.load();
  runApp(const HisaabApp());
  maybeAutoBackup();
}

const kSeed = Color(0xFF0F766E); // teal

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: kSeed, brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
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
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: switch (store.theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Records'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Accounts'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Calc'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
