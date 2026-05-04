# Fitness Timer Pro

<p align="center">
  <strong>English</strong> | <a href="#中文说明">中文说明</a>
</p>

A native iOS fitness timer app built with SwiftUI, featuring an AI-powered planning assistant, multi-phase workout timer, and calendar-based training management.

## Features

- **Multi-Phase Timer** — Prepare (orange) → Work (green) → Rest (blue) → Rest End, with reference-date precision and count-up unlimited mode
- **Free & Planned Training** — Quick-start free training with unlimited time, or plan exercises with specific sets, durations, and rest periods
- **Weekly Repeat** — Schedule recurring exercises on specific weekdays
- **Year & Month Calendar** — Full-year overview with completion status, drill down to daily exercise lists grouped by muscle group
- **Muscle Tags** — Categorize exercises by body part: Chest, Back, Legs, Shoulders, Arms, Abs
- **AI Planning Assistant** — Chat-based AI that can query your training data, create/edit/delete exercises, and propose workout plans with user confirmation
  - 11 providers: OpenAI, Claude, Gemini, Doubao, Qwen, Hunyuan, Moonshot, Zhipu, MiniMax, DeepSeek, Custom
  - Streaming responses with thinking/reasoning support
  - Tool calling with confirmation workflow
  - cURL import for custom provider setup
- **Audio System** — Countdown beeps, phase transition sounds, silent background audio to prevent iOS suspension
- **Confetti Celebration** — Workout completion animation
- **Font Selection** — 5 timer display fonts (BebasNeue, SF Pro, SF Rounded, SF Compact, Oswald)
- **Dark Mode** — Forced dark theme throughout
- **Privacy** — API keys stored in iOS Keychain; privacy manifest included

## Project Structure

```
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

- iOS 16.0+
- Xcode 15+
- Swift 5.9+

## How to Run

1. Clone the repository
2. Open `FitnessTimerPro.xcodeproj` in Xcode
3. Select a simulator (e.g., iPhone 15 Pro) or your device
4. Build and run (⌘R)

## Dependencies

- [GRDB.swift](https://github.com/groue/GRDB.swift) — SQLite database
- [ConfettiSwiftUI](https://github.com/simibac/ConfettiSwiftUI) — Celebration effects
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) — Markdown rendering in AI chat

---

<a id="中文说明"></a>

# Fitness Timer Pro

<p align="center">
  <a href="#fitness-timer-pro">English</a> | <strong>中文说明</strong>
</p>

一款基于 SwiftUI 的 iOS 原生健身计时器应用，内置 AI 规划助手、多阶段训练计时器和日历训练管理。

## 功能特性

- **多阶段计时器** — 准备（橙色）→ 训练（绿色）→ 休息（蓝色）→ 休息结束，基于参考日期的精确计时，支持不限时正计时模式
- **自由训练与计划训练** — 快速开始不限时自由训练，或按计划执行指定组数、时长和休息时间的训练
- **每周重复** — 在指定工作日自动安排重复训练
- **年历与月历** — 全年总览显示完成状态，下钻到按肌群分组的每日训练列表
- **肌群标签** — 按部位分类训练：胸、背、腿、肩、手臂、腹
- **AI 规划助手** — 基于对话的 AI 助手，可查询训练数据、创建/编辑/删除训练，并在用户确认后执行
  - 支持 11 家服务商：OpenAI、Claude、Gemini、豆包、通义千问、腾讯混元、月之暗面(Kimi)、智谱(GLM)、MiniMax、DeepSeek、自定义
  - 流式响应，支持思考/推理过程展示
  - 工具调用配合用户确认流程
  - 支持导入 cURL 命令快速配置自定义服务商
- **音频系统** — 倒计时提示音、阶段转换音效、静音后台音频防止 iOS 挂起
- **完成庆祝** — 训练完成时的彩纸动画
- **字体选择** — 5 种计时器显示字体（BebasNeue、SF Pro、SF Rounded、SF Compact、Oswald）
- **深色模式** — 全局强制深色主题
- **隐私安全** — API 密钥存储于 iOS Keychain；包含隐私清单文件

## 项目结构

```
FitnessTimerPro/
├── FitnessTimerProApp.swift        # 应用入口
├── Models.swift                    # 数据模型（Exercise、WorkoutState 等）
├── Utils.swift                     # 颜色扩展、KeychainHelper
├── Utils/
│   └── FernetDecryptor.swift       # Fernet 令牌解密工具
├── ViewModels/
│   ├── WorkoutManager.swift        # 核心状态与计时器逻辑
│   ├── AIService.swift             # 多服务商 AI 流式服务
│   └── AIToolManager.swift         # AI 工具执行与确认
├── Views/
│   ├── ContentView.swift           # 底部标签栏容器
│   ├── CalendarView.swift          # 年历/月历与训练列表
│   ├── TimerView.swift             # 训练计时器界面
│   ├── AddExerciseView.swift       # 添加/编辑训练表单
│   ├── SettingsView.swift          # 设置与默认值
│   ├── AIChatView.swift            # AI 对话界面
│   ├── AIInputOverlay.swift        # 浮动 AI 输入栏
│   ├── AISettingsView.swift        # AI 服务商配置
│   ├── AIActionConfirmationView.swift  # AI 操作确认
│   ├── PrivacyProtocolView.swift   # 隐私政策
│   ├── StandardDialog.swift        # 通用确认对话框
│   └── Components/
│       ├── MarkdownView.swift      # 深色主题 Markdown 渲染
│       └── ToastView.swift         # Toast 通知
├── DataLayer/
│   ├── DatabaseManager.swift       # GRDB SQLite 建库与迁移
│   ├── ExerciseStore.swift         # 训练记录增删改查
│   ├── WeeklyRepeatStore.swift     # 每周重复增删改查
│   └── ChatMessageStore.swift      # 聊天消息持久化
├── Resources/                      # 音频文件（倒计时、完成音效等）
├── fonts/                          # 自定义字体（BebasNeue、Oswald 等）
└── Assets.xcassets/                # 应用图标与图片
```

## 环境要求

- iOS 16.0+
- Xcode 15+
- Swift 5.9+

## 运行方式

1. 克隆仓库
2. 使用 Xcode 打开 `FitnessTimerPro.xcodeproj`
3. 选择模拟器（如 iPhone 15 Pro）或真机
4. 构建并运行（⌘R）

## 依赖

- [GRDB.swift](https://github.com/groue/GRDB.swift) — SQLite 数据库
- [ConfettiSwiftUI](https://github.com/simibac/ConfettiSwiftUI) — 庆祝动效
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) — AI 对话中的 Markdown 渲染
