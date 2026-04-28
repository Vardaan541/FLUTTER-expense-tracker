# Smart Expense Tracker

Smart Expense Tracker is a Flutter + Firebase app for tracking income/expenses, setting budgets, monitoring burn rate, and viewing category analytics through a modern dashboard.

## Features

- Firebase Authentication (email/password)
- Firestore-backed transaction history per user
- Income and expense entries with categories, notes, and dates
- Monthly and category budget planning
- Daily burn analytics with run-rate projection:
  - Current daily burn
  - 7-day rolling burn
  - Safe daily burn (from monthly budget)
  - Spending at % of safe pace
- Category-wise visual analytics (pie distribution + ranked share list)
- Monthly spending trend chart
- Gamified level progression system with 1000 level titles (emoji + rank title)
- Dark and light theme support

## Formula Snapshot (Research-Friendly)

- `currentDailyBurn = spentThisMonth / elapsedDaysInMonth`
- `rolling7DayBurn = sum(last7DaysExpenses) / 7`
- `safeDailyBurn = monthlyBudget / daysInMonth`
- `spendingAtSafePacePercent = (currentDailyBurn / safeDailyBurn) * 100`
- `projectedMonthSpend = currentDailyBurn * daysInMonth`

Interpretation:

- `< 100%`: under safe pace
- `= 100%`: on safe pace
- `> 100%`: above safe pace (potential overshoot risk)

## Tech Stack

- Flutter
- Provider (state management)
- Firebase Auth
- Cloud Firestore
- fl_chart
- intl

## Project Structure

- `lib/screens`: UI screens
- `lib/providers`: app state and business logic
- `lib/services`: Firebase and catalog services
- `lib/models`: data models
- `lib/widgets`: reusable UI widgets

## Setup

1. Install Flutter SDK.
2. Configure Firebase for Android/iOS.
3. Run:

```bash
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --release
```

Output:

- `build/app/outputs/flutter-apk/app-release.apk`

## Repository

GitHub: [Vardaan541/FLUTTER-expense-tracker](https://github.com/Vardaan541/FLUTTER-expense-tracker.git)
