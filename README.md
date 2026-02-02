<div align="center">

# 🎯 HuntSphere

**GPS-Based Treasure Hunt Platform**

<p>
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white" />
  <img src="https://img.shields.io/badge/Google_Maps-4285F4?style=for-the-badge&logo=googlemaps&logoColor=white" />
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" />
</p>

A **GPS-powered digital explorace platform** that enables facilitators to create, manage, and monitor treasure hunt activities in real-time with automatic team formation, geofencing checkpoints, and live leaderboards.

[Getting Started](#-getting-started) · [Features](#-key-features) · [Tech Stack](#%EF%B8%8F-tech-stack) · [Screenshots](#-screenshots)

</div>

---

## 📸 Screenshots

<div align="center">

### 🧑‍💼 Facilitator Side

<table>
  <tr>
    <td align="center"><b>Dashboard</b></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/facilitator_dashboard.jpg" width="300" /></td>
  </tr>
</table>

### 🎮 Participant Side

<table>
  <tr>
    <td align="center"><b>Join Activity</b></td>
    <td align="center"><b>Waiting Lobby</b></td>
  </tr>
  <tr>
    <td><img src="screenshots/participant_join.jpg" width="300" /></td>
    <td><img src="screenshots/participant_lobby.jpg" width="300" /></td>
  </tr>
  <tr>
    <td align="center" colspan="2"><b>Game Map with GPS Tracking</b></td>
  </tr>
  <tr>
    <td align="center" colspan="2"><img src="screenshots/game_map.jpg" width="300" /></td>
  </tr>
</table>

</div>

---

## 🛠️ Tech Stack

| Layer | Technology | Role |
| :--- | :--- | :--- |
| **Mobile App** | Flutter (Dart) | Cross-platform app for Facilitators & Participants |
| **Backend** | Supabase (PostgreSQL) | Real-time database, authentication & storage |
| **Maps** | Google Maps API | GPS tracking, geofencing & checkpoint markers |
| **Auth** | Supabase Auth | Email/password authentication with role management |
| **Real-time** | Supabase Realtime | Live leaderboard updates & lobby sync |

### Architecture

```
┌──────────────────────┐
│   Flutter Mobile App  │
│                       │
│  ┌─────────────────┐  │
│  │  Facilitator    │  │     ┌──────────────────────┐
│  │  • Create Game  │  │────▶│                      │
│  │  • Monitor Live │  │     │   Supabase Backend   │
│  │  • Review Tasks │  │◀────│                      │
│  └─────────────────┘  │     │  • PostgreSQL DB     │
│                       │     │  • Auth (Sanctum)    │
│  ┌─────────────────┐  │     │  • Realtime Engine   │
│  │  Participant    │  │────▶│  • Storage (Photos)  │
│  │  • Join Code    │  │     │                      │
│  │  • GPS Navigate │  │◀────│                      │
│  │  • Answer Tasks │  │     └──────────┬───────────┘
│  └─────────────────┘  │                │
└──────────────────────┘     ┌──────────▼───────────┐
                              │   Google Maps API    │
                              │  • GPS Tracking      │
                              │  • Geofencing        │
                              │  • Map Markers       │
                              └──────────────────────┘
```

---

## ✨ Key Features

### 🧑‍💼 Facilitator
- **Create Activity** — Set name, duration, and get auto-generated join code
- **Setup Checkpoints** — Pin GPS locations on map with custom radius & points
- **Add Tasks** — Quiz (auto-graded), Photo (manual review), QR scan per checkpoint
- **Lobby Management** — Real-time participant list with live count
- **Auto Team Formation** — System automatically divides participants into teams (3-5 per team)
- **Live Monitoring** — Real-time leaderboard & progress tracking
- **Photo Review** — Approve/reject photo submissions from participants

### 🎮 Participant
- **Quick Join** — Enter 6-character join code to enter activity
- **Waiting Lobby** — See other participants, wait for facilitator to start
- **Team Reveal** — Auto-assigned team with emoji & team name
- **GPS Navigation** — Google Maps with checkpoint markers & distance tracking
- **Geofencing** — Checkpoints auto-unlock when within radius (50m default)
- **Complete Tasks** — Answer quiz, take photos, scan QR codes
- **Live Leaderboard** — Real-time ranking with team highlighting
- **Progress Tracker** — Visual progress of completed checkpoints

### 🔐 Admin Verification
- **Manual Verification** — Admin verifies and approves new facilitators via Supabase backend
- **Role-Based Access** — Only verified facilitators can create and manage activities
- **Secure Registration** — Users register through Supabase Auth, admin grants facilitator access

---

## 🗄️ Database Schema

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  activities  │     │ checkpoints  │     │    tasks     │
├──────────────┤     ├──────────────┤     ├──────────────┤
│ id           │◄────│ activity_id  │◄────│ checkpoint_id│
│ name         │     │ name         │     │ title        │
│ join_code    │     │ latitude     │     │ type         │
│ status       │     │ longitude    │     │ points       │
│ duration_min │     │ radius_meters│     │ question     │
│ created_by   │     │ arrival_pts  │     │ answer       │
└──────────────┘     │ sequence     │     └──────────────┘
                     └──────────────┘
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    teams     │     │ participants │     │team_progress │
├──────────────┤     ├──────────────┤     ├──────────────┤
│ id           │     │ id           │     │ team_id      │
│ activity_id  │     │ team_id      │     │ checkpoint_id│
│ team_name    │     │ name         │     │ arrived_at   │
│ emoji        │     │ user_id      │     │ status       │
└──────────────┘     └──────────────┘     └──────────────┘

┌──────────────┐     ┌──────────────┐
│ facilitators │     │task_submissions│
├──────────────┤     ├──────────────┤
│ id           │     │ team_id      │
│ user_id      │     │ task_id      │
│ name         │     │ answer       │
│ email        │     │ is_correct   │
│ organization │     │ points_earned│
└──────────────┘     └──────────────┘
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x
- Android Studio / VS Code
- Google Maps API Key
- Supabase Account (Free tier)

### 1. Clone the repo

```bash
git clone https://github.com/Ariqdoangg/HuntSphere.git
cd HuntSphere
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Supabase

Create `lib/core/constants/supabase_constants.dart`:

```dart
class SupabaseConstants {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

### 4. Configure Google Maps

Add your API key to:

**Android:** `android/app/src/main/AndroidManifest.xml`
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

### 5. Run the app

```bash
flutter run
```

---

## 📁 Project Structure

```
HuntSphere/
├── lib/
│   ├── core/
│   │   └── constants/          # Supabase config, app constants
│   ├── features/
│   │   ├── facilitator/
│   │   │   └── screens/
│   │   │       ├── facilitator_auth_screen.dart
│   │   │       ├── facilitator_dashboard.dart
│   │   │       ├── checkpoint_setup_screen.dart
│   │   │       ├── task_management_screen.dart
│   │   │       ├── lobby_screen.dart
│   │   │       └── facilitator_leaderboard_screen.dart
│   │   ├── participant/
│   │   │   └── screens/
│   │   │       ├── participant_join_screen.dart
│   │   │       ├── waiting_lobby_screen.dart
│   │   │       ├── team_reveal_screen.dart
│   │   │       ├── game_map_screen.dart
│   │   │       ├── checkpoint_tasks_screen.dart
│   │   │       ├── quiz_task_screen.dart
│   │   │       ├── photo_task_screen.dart
│   │   │       ├── qr_task_screen.dart
│   │   │       ├── leaderboard_screen.dart
│   │   │       └── results_screen.dart
│   │   └── shared/
│   │       └── models/         # ActivityModel, CheckpointModel, TaskModel
│   ├── services/
│   │   └── supabase_service.dart
│   └── main.dart
├── android/                    # Android platform config
├── ios/                        # iOS platform config
├── screenshots/                # App screenshots
└── README.md
```

---

## 🎯 How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    FACILITATOR FLOW                          │
│                                                             │
│  Create Activity → Setup Checkpoints → Add Tasks → Lobby   │
│       │                                              │      │
│       ▼                                              ▼      │
│  Join Code Generated                    Start & Form Teams  │
│                                              │              │
│                                              ▼              │
│                                      Monitor Game Live      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    PARTICIPANT FLOW                          │
│                                                             │
│  Enter Join Code → Waiting Lobby → Team Reveal → Game Map  │
│                                                      │      │
│                                                      ▼      │
│                              Navigate → Geofence Unlock     │
│                                              │              │
│                                              ▼              │
│                                    Complete Tasks → Points  │
│                                              │              │
│                                              ▼              │
│                                      Live Leaderboard       │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Geofencing System

HuntSphere uses **GPS-based geofencing** to verify participant location:

- **Haversine Formula** — Calculates distance between player and checkpoint
- **Default Radius** — 50 meters (customizable per checkpoint)
- **Auto Detection** — GPS checks every 5 seconds
- **Manual Check-in** — Backup button when within radius
- **Visual Feedback** — Banner turns green when in range

```dart
// Geofence check (simplified)
double distance = haversine(playerLat, playerLng, checkpointLat, checkpointLng);
if (distance <= checkpoint.radius) {
    // Unlock checkpoint & show tasks!
}
```

---

## 👨‍💻 Author

**Ariq Haikal** — Final-year Software Engineering Student @ UPSI

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://linkedin.com/in/ariqhaikal)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)](https://github.com/Ariqdoangg)

---

<div align="center">
  <sub>Built with ❤️ for GPS-powered team building activities</sub>
</div>
