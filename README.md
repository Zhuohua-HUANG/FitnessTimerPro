<h1 align="center">
  Fitness Timer Pro<br>
</h1>
<div align="center">
<img src="https://img.shields.io/badge/platform-iOS-blue"/>
<img src="https://img.shields.io/badge/SwiftUI-iOS%2016%2B-orange"/>
<img src="https://img.shields.io/badge/App%20Store-Available-brightgreen"/>
</div>
<div align="center">

  [English](README.md) | [简体中文](README.zh-CN.md)
</div>
<p align="center">
A native iOS fitness timer app, featuring an AI-powered planning assistant and workout timer.
</p>
<p align="center">
  <a href="https://apps.apple.com/cn/app/%E5%81%A5%E8%BA%AB%E8%AE%A1%E6%97%B6%E5%99%A8-%E8%AE%AD%E7%BB%83%E8%AE%A1%E6%97%B6-ai-%E8%A7%84%E5%88%92%E5%8A%A9%E6%89%8B/id6760479130">
    <img src="https://img.shields.io/badge/Download-App%20Store-blue?logo=apple&logoColor=white"/>
  </a>
</p>

---

## Features

* Multi-Phase Timer: Prepare (orange) → Work (green) → Rest (blue) → Rest End, with reference-date precision and count-up unlimited mode;

* Free & Planned Training: Quick-start free training with unlimited time, or plan exercises with specific sets, durations, and rest periods;

* Weekly Repeat: Schedule recurring exercises on specific weekdays;

* Year & Month Calendar: Full-year overview with completion status, drill down to daily exercise lists grouped by muscle group;

* Muscle Tags: Categorize exercises by body part — Chest, Back, Legs, Shoulders, Arms, Abs;

* AI Planning Assistant: Chat-based AI that can query your training data, create/edit/delete exercises, and propose workout plans with user confirmation;
  * 11 providers: OpenAI, Claude, Gemini, Doubao, Qwen, Hunyuan, Moonshot, Zhipu, MiniMax, DeepSeek, Custom;
  * Streaming responses with thinking/reasoning support;
  * Tool calling with confirmation workflow;
  * cURL import for custom provider setup;

* Audio System: Countdown beeps, phase transition sounds, silent background audio to prevent iOS suspension;

* Confetti Celebration: Workout completion animation;

* Font Selection: 5 timer display fonts (BebasNeue, SF Pro, SF Rounded, SF Compact, Oswald);

* Dark Mode: Forced dark theme throughout;

* Privacy: API keys stored in iOS Keychain; privacy manifest included;

## Project Structure

```text
FitnessTimerPro/
├── FitnessTimerProApp.swift        # App entry point
├── Models.swift                    # Data models (Exercise, WorkoutState, etc.)
├── Utils.swift                     # Color extensions, KeychainHelper
├── Utils/
│   └── FernetDecryptor.swift       # Fernet token decryption utility
├── ViewModels/
│   ├── WorkoutManager.swift        # Central state & timer logic
│   ├── AIService.swift             # Multi-provider AI streaming service
│   └── AIToolManager.swift         # AI tool execution & confirmation
├── Views/
│   ├── ContentView.swift           # Tab bar container
│   ├── CalendarView.swift          # Year/Month calendar & exercise list
│   ├── TimerView.swift             # Workout timer screen
│   ├── AddExerciseView.swift       # Add/Edit exercise form
│   ├── SettingsView.swift          # Settings & defaults
│   ├── AIChatView.swift            # AI chat interface
│   ├── AIInputOverlay.swift        # Floating AI input bar
│   ├── AISettingsView.swift        # AI provider configuration
│   ├── AIActionConfirmationView.swift  # AI action confirmation
│   ├── PrivacyProtocolView.swift   # Privacy policy
│   ├── StandardDialog.swift        # Reusable confirmation dialog
│   └── Components/
│       ├── MarkdownView.swift      # Dark-themed Markdown rendering
│       └── ToastView.swift         # Toast notifications
├── DataLayer/
│   ├── DatabaseManager.swift       # GRDB SQLite setup & migration
│   ├── ExerciseStore.swift         # Exercise CRUD
│   ├── WeeklyRepeatStore.swift     # Weekly repeat CRUD
│   └── ChatMessageStore.swift      # Chat message persistence
├── Resources/                      # Audio files (countdown, finish sounds)
├── fonts/                          # Custom fonts (BebasNeue, Oswald, etc.)
└── Assets.xcassets/                # App icons & images
```

## Requirements

* iOS 16.0+
* Xcode 15+
* Swift 5.9+

## How to Run

1. Clone the repository;
2. Open `FitnessTimerPro.xcodeproj` in Xcode;
3. Select a simulator (e.g., iPhone 15 Pro) or your device;
4. Build and run (⌘R);

## Dependencies

* [GRDB.swift](https://github.com/groue/GRDB.swift) — SQLite database;
* [ConfettiSwiftUI](https://github.com/simibac/ConfettiSwiftUI) — Celebration effects;
* [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) — Markdown rendering in AI chat;
