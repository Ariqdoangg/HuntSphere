# 🌐 HuntSphere - GPS-Based Treasure Hunt Platform

<div align="center">

![HuntSphere](https://img.shields.io/badge/HuntSphere-GPS%20Treasure%20Hunt-0f172a?style=for-the-badge&labelColor=0f172a&color=06b6d4)

**A real-time, location-based team-building application where participants compete in GPS-tracked treasure hunts managed by a live facilitator.**

Create hunts. Drop checkpoints. Track teams in real-time.

[Features](#-features) • [Tech Stack](#-tech-stack) • [Installation](#-installation) • [Screenshots](#-screenshots) • [Architecture](#-architecture)

</div>

---

## 🎯 About

HuntSphere digitizes and automates the traditional "explorace" / treasure hunt experience. Facilitators create GPS-based activities with checkpoints and tasks, while participants compete in teams — all tracked in real-time with live scoring.

### The Problem
- Traditional treasure hunts rely on **manual registration & scoring**
- Existing apps are **limited to specific program types**
- No **real-time tracking** of team progress
- Complex setup and coordination

### The Solution
HuntSphere automates the entire flow — from activity creation to team grouping to live scoring. Facilitators manage everything from a dashboard, while participants navigate checkpoints using GPS on their phones.

---

## ✨ Features

### 🎮 Dual Role System

**Facilitator (Admin)**
- Create and configure activities with custom rules
- Drop GPS checkpoints on an interactive map
- Set radius thresholds for geofence triggers
- Assign multiple task types per checkpoint
- Review and approve photo submissions in real-time
- Monitor all teams via live dashboard

**Participant (Player)**
- Join activities using a unique code
- Live selfie capture for identity verification
- Navigate to checkpoints using GPS guidance
- Complete tasks: Quizzes, QR Scans, Photo Challenges
- View real-time leaderboard and team standings

### 📍 GPS Geofencing
- Real-time location tracking using Haversine formula
- Automatic checkpoint detection when within radius
- Haptic feedback on checkpoint arrival
- Tasks unlock only when physically at the location

### 👥 Smart Team Grouping
- Automatic team shuffling when facilitator starts the race
- Groups of 4 (adjusts for remainders — no player left alone)
- Team reveal screen showing teammates' selfies
- Powered by Supabase Edge Functions

### 📸 Multiple Task Types
| Type | Validation |
|------|-----------|
| 📸 Photo Task | Manual (Facilitator reviews) |
| 📍 GPS Task | Automatic (Location verified) |
| 📱 QR Code | Automatic (String matching) |
| ❓ Quiz | Automatic (Database validated) |

### 🏆 Real-time Leaderboard
- Live scoring via Supabase Realtime subscriptions
- Points for checkpoint arrivals + task completions
- Instant updates across all connected devices
- Win logic: Fastest completion or highest score

### 🎨 Dark Gaming Aesthetic
- Navy dark theme with cyan and neon pink accents
- Glow effects and gradient buttons
- Futuristic UI designed for engagement
- Smooth animations and transitions

---

## 🛠 Tech Stack

### Mobile App
| Technology | Purpose |
|-----------|---------|
| **Flutter** | Cross-platform mobile framework |
| **Dart** | Programming language |
| **BLoC Pattern** | State management |
| **Geolocator** | GPS & location services |
| **Google Maps** | Interactive map display |

### Backend
| Technology | Purpose |
|-----------|---------|
| **Supabase** | Backend-as-a-Service |
| **PostgreSQL** | Database with RLS |
| **Supabase Realtime** | Live subscriptions & broadcasts |
| **Supabase Edge Functions** | Serverless logic (Deno) |
| **Supabase Storage** | File storage (selfies & submissions) |

### Architecture
```
├── Flutter App (Cross-platform iOS/Android)
│   ├── BLoC State Management
│   ├── Geolocator (GPS Tracking)
│   ├── Google Maps Integration
│   └── Camera & QR Scanner
├── Supabase Backend
│   ├── PostgreSQL (Database + RLS Policies)
│   ├── Realtime (Live Leaderboard & Updates)
│   ├── Edge Functions (Team Grouping Logic)
│   └── Storage (Selfies & Photo Submissions)
```

---

## 📦 Installation

### Prerequisites
- Flutter SDK 3.x+
- Dart SDK
- Android Studio / VS Code
- Supabase account

### Setup

1. **Clone the repository**
```bash
git clone https://github.com/Ariqdoangg/HuntSphere.git
cd HuntSphere
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Supabase**

Create a Supabase project at [supabase.com](https://supabase.com), then update credentials:

```dart
// lib/core/utils/constants.dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

4. **Run database migrations**

In Supabase SQL Editor, run the migration files from `supabase/migrations/` in order.

5. **Create storage buckets**

Create two buckets in Supabase Storage:
- `selfies` — For participant registration photos
- `submissions` — For task-related uploads

6. **Run the app**
```bash
flutter run
```

---

## 📸 Screenshots

### Welcome & Join
> Dark-themed onboarding with activity code entry
<!-- ![Welcome](screenshots/welcome.png) -->

### Facilitator Dashboard
> Create activities, drop checkpoints, manage teams
<!-- ![Facilitator](screenshots/facilitator.png) -->

### Live Map & GPS Tracking
> Real-time checkpoint navigation with geofencing
<!-- ![Map](screenshots/map.png) -->

### Task Completion
> Photo, Quiz, QR, and GPS task interfaces
<!-- ![Tasks](screenshots/tasks.png) -->

### Leaderboard
> Real-time team rankings and scoring
<!-- ![Leaderboard](screenshots/leaderboard.png) -->

*Replace comments above with actual screenshot images*

---

## 🗄 Database Schema

```
activities
├── id, facilitator_id, name
├── join_code, status, duration
├── start_time, end_time
└── settings, timestamps

checkpoints
├── id, activity_id, name
├── latitude, longitude, radius
├── arrival_points, order_index
└── clue, description, timestamps

tasks
├── id, checkpoint_id, type
├── title, description, points
├── correct_answer, options
└── timestamps

teams
├── id, activity_id, name
├── total_points, finish_time
└── status, timestamps

participants
├── id, user_id, activity_id
├── team_id, name, selfie_url
└── status, timestamps

submissions
├── id, task_id, team_id
├── participant_id, content
├── media_url, status, points
└── reviewed_by, timestamps
```

---

## 🏗 Project Structure

```
huntsphere/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart                  # App configuration
│   │   ├── theme.dart                # Dark gaming theme
│   │   ├── routes.dart               # Navigation routes
│   │   └── bloc_observer.dart        # BLoC debugging
│   ├── core/
│   │   ├── models/
│   │   │   ├── activity_model.dart
│   │   │   ├── participant_model.dart
│   │   │   ├── task_model.dart
│   │   │   └── submission_model.dart
│   │   ├── repositories/
│   │   │   └── activity_repository.dart
│   │   ├── services/
│   │   │   └── session_service.dart
│   │   └── utils/
│   │       └── constants.dart
│   └── features/
│       ├── welcome/screens/
│       │   └── welcome_screen.dart
│       ├── join/screens/
│       │   ├── join_activity_screen.dart
│       │   └── setup_profile_screen.dart
│       ├── facilitator/screens/
│       │   ├── dashboard_screen.dart
│       │   ├── create_activity_screen.dart
│       │   ├── checkpoint_map_screen.dart
│       │   └── approval_queue_screen.dart
│       ├── gameplay/screens/
│       │   ├── map_navigation_screen.dart
│       │   └── checkpoint_screen.dart
│       ├── tasks/screens/
│       │   ├── task_list_screen.dart
│       │   └── photo_task_screen.dart
│       └── leaderboard/screens/
│           └── leaderboard_screen.dart
├── supabase/
│   ├── migrations/
│   │   ├── 20250101000000_initial_schema.sql
│   │   └── 20250101000001_storage_setup.sql
│   └── functions/
│       ├── approve-submission/
│       └── reject-submission/
├── pubspec.yaml
└── README.md
```

---

## 🔄 Application Flow

```
┌─────────────────────────────────────────────────┐
│                  FACILITATOR                     │
│                                                  │
│  Create Activity → Set Checkpoints → Add Tasks   │
│       │                                          │
│       ▼                                          │
│  Share Join Code → Wait for Players              │
│       │                                          │
│       ▼                                          │
│  Start Race → Auto-Group Teams → Monitor Live    │
│       │                                          │
│       ▼                                          │
│  Review Submissions → Approve/Reject → End Race  │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│                  PARTICIPANT                     │
│                                                  │
│  Enter Join Code → Take Selfie → Wait in Lobby   │
│       │                                          │
│       ▼                                          │
│  Team Reveal → Navigate to Checkpoints (GPS)     │
│       │                                          │
│       ▼                                          │
│  Complete Tasks → Submit Answers/Photos          │
│       │                                          │
│       ▼                                          │
│  Track Leaderboard → Finish Race                 │
└─────────────────────────────────────────────────┘
```

---

## 🚀 Key Technical Highlights

- **Real-time GPS Geofencing**: Haversine formula calculates distance to checkpoints, automatically triggering task unlocks with haptic feedback
- **Smart Grouping Algorithm**: Supabase Edge Function shuffles and distributes players into balanced teams with no player left solo
- **Live Data Sync**: Supabase Realtime subscriptions push leaderboard updates instantly to all connected devices
- **Dual Authentication**: Email/password for facilitators, anonymous code-based login for participants
- **Row Level Security**: PostgreSQL RLS policies ensure data isolation between activities and teams
- **Offline-Ready Architecture**: BLoC pattern with repository layer supports graceful offline handling

---

## 📄 License

This project is open-sourced for educational purposes.

---

## 👨‍💻 Author

**Mohammad Ariq Haikal**
- GitHub: [@Ariqdoangg](https://github.com/Ariqdoangg)
- LinkedIn: [ariqhaikal](https://www.linkedin.com/in/ariqhaikal)
- Email: 4riq.haika1@gmail.com

---

<div align="center">

Built with ❤️ using Flutter, Supabase & Google Maps

⭐ Star this repo if you find it useful!

</div>
