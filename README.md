# Make My Money Last (3ML)

**Make My Money Last** is a Flutter app for personal budgeting with a chat-first workflow. It focuses on one question for the current pay period:

> **How much can I safely spend per day without running out before payday?**

There is no bank linking: profile and transactions live in **SQLite** on the device. Optional HTTP services can parse natural-language spending and provide coaching replies; if they are unavailable, the app falls back to **local parsing**, **local coaching**, and **heuristic** transaction-vs-conversation routing.

---

## Requirements

- **Flutter** with Dart **≥ 3.3.0** (see `pubspec.yaml`)
- **Android Studio** or **Xcode** when building for mobile emulators or devices

---

## Run the app

From the repository root (this folder):

```bash
flutter pub get
flutter run
```

Targets **mobile** (Android/iOS), **desktop**, and **web** are supported in code via `sqflite` FFI variants initialized in `lib/sqlite_init.dart`.

---

## Project layout

```
lib/
├── main.dart                    # App entry, orientation, theme routing
├── app_theme.dart               # Light/dark themes, AppColors extension
├── sqlite_init.dart             # Platform SQLite bootstrap
├── sqlite_init_vm.dart / sqlite_init_web.dart
│
├── models/
│   ├── user_profile.dart        # Profile + payday calendar helpers
│   ├── transaction_model.dart   # Transactions + parser JSON → model
│   └── buffer_model.dart        # End-of-day buffer / credits
│
├── services/
│   ├── api_service.dart         # Classifier, event parser, coach, chat HTTP
│   ├── budget_service.dart      # Safe-to-spend and period aggregates
│   ├── category_service.dart    # Category metadata + items_db hooks
│   ├── database_service.dart    # SQLite persistence
│   ├── date_parser_service.dart # Natural-language date → DateTime
│   └── export_service.dart      # CSV + JSON backup
│
├── providers/
│   └── app_provider.dart        # Global state (profile, chat, budget)
│
├── data/
│   └── items_db.dart            # Category keyword hints for the parser UI
│
├── screens/
│   ├── main_shell.dart          # Bottom navigation + PageView
│   ├── onboarding/
│   │   ├── onboarding_screen.dart
│   │   └── setup_screen.dart
│   ├── home/home_screen.dart
│   ├── chat/chat_screen.dart
│   ├── analytics/analytics_screen.dart
│   └── settings/settings_screen.dart
│
└── widgets/
    ├── safe_to_spend_card.dart
    ├── payday_circle.dart
    └── transaction_tile.dart

backend/
├── classifier_server.py         # Optional local DistilBERT classifier (FastAPI)
└── requirements.txt
```

---

## Optional: local transaction classifier

The app can call a **local FastAPI** service to classify input as **transaction** vs **conversation** before parsing (see `ApiService.classifyInput`).

- **Endpoint:** `POST /classify` with JSON body `{ "text": "…" }`
- **Response:** `{ "label": "transaction" | "conversation", "confidence": <number>, … }`
- **Defaults:** `http://127.0.0.1:8000` on desktop, `http://10.0.2.2:8000` on Android emulator, `http://localhost:8000` on web

From the repo root, with Python 3 and a model export at `classifier/3ml-classifier-distilbert` (or set `M3L_CLASSIFIER_MODEL` to your model directory):

```bash
pip install -r backend/requirements.txt
python backend/classifier_server.py
```

Health check: `GET /health`.

---

## Remote APIs (developer configuration)

Parser and coach URLs are **not** edited from the in-app Settings screen today. They default in `lib/services/api_service.dart` (`_eventParserUrl`, `_coachChatUrl`). Change those defaults or call `ApiService().setEventParserUrl(...)` / `setCoachChatUrl(...)` from your own wiring if you need runtime configuration.

### Event parser — `POST …/parse`

**Request**

```http
POST {baseUrl}/parse
Content-Type: application/json

{ "text": "coffee 35" }
```

**Responses**

- **Success:** JSON object with fields the app normalizes (aliases in parentheses): `intent`, `category`, `item`, `amount`, `date` (`date_expression`), `needs_clarification`, `confidence`. Amount must be positive for a saved transaction when clarification is not required.
- **Not parseable:** `{ "parseable": false }` — user message is treated as non-transaction text.

The client maps **intent** and **category** to stored **transaction types** (Income, Expense, Unknown); see `TransactionModel.fromModelA`.

### Coach — `POST …/coach`

**Request** (shape used by `getCoachingTip`):

```json
{
  "safe_to_spend_before": 120.0,
  "safe_to_spend_today": 115.5,
  "runway_days": 12,
  "current_balance": 0.0,
  "is_over_budget": false,
  "recent_expense": {
    "amount": 35.0,
    "category": "food & dining",
    "item": "coffee"
  },
  "week_summary": {}
}
```

**Response:** JSON containing a string **`message`** (nested keys are resolved by `_extractStringResponse`).

If the coach URL is empty or the request fails, the app uses **`localCoachingTip`** instead.

### Budget Q&A chat — `POST …/chat`

**Request:** `{ "user_context": "…", "user_input": "…" }`  
**Response:** JSON containing an **`answer`** string.

If the coach base URL is not configured, **`localChatFallback`** is used.

---

## Safe-to-spend logic (summary)

For the transactions between **last payday** and **next payday** (see `BudgetService.calculate`):

1. **Disposable income** (from profile): `salary - fixedBills - savingsGoal`
2. **Period pool:** disposable income **plus** any **income** recorded in the period
3. **Remaining:** period pool **minus** expenses in the period
4. **Safe to spend (daily):** `remaining / daysUntilPayday` (with a minimum of one day in the divisor)
5. **Safety buffer:** safe-to-spend minus the **even daily burn** you would need to hit the pool exactly on time (`periodPool / totalDaysInPeriod`)

The home card uses these values; negative safe-to-spend means you are ahead of budget for the days left.

---

## Data export

Under **Settings → Privacy & Data**:

| Action | Contents |
|--------|----------|
| **Export Transactions (CSV)** | One row per transaction with id, raw text, type, intent, item, amount, dates, category, confidence |
| **Backup Data** | JSON: profile, all transactions, plus `before_parser` / `after_parser` fields for auditing or restore |

**Settings → Danger Zone → Reset App** deletes local data after confirmation.

---

## UI and themes

The app ships **dark** and **light** themes (`AppColors` via `ThemeExtension`). Shared accents include primary `#00D4A1`, accent `#7C6FFF`, and danger `#FF5252` (`AppTheme`).

Bottom tabs: **Home**, **Chat**, **Spending** (analytics), **Settings**.

---

## Privacy

- No bank or card linking
- Data stored locally (SQLite + SharedPreferences for preferences)
- Text you type is only sent to URLs you configure in code (parser, coach, chat) and to the optional local classifier
- Privacy copy is also summarized in-app under **Settings → Privacy**

---

## Version

App version **1.0.0** (see `pubspec.yaml`).
