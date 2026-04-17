import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/pet_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  // Needed because we are calling async code before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Connects Flutter app to your Firebase project.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  final AuthService authService = AuthService();
  final FirestoreService firestoreService = FirestoreService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authService),
        ),
        ChangeNotifierProvider<TransactionProvider>(
          create: (_) => TransactionProvider(firestoreService),
        ),
        ChangeNotifierProvider<BudgetProvider>(
          create: (_) => BudgetProvider(firestoreService),
        ),
        ChangeNotifierProvider<PetProvider>(
          create: (_) => PetProvider(firestoreService),
        ),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: const SmartExpenseTrackerApp(),
    ),
  );
}

class SmartExpenseTrackerApp extends StatelessWidget {
  const SmartExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder:
          (BuildContext context, ThemeProvider themeProvider, Widget? child) {
            final ColorScheme darkScheme = ColorScheme.fromSeed(
              seedColor: const Color(0xFF4F46E5),
              brightness: Brightness.dark,
            );
            final ColorScheme lightScheme = ColorScheme.fromSeed(
              seedColor: const Color(0xFF4F46E5),
              brightness: Brightness.light,
            );

            return MaterialApp(
              // Removes debug banner from top-right
              debugShowCheckedModeBanner: false,
              title: 'Smart Expense Tracker',
              themeMode: themeProvider.themeMode,
              theme: ThemeData(
                colorScheme: lightScheme,
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFFF3F5FA),
                cardTheme: CardThemeData(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                appBarTheme: const AppBarTheme(
                  elevation: 0,
                  centerTitle: false,
                  backgroundColor: Colors.transparent,
                ),
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: const Color(0xFFE8ECF8),
                  indicatorColor: lightScheme.primary.withValues(alpha: 0.16),
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                    Set<WidgetState> states,
                  ) {
                    final bool selected = states.contains(WidgetState.selected);
                    return TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? lightScheme.onSurface
                          : lightScheme.onSurface.withValues(alpha: 0.7),
                    );
                  }),
                ),
              ),
              darkTheme: ThemeData(
                colorScheme: darkScheme,
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFF090B13),
                cardTheme: CardThemeData(
                  color: const Color(0xFF121729),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                appBarTheme: const AppBarTheme(
                  elevation: 0,
                  centerTitle: false,
                  backgroundColor: Colors.transparent,
                ),
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: const Color(0xFF11172A),
                  indicatorColor: darkScheme.primary.withValues(alpha: 0.24),
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                    Set<WidgetState> states,
                  ) {
                    final bool selected = states.contains(WidgetState.selected);
                    return TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? darkScheme.onSurface
                          : darkScheme.onSurface.withValues(alpha: 0.72),
                    );
                  }),
                ),
              ),
              home: const AuthGate(),
            );
          },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder:
          (BuildContext context, AuthProvider authProvider, Widget? child) {
            if (!authProvider.isAuthenticated) {
              return const AuthScreen();
            }

            final String uid = authProvider.user!.uid;
            return HomeShellScreen(uid: uid);
          },
    );
  }
}
