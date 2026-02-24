# Monojog App — Full Implementation Plan

> **Version:** 2.0 | **Language:** English only | **Date:** 2026-02-22

---

## 🗺️ App Architecture Overview

```
MonojogApp
│
├── SplashScreen  →  LoginScreen  →  MainScreen
│
└── MainScreen (4 Tabs — Floating Bottom Nav)
    ├── Tab 0: Home          🏠
    ├── Tab 1: Monojog       🚀  (Focus Timer — replaces centre diamond button)
    ├── Tab 2: Room          👥  (Study Rooms — custom time input, no dummy data)
    └── Tab 3: Garden        🌿  (New Screen: Stats + Flower Garden)
```

---

## 📐 Tab Structure

| # | Tab Name  | Icon                     | Screen File             | Status       |
|---|-----------|--------------------------|-------------------------|--------------|
| 0 | Home      | `home_rounded`           | `home_screen.dart`      | ✅ Exists (fix Bengali text) |
| 1 | Monojog   | `rocket_launch_rounded`  | `focus_screen.dart`     | ✅ Exists (fix Bengali text) |
| 2 | Room      | `meeting_room_rounded`   | `study_room_screen.dart`| 🔧 Update   |
| 3 | Garden    | `local_florist_rounded`  | `garden_screen.dart`    | 🆕 Create   |

---

## 🎨 Design System

### Color Palette
```
Primary Green:   #4CAF50  (room + garden accents)
Dark Green:      #2E7D32
Lime Active:     #C4F028  (bottom nav active pill)
Background:      #F8FFF8  (light green-tinted white)
Dark Nav BG:     #1A1C1E
Card White:      #FFFFFF
Text Dark:       #1A2B1A
Text Secondary:  #6B7B6B
```

### Bottom Navigation (Production-Grade)
- **Style**: Pill-shaped floating bar, dark background `#1A1C1E`
- **Active State**: Lime green `#C4F028` pill background with dark icon + label  
- **Inactive State**: White/grey icon + label, 45% opacity
- **4 items**: Home · Monojog · Room · Garden
- **No center diamond button** (that entire widget is removed)

---

## 🔧 Changes by File

### 1. `main.dart` — Complete Rewrite of MainScreen

**Remove:**
- `_buildHeader()` with the purple gradient header (including profile header, language toggle)
- The center diamond FAB (`_buildDiamondButton`)
- The `_openAddSheet` / `AddTaskSheet` reference in bottom nav
- `LocaleProvider` Consumer from nav (English is hardcoded now)
- Import of `locale_provider.dart`, `profile_header.dart`, `add_task_sheet.dart`

**Add:**
- 4-tab bottom nav: Home, Monojog, Room, Garden
- Each tab has icon + label, pill-shaped active indicator
- No global header — each screen manages its own top bar

**Screen array:**
```dart
[HomeScreen(), FocusScreen(), StudyRoomScreen(), GardenScreen()]
```

---

### 2. `study_room_screen.dart` — Update Room Screen

**Remove:**
- `_friends` dummy data list (`_FriendInfo` objects — Yuahi, Daisy, etc.)
- `_FriendInfo` class entirely
- `_friendTile()` widget
- `_buildTogetherBody()` (Together/Friends tab with dummy friends)
- The Alone/Together toggle
- `_friendsFilter` state & `_filterBtn()` 
- `_showAddFriendDialog()` call references

**Add:**
- **Custom Time Picker**: Replace fixed-chip time selection with a proper time input
  - Scrollable wheel picker (hours + minutes) or a simple text field
  - Default: 60 minutes
  - Range: 5 min – 480 min (8 hours)
- **Current Room View**: If student is in a room, show:
  - Room name, room code
  - Member list (from `StudyRoomProvider` — real data only)
  - Live countdown timer synced to room's set time
- **Admin Can Set Time**: Room creator gets time input; joiners see the time set by admin

---

### 3. `garden_screen.dart` — NEW SCREEN

**Two Sub-tabs inside Garden:**

#### Sub-tab A: Statistics 📊
- Visual bar chart of daily focus minutes (last 7 days) — from `fl_chart`
- Summary cards: Total Focus Time, Sessions Done, Current Streak, Longest Streak
- Weekly line chart of concentration trend
- Day-of-week labels in English

