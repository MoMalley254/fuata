# UI Design Brief: "Pocket" (working title)

> **How to use this with an AI design tool:** paste this whole document first, then ask for **one screen at a time** ("Design screen 2: Home, light mode, then dark mode"). Ask for a design-token table at the end so the result can be rebuilt in Flutter.

---

## 1. What the app is

A personal money-flow tracker for Android. The user records what they have across **cash, mobile money, bank accounts, cards and anything else they name**, and the app shows, at a glance:

- how much they have left to spend today,
- where their money went (who, when, how much),
- where money came in from.

Everything stays on the phone. There is no account, no sign-up, no server, no internet. Transactions are added by hand, by sharing/pasting a bank or mobile-money message, or (optionally) captured from notifications.

**The problem it solves:** the person overspends when out and about, and can't reconcile cash, mobile money and bank spending in one place.

**The signature feature:** a persistent notification "banner" in the Android notification curtain that shows how much is left and whether they are safe, close to the limit, over it, or overdrawn, without opening the app.

## 2. Design principles (the important part)

1. **Glanceable first.** One look answers "Am I okay today?" The most important number is the biggest thing on the screen.
2. **Simple by default, deep on demand (progressive disclosure).** Show the minimum useful information. Anything extra sits one tap away (expand, "More", "Details"). Never show everything at once.
3. **Personal, not institutional.** It must **not** look like a banking app or an accounting ledger. No dense tables, no navy-and-grey corporate palette, no account-number styling, no jargon such as "ledger", "debit/credit", "reconcile".
4. **The user owns it.** The user names their money, picks its icon and colour, chooses what Home shows and how much detail they see. Copy speaks in first person and ownership: *my money, your day, you've got*.
5. **Works for them, not a chore.** Adding a transaction takes seconds. Nothing is nagging or shaming. Overspending is treated with calm, practical language, never guilt.
6. **Calm and inviting.** Soft shapes, generous spacing, warm colour, gentle motion. Feels closer to a personal journal or a habit app than a finance tool.

## 3. Personalisation (design these as real, visible features)

| What the user controls | Where |
|---|---|
| Their name (used in the greeting) | Onboarding, Me |
| Accent colour for the whole app (from ~8 warm/cool options, plus custom) | Onboarding, Me |
| Each money unit: name, icon **or** emoji **or** photo, colour | Add/Edit unit |
| Which units appear on Home and in what order | Home (long-press to reorder), My money |
| Headline number on Home: "Left today" / "Total I have" / "Spent today" | Me → Home |
| Which sections Home shows (Units, Lately, Weekly peek) | Me → Home |
| **Detail level: Simple / Balanced / Detailed** | Me → Detail |
| Which units and what the notification banner shows | Banner setup |
| Their own limits (daily, weekly, monthly, per unit or overall) | Limits |
| Category names and icons | Me → Categories |
| Light / dark / follow system | Me → Appearance |

**Detail level behaviour (design all three states for Activity and Transaction detail):**
- **Simple:** amount, who, a friendly time ("this afternoon"). Nothing else.
- **Balanced (default):** adds the money unit and category.
- **Detailed:** adds exact date/time, transaction code, fee, note, source (manual / message / notification), and the balance after.

## 4. Look and feel

- **Platform:** Android phone, portrait, design at 360×800 dp. Must be buildable with Flutter and Material 3 components, so avoid effects that are hard to build (heavy blur, complex 3D).
- **Shape language:** large rounded corners (20-28 dp cards, pill-shaped chips and buttons), soft shadows or tonal surfaces rather than hard borders.
- **Colour:**
  - Background: warm off-white (about `#FBF8F3`) in light mode, soft charcoal (about `#14161A`) in dark. Avoid pure white and pure black.
  - Default accent: a warm teal or coral (user changeable).
  - **Status colours** (used on the hero card, banner, progress rings, and chips):

| State | Meaning | Suggested colour | Also needs (never colour alone) |
|---|---|---|---|
| Safe | Well within limit | Green `#2E9E6B` | check icon + "You're good" |
| Warning | Roughly 70-90% of limit used | Amber `#E8A317` | clock/! icon + "Easy now" |
| Danger | Roughly 90-100% used | Orange-red `#E5533D` | alert icon + "Almost at your limit" |
| Overdraft | Over limit or a unit below zero | Deep crimson `#B3123F` | striped/pattern ring + "Over by X" |

  All text must meet contrast requirements in both themes. Status must be readable by colour-blind users (icon + label + fill pattern).
- **Typography:** friendly rounded sans-serif (Nunito, DM Sans or Plus Jakarta Sans). **Big, bold, tabular numerals** for money. Small, quiet labels. Only 3-4 text sizes on any screen.
- **Iconography:** rounded outline icons, plus emoji as first-class icons for units and categories.
- **Motion:** gentle. Numbers count up/down, rings fill smoothly, sheets slide up. No bouncing or confetti.
- **Illustration:** light, friendly empty-state illustrations (a small piggy-bank-like or coin-purse character is fine). Never stock finance imagery (graphs with arrows, suits, skyscrapers).

