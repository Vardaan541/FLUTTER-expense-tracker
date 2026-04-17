import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/pet_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/transaction_provider.dart';
import 'add_transaction_screen.dart';
import 'budget_screen.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key, required this.uid});

  final String uid;

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const <Widget>[
    DashboardScreen(),
    AddTransactionScreen(),
    TransactionsScreen(),
    BudgetScreen(),
  ];

  final List<String> _titles = const <String>[
    'Burn Arena',
    'Add Entry',
    'History',
    'Budget Plan',
  ];

  @override
  void initState() {
    super.initState();
    _bindProvidersForUser();
  }

  @override
  void didUpdateWidget(covariant HomeShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _bindProvidersForUser();
    }
  }

  void _bindProvidersForUser() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<TransactionProvider>().bindToUser(widget.uid);
      context.read<BudgetProvider>().bindToUser(widget.uid);
      context.read<PetProvider>().bindToUser(widget.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_titles[_selectedIndex]),
            if (_selectedIndex == 0)
              Text(
                'Control your daily burn',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: 0.72,
                  ),
                ),
              ),
          ],
        ),
        actions: <Widget>[
          Consumer<ThemeProvider>(
            builder:
                (
                  BuildContext context,
                  ThemeProvider themeProvider,
                  Widget? child,
                ) {
                  return IconButton(
                    onPressed: themeProvider.toggleTheme,
                    icon: Icon(
                      themeProvider.isDarkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                    tooltip: themeProvider.isDarkMode
                        ? 'Switch to light mode'
                        : 'Switch to dark mode',
                  );
                },
          ),
          IconButton(
            onPressed: () async {
              context.read<TransactionProvider>().clear();
              context.read<BudgetProvider>().clear();
              context.read<PetProvider>().clear();
              await context.read<AuthProvider>().signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Burn',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Plan',
          ),
        ],
      ),
    );
  }
}