#### Sub-tab B: My Garden 🌸
- Flowers/plants grow based on total focus minutes earned
- Each plant represents a milestone (e.g., 60 min = seed sprouts, 300 min = flower blooms...)
- Animated growth stages using `AnimatedContainer` / `TweenAnimationBuilder`
- Show unlocked rewards/badges from `GameProvider`
- Emoji-based flower garden with animated sparkle effects

**Garden Growth Formula:**
```
Focus Minutes → Plant Stage
   0–59       : 🌱 Seed
  60–179       : 🌿 Sprout  
 180–359       : 🌷 Bud
 360–599       : 🌸 Bloom
 600+          : 🌳 Full Tree (rewarded!)
```

---

### 4. `statistics_screen.dart` + `rewards_screen.dart` — English-only pass

- Replace all Bengali text strings with English equivalents
- These screens are now embedded inside `GardenScreen` as sub-tabs

---

### 5. `focus_screen.dart` — English-only pass

- Replace Bengali strings with English:  
  `'মনোযোগ সেশন'` → `'Focus Session'`  
  `'ডিপ ফোকাস মোড...'` → description in English  
  etc.

---

### 6. `home_screen.dart` — English-only pass

- All `locale.t(...)` calls that return Bengali must be replaced with hardcoded English strings
- Remove `LocaleProvider` import if no longer needed

---

## 📋 Execution Checklist

- [x] ~~Create this plan~~
- [ ] 1. Rewrite `main.dart` → remove header, new 4-tab nav, import GardenScreen
- [ ] 2. Create `lib/screens/garden_screen.dart` → Stats + Flower Garden
- [ ] 3. Update `study_room_screen.dart` → remove dummy friends, add custom time picker
- [ ] 4. English pass on `statistics_screen.dart` → English labels
- [ ] 5. English pass on `rewards_screen.dart` → English labels  
- [ ] 6. English pass on `focus_screen.dart` → English labels
- [ ] 7. English pass on `home_screen.dart` → English labels
- [ ] 8. Run `flutter analyze` to catch errors

---

## 🖼️ Visual Wireframes (ASCII)

### Bottom Navigation Bar
```
┌─────────────────────────────────────────┐
│  🏠     🚀     👥     🌿              │
│ Home  Monojog  Room  Garden             │
│  ▔▔▔▔▔▔                                 │
│ [active = lime pill background]          │
└─────────────────────────────────────────┘
```

### Room Screen Layout (Custom Time)
```
┌─────────────────────────────────┐
│  🚪 Room          [Create] [Join]│
├─────────────────────────────────┤
│  Set Study Duration             │
│  ┌───────┐  :  ┌───────┐       │
│  │  01   │     │  30   │       │  ← hour/min wheel
│  └───────┘     └───────┘       │
│                                 │
│  [🌱 Start Solo Session]        │
│  [👥 Create Room for others]   │
│                                 │
│  ── Active Room ──────────────  │
│  📍 Room: "StudyZone" #AB12C   │
│  👤 Members: You + 2 others    │
│  ⏱ Time left: 00:45:22        │
└─────────────────────────────────┘
```

### Garden Screen Layout
```
┌──────────────────────────────────┐
│  🌿 My Garden                    │
│  ┌──────────┬──────────┐         │
│  │ 📊 Stats │ 🌸 Garden│         │  ← Tab bar
│  └──────────┴──────────┘         │
│                                  │
│  [Stats Tab View]                │
│  ┌────────────────────────────┐  │
│  │  Weekly Focus Bar Chart    │  │
│  │  Mon Tue Wed Thu Fri Sat   │  │
│  │  ▓▓  ░░  ▓▓▓ ░░  ▓▓  ▓▓   │  │
│  └────────────────────────────┘  │
│  [360 min] [12 sessions] [5🔥]  │
│                                  │
│  [Garden Tab View]               │
│  🌱  🌿  🌷  🌸  🌳 🌳 🌳       │
│  (animated, grows with focus)    │
│  "You've grown 3 full trees! 🎉"│
└──────────────────────────────────┘
```