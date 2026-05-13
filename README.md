# 💚 Make My Money Last (3ML)

A chat-based personal budgeting Flutter app that answers one critical question every day:

> **"How much can I safely spend today without running out of money before payday?"**

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.3.0
- Dart ≥ 3.3.0
- Android Studio / Xcode for device deployment

### Install & Run

```bash
cd make_my_money_last
flutter pub get
flutter run
```

---

## 🏗️ Project Structure

```
lib/
├── main.dart                    # Entry point & app router
├── app_theme.dart               # Design system (colors, typography)
│
├── models/
│   ├── user_profile.dart        # User profile model + budget math
│   └── transaction_model.dart   # Transaction model + Model A JSON mapping
│
├── services/
│   ├── api_service.dart         # Model A (parser) + Model B (coach) HTTP calls
│   ├── budget_service.dart      # Safe-to-spend calculation engine
│   ├── category_service.dart    # Auto-categorization from items_db
│   ├── database_service.dart    # SQLite local storage
│   ├── date_parser_service.dart # Natural language date → DateTime
│   └── export_service.dart      # CSV + JSON dataset export
│
├── providers/
│   └── app_provider.dart        # Central state management (ChangeNotifier)
│
├── data/
│   └── items_db.dart            # All category → keyword mappings
│
├── screens/
│   ├── onboarding/
│   │   ├── onboarding_screen.dart   # New user vs restore
│   │   └── setup_screen.dart        # 5-step profile setup
│   ├── home/
│   │   └── home_screen.dart         # Safe-to-spend + payday + recent tx
│   ├── chat/
│   │   └── chat_screen.dart         # Chat interface + suggestions
│   ├── analytics/
│   │   └── analytics_screen.dart    # Spending breakdown + categories
│   └── settings/
│       └── settings_screen.dart     # Profile, data, API config, danger zone
│
├── widgets/
│   ├── safe_to_spend_card.dart  # Main card + tap-to-justify modal
│   ├── payday_circle.dart       # Animated dot-ring countdown
│   └── transaction_tile.dart    # Swipeable tx row with edit/delete
│
└── screens/
    └── main_shell.dart          # Bottom nav shell
```

---

## 🔌 Connecting Your Models

### Model A — Transaction Parser

**URL:** Configure in Settings → API Settings → Model A URL

**Expected request:**
```json
POST /parse
Content-Type: application/json

{ "text": "coffee 35" }
```

**Expected response:**
```json
{
  "transaction_type": "Expense",
  "intent": "bought coffee",
  "item": "coffee",
  "amount": 35.0,
  "date": "today",
  "needs_clarification": null,
  "confidence_score": 0.95
}
```

**Transaction types:**
- `"Income"` — salary, freelance, refunds
- `"Expense"` — all spending
- `"Investment"` — savings transfers, investments
- `"Unknown"` — greetings, nonsense → **app ignores these silently**

### Model B — Coaching Tips

**URL:** Configure in Settings → API Settings → Model B URL

**Expected request:**
```json
POST /coach
Content-Type: application/json

{
  "user_name": "Ahmed",
  "safe_to_spend": 85.50,
  "total_spent": 320.0,
  "disposable_income": 5000.0,
  "last_item": "coffee",
  "currency": "EGP"
}
```

**Expected response:**
```json
{ "message": "☕ That coffee is fine, but you have 12 days left. Stay mindful!" }
```

> If Model B URL is not set, the app generates local coaching tips automatically.

---

## 📦 Safe-to-Spend Formula

```
Disposable Income = Salary - Fixed Bills - Savings Goal
Remaining         = Disposable Income - Total Spent (this period)
Safe-to-Spend     = Remaining ÷ Days Until Payday
Safety Buffer     = Safe-to-Spend - (Disposable Income ÷ Total Days)
```

- **Green** = Safe-to-Spend ≥ 0
- **Red** = Over budget, negative number

---

## 📊 Data Export

From Settings → Privacy & Data:
- **CSV** — transaction list with all fields
- **Full Dataset (JSON)** — includes raw user input + Model A output side-by-side
- **Backup** — complete recovery file (profile + all transactions)

---

## 🎨 Design System

Dark fintech aesthetic with:
- Background: `#080C1A` (deep navy)
- Primary: `#00D4A1` (emerald mint)
- Accent: `#7C6FFF` (soft violet)
- Danger: `#FF5252` (coral red)
- Cards with subtle borders and glass morphism

---

## 📋 Key Screens

| Screen | Description |
|--------|-------------|
| **Onboarding** | New user setup (5 steps) or restore from backup |
| **Home** | Safe-to-spend card, payday countdown ring, recent transactions |
| **Chat** | Natural language input, quick suggestions, coaching tips |
| **Spending** | Donut chart + expandable category breakdown |
| **Settings** | Profile edit, API config, CSV/JSON export, reset |

---

## 🔒 Privacy

- Zero bank linking
- All data stored locally via SQLite
- Only raw text is sent to your configured API endpoints
- Full data deletion available in Settings → Danger Zone

---

## 📧 Contact

**Developer:** your@email.com  
**Version:** 1.0.0
