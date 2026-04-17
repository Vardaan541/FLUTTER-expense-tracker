import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/pet_progress.dart';
import '../providers/budget_provider.dart';
import '../providers/pet_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/monthly_spending_chart.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, BudgetProvider, PetProvider>(
      builder:
          (
            BuildContext context,
            TransactionProvider transactionProvider,
            BudgetProvider budgetProvider,
            PetProvider petProvider,
            Widget? child,
          ) {
            if (transactionProvider.isLoading || budgetProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final double monthSpent = transactionProvider
                .currentMonthExpenseTotal();
            final Map<String, double> categorySpent = transactionProvider
                .currentMonthExpenseByCategory();
            final MapEntry<String, double>? topCategory =
                categorySpent.entries.isEmpty
                ? null
                : (categorySpent.entries.toList()..sort((
                        MapEntry<String, double> a,
                        MapEntry<String, double> b,
                      ) {
                        return b.value.compareTo(a.value);
                      }))
                      .first;
            final DateTime now = DateTime.now();
            final int day = now.day;
            final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
            final double avgDailySpend = day == 0 ? 0 : monthSpent / day;
            final double projectedMonthSpend = avgDailySpend * daysInMonth;
            final _PetStatus petStatus = _PetStatus.fromSpending(
              projectedMonthSpend: projectedMonthSpend,
              monthSpent: monthSpent,
              budgetLimit: budgetProvider.budget.monthlyLimit,
              dayOfMonth: day,
              daysInMonth: daysInMonth,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) {
                return;
              }
              context.read<PetProvider>().syncProjection(
                projectedMonthSpend: projectedMonthSpend,
                budgetLimit: budgetProvider.budget.monthlyLimit,
                score: petStatus.score,
                stageKey: petStatus.stageKey,
              );
            });
            final NumberFormat currency = NumberFormat.currency(symbol: '₹');
            final double budgetLimit = budgetProvider.budget.monthlyLimit;
            final bool hasBudget = budgetLimit > 0;
            final double safeDailySpend = hasBudget ? budgetLimit / daysInMonth : 0;
            final double burnPaceRatio = safeDailySpend == 0
                ? 0
                : avgDailySpend / safeDailySpend;
            final double burnGaugeValue = hasBudget
                ? (burnPaceRatio / 2).clamp(0.0, 1.0)
                : 0;
            final int burnScore = hasBudget
                ? ((1 - ((burnPaceRatio - 1).abs() / 1.4)).clamp(0.0, 1.0) * 100)
                      .toInt()
                : 0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (transactionProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      transactionProvider.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (budgetProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      budgetProvider.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (petProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      petProvider.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                _BurnHeroCard(
                  currency: currency,
                  avgDailySpend: avgDailySpend,
                  safeDailySpend: safeDailySpend,
                  burnGaugeValue: burnGaugeValue,
                  burnPaceRatio: burnPaceRatio,
                  burnScore: burnScore,
                  hasBudget: hasBudget,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricChip(
                        label: 'Spent This Month',
                        value: currency.format(monthSpent),
                        icon: Icons.payments_outlined,
                        accent: Colors.deepOrangeAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricChip(
                        label: 'Month Projection',
                        value: currency.format(projectedMonthSpend),
                        icon: Icons.bolt_outlined,
                        accent: Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Theme.of(context).colorScheme.primaryContainer.withValues(
                          alpha: 0.65,
                        ),
                        Theme.of(context).colorScheme.secondaryContainer.withValues(
                          alpha: 0.45,
                        ),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Smart Insights',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        topCategory == null
                            ? 'No expenses this month yet.'
                            : 'Top category: ${topCategory.key} (${currency.format(topCategory.value)})',
                      ),
                      const SizedBox(height: 6),
                      Text('Daily burn rate: ${currency.format(avgDailySpend)}'),
                      const SizedBox(height: 6),
                      Text(
                        'Projected month-end spending: ${currency.format(projectedMonthSpend)}',
                      ),
                      const SizedBox(height: 12),
                      _ProjectionPetCard(
                        petStatus: petStatus,
                        petProgress: petProvider.pet,
                        projectedMonthSpend: projectedMonthSpend,
                        budgetLimit: budgetProvider.budget.monthlyLimit,
                      ),
                      const SizedBox(height: 10),
                      _BudgetAlertBanner(
                        isExceeded: budgetProvider.isMonthlyBudgetExceeded(
                          monthSpent,
                        ),
                        budgetLimit: budgetProvider.budget.monthlyLimit,
                        spent: monthSpent,
                      ),
                      const SizedBox(height: 10),
                      const _GameRulesCard(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Monthly Spending Trend',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                MonthlySpendingChart(
                  monthlyTotals: transactionProvider
                      .monthlyExpenseTotalsForCurrentYear(),
                ),
                const SizedBox(height: 16),
                SummaryCard(
                  title: 'Total Balance',
                  value: transactionProvider.balance,
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SummaryCard(
                        title: 'Income',
                        value: transactionProvider.totalIncome,
                        icon: Icons.arrow_downward_rounded,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        title: 'Expenses',
                        value: transactionProvider.totalExpense,
                        icon: Icons.arrow_upward_rounded,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
    );
  }
}

class _BurnHeroCard extends StatelessWidget {
  const _BurnHeroCard({
    required this.currency,
    required this.avgDailySpend,
    required this.safeDailySpend,
    required this.burnGaugeValue,
    required this.burnPaceRatio,
    required this.burnScore,
    required this.hasBudget,
  });

  final NumberFormat currency;
  final double avgDailySpend;
  final double safeDailySpend;
  final double burnGaugeValue;
  final double burnPaceRatio;
  final int burnScore;
  final bool hasBudget;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = burnPaceRatio <= 1
        ? Colors.greenAccent.shade100
        : Colors.deepOrangeAccent.shade100;
    final Color foreground = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color mutedForeground = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF334155);
    final List<Color> heroGradient = isDark
        ? const <Color>[Color(0xFF1E243D), Color(0xFF14182B)]
        : const <Color>[Color(0xFFEAF0FF), Color(0xFFDDE7FF)];
    final Color paceBackground = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.04);

    final String paceTitle;
    if (!hasBudget) {
      paceTitle = 'Set your monthly budget to unlock Burn Mode';
    } else if (burnPaceRatio <= 0.9) {
      paceTitle = 'Zen pace: you are under the safe burn zone';
    } else if (burnPaceRatio <= 1.1) {
      paceTitle = 'Perfect pace: your burn is on track';
    } else {
      paceTitle = 'Heat rising: tighten spend to protect runway';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: heroGradient,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.12),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Daily Burn Arena',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 9,
                      color: foreground.withValues(alpha: 0.14),
                    ),
                    CircularProgressIndicator(
                      value: burnGaugeValue,
                      strokeWidth: 9,
                      color: accent,
                    ),
                    Center(
                      child: Text(
                        '$burnScore',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      currency.format(avgDailySpend),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                    Text(
                      'Current daily burn rate',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasBudget
                          ? 'Safe daily burn: ${currency.format(safeDailySpend)}'
                          : 'Safe daily burn available after setting budget',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: paceBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              paceTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BudgetAlertBanner extends StatelessWidget {
  const _BudgetAlertBanner({
    required this.isExceeded,
    required this.budgetLimit,
    required this.spent,
  });

  final bool isExceeded;
  final double budgetLimit;
  final double spent;

  @override
  Widget build(BuildContext context) {
    if (budgetLimit <= 0) {
      return const Text(
        'Set a monthly budget in Budget tab to enable smart alerts.',
      );
    }

    final NumberFormat currency = NumberFormat.currency(symbol: '₹');
    final String text = isExceeded
        ? 'Alert: You crossed your monthly budget by ${currency.format(spent - budgetLimit)}'
        : 'Great! You are within budget. Remaining: ${currency.format(budgetLimit - spent)}';
    final Color foreground = isExceeded
        ? const Color(0xFF7A1022)
        : const Color(0xFF0F5A2F);
    final Color background = isExceeded
        ? const Color(0xFFFFE3E6)
        : const Color(0xFFD9FBE6);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isExceeded ? Icons.warning_amber_rounded : Icons.check_circle,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameRulesCard extends StatelessWidget {
  const _GameRulesCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showRulesBottomSheet(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Game Rules: How to win your burn battle',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  void _showRulesBottomSheet(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final ColorScheme bottomSheetScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    height: 4,
                    width: 42,
                    decoration: BoxDecoration(
                      color: bottomSheetScheme.onSurface.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Gamified Expense Tracker Rules',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: bottomSheetScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                const _RuleItem(
                  icon: Icons.local_fire_department_rounded,
                  text:
                      'Main target: keep your daily burn rate at or below the safe daily burn.',
                ),
                const _RuleItem(
                  icon: Icons.savings_rounded,
                  text:
                      'Set a monthly budget first. This unlocks burn score, pet growth, and meaningful projections.',
                ),
                const _RuleItem(
                  icon: Icons.bolt_rounded,
                  text:
                      'Low-spend transactions build combo streaks. Better combos reward more coins and progress.',
                ),
                const _RuleItem(
                  icon: Icons.warning_amber_rounded,
                  text:
                      'Heavy spends trigger Overheat alerts and can reset combo momentum.',
                ),
                const _RuleItem(
                  icon: Icons.emoji_events_rounded,
                  text:
                      'Maintain discipline over multiple days to unlock badges, skins, and higher pet stages.',
                ),
                const _RuleItem(
                  icon: Icons.track_changes_rounded,
                  text:
                      'Use month projection daily: if it overshoots budget, reduce today\'s spend to recover pace.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionPetCard extends StatelessWidget {
  const _ProjectionPetCard({
    required this.petStatus,
    required this.petProgress,
    required this.projectedMonthSpend,
    required this.budgetLimit,
  });

  final _PetStatus petStatus;
  final PetProgress petProgress;
  final double projectedMonthSpend;
  final double budgetLimit;

  @override
  Widget build(BuildContext context) {
    final NumberFormat currency = NumberFormat.currency(symbol: '₹');
    final int toNextStage = (petStatus.nextStageScore - petProgress.currentXp)
        .clamp(0, 100);
    final bool hasBudget = budgetLimit > 0;
    final String skinEmoji = petStatus.stageKey == 'egg'
        ? petStatus.emoji
        : _emojiForSkin(petProgress.selectedSkin);
    final List<String> badgeLabels = petProgress.badges
        .map(_badgeLabel)
        .toList()
      ..sort();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(skinEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      petStatus.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      petStatus.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                'XP ${petProgress.currentXp}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: petProgress.currentXp / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            hasBudget
                ? '$toNextStage XP to next evolution'
                : 'Set a monthly budget to start growing your pet',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (hasBudget) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              projectedMonthSpend <= budgetLimit
                  ? 'Projected cushion: ${currency.format(budgetLimit - projectedMonthSpend)}'
                  : 'Projected overshoot: ${currency.format(projectedMonthSpend - budgetLimit)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Treat coins: ${petProgress.petCoins}  |  Spend combo: ${petProgress.disciplineCombo}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Streak: ${petProgress.streakDays} days (best ${petProgress.bestStreak})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Skins unlocked: ${petProgress.unlockedSkins.length}/4',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (badgeLabels.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: badgeLabels.map((String label) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text('Today\'s quest: ${petStatus.quest}'),
        ],
      ),
    );
  }

  String _emojiForSkin(String skin) {
    switch (skin) {
      case 'dragon':
        return '🐉';
      case 'fox':
        return '🦊';
      case 'hatchling':
        return '🐣';
      default:
        return '🐢';
    }
  }

  String _badgeLabel(String badge) {
    switch (badge) {
      case 'first_budget_pet':
        return 'First Hatch';
      case 'projection_guardian':
        return 'Projection Guardian';
      case 'dragon_mode':
        return 'Dragon Mode';
      case 'streak_3':
        return '3-Day Streak';
      case 'streak_7':
        return '7-Day Streak';
      case 'combo_3':
        return 'Combo 3';
      case 'combo_5':
        return 'Combo 5';
      case 'coin_collector_100':
        return '100 Coins';
      default:
        return badge;
    }
  }
}

class _PetStatus {
  const _PetStatus({
    required this.score,
    required this.stageKey,
    required this.emoji,
    required this.name,
    required this.subtitle,
    required this.quest,
    required this.nextStageScore,
  });

  final int score;
  final String stageKey;
  final String emoji;
  final String name;
  final String subtitle;
  final String quest;
  final int nextStageScore;

  factory _PetStatus.fromSpending({
    required double projectedMonthSpend,
    required double monthSpent,
    required double budgetLimit,
    required int dayOfMonth,
    required int daysInMonth,
  }) {
    if (budgetLimit <= 0) {
      return const _PetStatus(
        score: 0,
        stageKey: 'egg',
        emoji: '🥚',
        name: 'Unhatched Pocket Pet',
        subtitle: 'Needs a budget nest to hatch.',
        quest: 'Set a monthly budget to unlock pet growth',
        nextStageScore: 25,
      );
    }

    final double usageRatio = projectedMonthSpend / budgetLimit;
    final double allowedDaily = budgetLimit / daysInMonth;
    final double avgDaily = dayOfMonth == 0 ? 0 : monthSpent / dayOfMonth;
    final double paceRatio = allowedDaily == 0 ? 0 : avgDaily / allowedDaily;
    final double expectedSpentSoFar = allowedDaily * dayOfMonth;
    int score = 0;

    if (usageRatio <= 0.8) {
      score += 40;
    } else if (usageRatio <= 1.0) {
      score += 30;
    } else if (usageRatio <= 1.1) {
      score += 18;
    } else if (usageRatio <= 1.25) {
      score += 8;
    }

    if (paceRatio <= 1) {
      score += 25;
    } else {
      score += (25 - ((paceRatio - 1) * 40)).clamp(0, 25).toInt();
    }

    if (projectedMonthSpend < budgetLimit) {
      final double cushionRatio =
          ((budgetLimit - projectedMonthSpend) / budgetLimit).clamp(0, 1);
      score += (cushionRatio * 20).toInt();
    }

    if (monthSpent <= expectedSpentSoFar) {
      score += 15;
    } else {
      score += 5;
    }

    score = score.clamp(0, 100);

    if (score >= 85) {
      return _PetStatus(
        score: score,
        stageKey: 'dragon',
        emoji: '🐉',
        name: 'Emerald Budget Dragon',
        subtitle: 'Legendary control. Your projections are crystal clear.',
        quest: 'Keep daily spend below ₹${allowedDaily.toStringAsFixed(0)}',
        nextStageScore: 100,
      );
    }
    if (score >= 65) {
      return _PetStatus(
        score: score,
        stageKey: 'fox',
        emoji: '🦊',
        name: 'Savvy Forecast Fox',
        subtitle: 'Great instincts. One careful week unlocks evolution.',
        quest: 'Trim one non-essential category today',
        nextStageScore: 85,
      );
    }
    if (score >= 40) {
      return _PetStatus(
        score: score,
        stageKey: 'hatchling',
        emoji: '🐣',
        name: 'Budget Hatchling',
        subtitle: 'Growing steadily. Small wins will level it up.',
        quest: 'Hit a no-spend half-day to gain bonus XP',
        nextStageScore: 65,
      );
    }
    return _PetStatus(
      score: score,
      stageKey: 'turtle',
      emoji: '🐢',
      name: 'Cautious Turtle',
      subtitle: 'Slow and steady comeback mode is active.',
      quest: 'Bring projection under ₹${budgetLimit.toStringAsFixed(0)}',
      nextStageScore: 40,
    );
  }
}
