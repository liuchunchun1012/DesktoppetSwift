# Change: 个人生活助手功能 - 番茄钟、习惯提醒与语音交互

## Why

当前 DesktoppetSwift 的定位不够清晰，功能主要集中在 AI 对话、翻译和图片分析。经过讨论，我们明确了产品的核心定位：

**个人生活陪伴助手，而非工作效率工具**

核心原则：
1. **个人化** - 关注用户的生活节奏和习惯，而非工作任务
2. **轻量级** - 小功能、小交互、小播报，避免复杂性
3. **本地优先** - 尽量使用系统 API 和本地计算，减少 AI Token 消耗和成本
4. **陪伴感** - 小猫是温暖的朋友，不是冷冰冰的工具

用户希望桌面宠物能够：
- 陪伴日常生活（番茄钟、提醒喝水、久坐提醒）
- 更自然的交互方式（语音输入）
- 跨设备无缝体验（Mac ↔ iPhone）
- 低成本运行（本地功能为主，AI 按需使用）

## What Changes

### 核心新增功能

1. **番茄钟系统**
   - 25 分钟工作 + 5 分钟短休息 + 15 分钟长休息
   - 小猫动画状态切换（工作时安静、休息时活跃）
   - 音效 + 通知提醒
   - 本地统计和记录

2. **习惯提醒系统**
   - 喝水提醒（可配置间隔，默认 1 小时）
   - 久坐提醒（检测鼠标/键盘活动，默认 50 分钟）
   - 眼睛休息提醒（20-20-20 规则）
   - 本地规则引擎，零 Token

3. **语音交互（STT）**
   - 快捷键录音（Cmd+Shift+V）
   - 使用 macOS Speech Framework 或 OpenAI Whisper
   - 语音命令识别（本地规则）
   - TTS 作为可选功能（默认关闭，用音效代替）

4. **跨设备同步基础**
   - iCloud CloudKit 同步数据（番茄钟记录、习惯追踪）
   - 为未来 iOS 版本和 Handoff 做准备
   - 本地优先，离线可用

### 技术策略调整

- **本地 API 优先**：使用 macOS 系统框架（Timer, UserNotifications, Speech, Vision）
- **AI 按需调用**：优先使用 Ollama 本地模型，云端 API 仅在必要时使用
- **规则引擎**：简单的提醒和命令识别使用本地规则，不调用 AI
- **成本意识**：为用户节省 Token，提供完全免费的本地体验

### 明确不做的功能

- ❌ **IDE 伴侣集成** - 过于冗余，不符合个人生活助手定位
- ❌ **项目管理功能** - 不做工作效率工具
- ❌ **代码分析** - 专注于生活而非开发

## Impact

### 新增能力模块

- **pomodoro** - 番茄钟核心功能
- **habit-reminders** - 习惯提醒系统
- **voice-interaction** - 语音交互（替代之前的 `add-voice-chat`）
- **cross-device-sync** - 跨设备数据同步基础

### 影响的现有代码

- `ContentView.swift` - 添加番茄钟状态管理和动画切换
- `StatusBarController.swift` - 添加番茄钟控制菜单
- `UserSettings.swift` - 添加番茄钟和提醒相关设置
- `AIProviderManager.swift` - 添加本地命令识别，减少不必要的 AI 调用

### 新增文件

- `PomodoroTimer.swift` - 番茄钟计时器
- `HabitReminderManager.swift` - 习惯提醒管理
- `VoiceRecorder.swift` - 语音录制
- `SpeechToTextService.swift` - STT 服务抽象
- `LocalCommandParser.swift` - 本地命令识别
- `SoundEffectPlayer.swift` - 音效播放
- `CloudSyncManager.swift` - iCloud 同步

### 依赖和权限

- 麦克风权限（语音录制）
- iCloud 权限（数据同步）
- 通知权限（提醒功能）

### 用户体验变化

- 小猫不再只是对话工具，而是生活伙伴
- 更多主动交互（定时提醒）
- 更低的使用成本（本地功能为主）
- 为跨设备体验铺路

### 与现有功能的协同

- 现有 AI 对话、翻译、图片分析功能保持不变
- 番茄钟休息时可触发 AI 对话（可选）
- 语音输入可用于现有所有功能
- 统一的设置界面管理所有功能