## 5. Voice and microcopy

Warm, short, plain, first person, never judgemental.

| Situation | Say | Don't say |
|---|---|---|
| Greeting | "Hi Amina 👋" | "Welcome back, User" |
| Safe | "You've got 1,250 left today" | "Remaining budget: 1,250.00" |
| Warning | "Easy now: 400 left for today" | "Warning: budget nearly exhausted" |
| Overdraft | "You're 200 over today. Want to adjust?" | "Limit exceeded!" |
| Empty activity | "Nothing yet today. Nice and calm." | "No transactions found" |
| Captured message | "Caught this from your messages. Is it right?" | "Pending transaction review" |
| Privacy | "Everything stays on this phone." | "Data is encrypted in transit" |

Use "money" not "funds", "spent/got/moved" not "debit/credit/transfer" wherever possible.

## 6. Sample data (use in every mockup so screens feel real)

- User: **Amina**, currency **KES**, daily limit **2,000**, monthly limit **45,000**
- Units ("My money"):
  - 💵 Cash: 760 (green)
  - 📱 Mobile money: 3,450 (blue)
  - 🏦 Bank X: 12,000 (purple, custom name and emoji)
  - 💳 Card C: 120 (orange)
- Today's activity:
  - Spent 350 · Java House · Mobile money · 1:12 PM · Food
  - Spent 150 · Matatu fare · Cash · 8:05 AM · Transport
  - Got 5,000 · Salary · Bank X · yesterday · Income
  - Moved 2,000 · Bank X → Cash · yesterday (not counted as spending)
- Today total spent: 500, so **1,500 left of 2,000**. Use other amounts for warning, danger and overdraft variants.
- Caught-from-message example: "Confirmed. Ksh350.00 paid to JAVA HOUSE on 21/9/26 at 1:12 PM. Transaction code QW12ABC3. New balance Ksh3,450.00."

## 7. Screens to design

Design each in **light and dark**. For key screens also show an **empty state** and a **detail-level variation** where noted.

### 7.1 Onboarding (4-5 short steps, all skippable, no forms)
1. **Welcome:** "Your money, in one glance. Everything stays on this phone." Ask for name and accent colour.
2. **Add your money:** quick-pick tiles (Cash, Mobile money, Bank, Card, Something else). Each opens a tiny sheet: name, icon/emoji/photo, colour, "how much is in it now?". No card numbers, and say so ("We never ask for account or card numbers").
3. **Daily limit (optional):** big number stepper plus a "Skip, I'll decide later" link.
4. **Your banner (optional):** a live preview of the notification banner, "Show this in your notifications?" with Yes/Not now.
5. **Auto-catch (optional):** friendly explainer of reading bank/mobile-money notifications. Three plain bullets: what it reads, what it ignores (everything else), and that it never leaves the phone. Buttons: "Set it up later" / "Turn on".

### 7.2 Home ("Today"): the most important screen
- Greeting and small date, avatar/initial top right.
- **Hero card:** large ring or soft progress shape filled to today's usage, coloured by status. Centre: the big "Left today" number, with a one-line friendly status message and a small "of 2,000 · resets at midnight". Tap hero → expands to show spent so far, per-unit split, and the next-limit info (progressive disclosure).
- **My money:** horizontally scrolling cards, one per unit (icon, name, amount). Tap → unit page. Last card is a soft "+ Add".
- **Lately:** the latest 3 transactions as light rows (no table lines), with "See all" link.
- Optional **Week peek:** a tiny 7-day bar strip.
- **Add button:** prominent floating "+" (or centre button in bottom nav).
- **Bottom navigation (4 items):** Today, Activity, My money, Me.
- Design Home in **four status states** (safe, warning, danger, overdraft) and one **empty first-day state**.

### 7.3 Add transaction (bottom sheet, opens from "+")
- Type toggle: **Spent · Got · Moved**.
- **Big amount with a numeric keypad first.** Nothing else blocks it.
- "From/To" unit chips (defaults to the last used).
- One optional line: "Who or what for?" (autocompletes past names).
- A collapsed **"More"** row expands to: category, date/time, note, fee.
- One large "Save" button. Moved shows two unit pickers with an arrow.

### 7.4 Activity
- Grouped by friendly day headings ("Today", "Yesterday", "Mon 15 Sep") with a small daily total.
- Rows: emoji/category icon, who, amount (colour-tinted subtly: spent neutral, got green). No grid lines.
- Filter **chips** on top: All / Spent / Got / by unit. Search icon.
- Tap a row → **bottom-sheet detail** with an "expand for details" section. Show it in Simple, Balanced and Detailed.
- "Where it went" toggle: switches the list to **people/places ranked by amount** for the period.
- Empty state.

