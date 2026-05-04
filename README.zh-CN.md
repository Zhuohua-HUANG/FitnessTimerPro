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
一款基于 SwiftUI 的 iOS 原生健身计时器应用，内置 AI 规划助手、多阶段训练计时器和日历训练管理。
</p>
<p align="center">
  <a href="https://apps.apple.com/cn/app/%E5%81%A5%E8%BA%AB%E8%AE%A1%E6%97%B6%E5%99%A8-%E8%AE%AD%E7%BB%83%E8%AE%A1%E6%97%B6-ai-%E8%A7%84%E5%88%92%E5%8A%A9%E6%89%8B/id6760479130">
    <img src="https://img.shields.io/badge/Download-App%20Store-blue?logo=apple&logoColor=white"/>
  </a>
</p>

---

## 功能特性

* 多阶段计时器：准备（橙色）→ 训练（绿色）→ 休息（蓝色）→ 休息结束，基于参考日期的精确计时，支持不限时正计时模式；

* 自由训练与计划训练：快速开始不限时自由训练，或按计划执行指定组数、时长和休息时间的训练；

* 每周重复：在指定工作日自动安排重复训练；

* 年历与月历：全年总览显示完成状态，下钻到按肌群分组的每日训练列表；

* 肌群标签：按部位分类训练——胸、背、腿、肩、手臂、腹；

* AI 规划助手：基于对话的 AI 助手，可查询训练数据、创建/编辑/删除训练，并在用户确认后执行；
  * 支持 11 家服务商：OpenAI、Claude、Gemini、豆包、通义千问、腾讯混元、月之暗面(Kimi)、智谱(GLM)、MiniMax、DeepSeek、自定义；
  * 流式响应，支持思考/推理过程展示；
  * 工具调用配合用户确认流程；
  * 支持导入 cURL 命令快速配置自定义服务商；

* 音频系统：倒计时提示音、阶段转换音效、静音后台音频防止 iOS 挂起；

* 完成庆祝：训练完成时的彩纸动画；

* 字体选择：5 种计时器显示字体（BebasNeue、SF Pro、SF Rounded、SF Compact、Oswald）；

* 深色模式：全局强制深色主题；

* 隐私安全：API 密钥存储于 iOS Keychain；包含隐私清单文件；

## 项目结构

```text
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

* iOS 16.0+
* Xcode 15+
* Swift 5.9+

## 运行方式

1. 克隆仓库；
2. 使用 Xcode 打开 `FitnessTimerPro.xcodeproj`；
3. 选择模拟器（如 iPhone 15 Pro）或真机；
4. 构建并运行（⌘R）；

## 依赖

* [GRDB.swift](https://github.com/groue/GRDB.swift) — SQLite 数据库；
* [ConfettiSwiftUI](https://github.com/simibac/ConfettiSwiftUI) — 庆祝动效；
* [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) — AI 对话中的 Markdown 渲染；