### 7.5 My money
- Big total at top ("Altogether you have 16,330"), tap to hide/show amounts (privacy eye).
- Cards for each unit with icon, name, amount, and a small "last updated" or "checked" hint.
- Tap → **unit page:** amount, quick "Update balance" (sets it to a number; the app records the difference as an adjustment), that unit's recent activity, edit name/icon/colour, its limit, and its message-reading rule if any.
- "+ Add something" tile.

### 7.6 Caught from your messages (review inbox)
- Card stack or list of captured transactions: "Spent 350 · Java House · Mobile money · 1:12 PM."
- Actions per card: ✓ Looks right, ✎ Fix, ✕ Not mine. Swipe gestures optional.
- Second section: "Couldn't read these", each with a "Teach me" button that opens the rule builder.
- A setting toggle in the header: "Auto-accept from trusted rules."
- Empty state: "All caught up."

### 7.7 Teach the app to read a message (rule builder)
- Step 1: "Paste a message you get" (large text area, plus "Paste" button).
- Step 2: the message appears as **tappable word chips**. Tapping a word or selecting a range opens a small palette: Amount, Code, Date/time, Person/Place, Balance, Fee, "This part changes", plus "Add my own field". Chosen words get coloured highlights matching the palette.
- Step 3: a live **"Here's what I found"** mini transaction card that updates as they label. Fields not found are shown as empty dashed chips.
- Step 4: "Try another message" (paste more samples and see if it still works), and choose the unit and whether it is Spent/Got or "let the message decide".
- Save as a named rule, e.g. "Bank X · money out".

### 7.8 Limits and alerts
- Simple cards: Daily, Weekly, Monthly, each with an on/off switch and a big number field.
- Optional per-unit limits under "More".
- **Alert levels** as friendly sliders: "Nudge me at 70% / 90% / when I'm over".
- **Quiet hours** option.
- A live preview of the resulting banner state.

### 7.9 Banner setup (notification customisation)
- **Live notification preview** at the top, changing as options change. Show both collapsed and expanded.
- Options: which units to show (all / pick), headline number, show progress bar, show quick-add button, hide amounts on the lock screen.
- Note that colour is limited by Android; the design uses a status emoji (🟢🟡🟠🔴), a progress bar and a coloured icon.

### 7.10 Notification designs (draw as Android notification-shade mockups)
- **Banner, collapsed:** "🟢 1,500 left today" with a subtle progress bar.
- **Banner, expanded:** unit split (Cash 760 · Mobile 3,450 · Bank X 12,000), the spent-today line, and buttons: "+ Add" and "Open".
- All four states: 🟢 safe, 🟡 warning, 🟠 danger, 🔴 overdraft ("Over by 200").
- **Alert notification** (separate): "Easy now: you've used 80% of today."
- **Caught-a-transaction** notification: "Spent 350 · Java House. Tap to check."

### 7.11 Summaries (Today / Week / Month)
- A segmented control: Day / Week / Month.
- **Story-style cards**, not dashboards: "This week you spent 8,420. Most of it went to Food, and Java House was your top spot."
- **Spent vs Got** as a simple two-bar comparison, with "Where it went" and "Where it came from" lists (top 3, "See all" for more).
- Optional **per-unit split** as a soft stacked bar. Charts must be simple (one idea per chart).
- A "Show me more" expander for those who want the numbers.
- Gentle, non-judgemental tone: "A bit more than last week."

### 7.12 Me (settings and personalisation)
- Profile block (name, accent colour swatches).
- Groups: **Home** (headline, sections), **Detail level** (Simple/Balanced/Detailed with live example row), **Limits & alerts**, **Banner**, **Message reading** (rules, allowed apps), **Categories**, **Appearance**, **Privacy & data**.
- **Privacy & data:** a reassuring panel, "Nothing leaves this phone" (no account, no internet permission), with Export, Import, and "Erase everything" (with a confirm step).

## 8. Reusable components to design once

Hero status ring card · Unit card · Transaction row · Transaction bottom sheet · Amount keypad · Filter chip · Segmented control · Status pill (Safe/Easy/Almost/Over) · Word-label chip (rule builder) · Empty-state card · Confirmation dialog · Toggle row · Notification mockups.

## 9. Do and don't

**Do:** big numbers, lots of whitespace, one primary action per screen, friendly words, emoji, rounded shapes, consistent status colours, thumb-reachable actions at the bottom.
**Don't:** tables, dense lists, tiny grey text, more than two accent colours on a screen, bank-style logos or padlocks, red text for ordinary spending, guilt-based messages, jargon, anything that asks for card or account numbers.

## 10. What to deliver back

1. Every screen in section 7 in **light and dark** at 360×800.
2. The Home screen in all four status states plus its empty state.
3. Activity in Simple, Balanced and Detailed detail levels.
4. The five notification mockups (section 7.10).
5. A **design-token table**: colours (both themes), type scale, spacing scale, corner radii, elevation, and icon sizes.
6. A short **component list** with states (default, pressed, disabled).
7. A short note on the visual direction (2-3 sentences) so it can be kept consistent later.
