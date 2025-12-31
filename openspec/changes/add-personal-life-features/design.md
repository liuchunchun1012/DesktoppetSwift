# 技术设计 - 个人生活助手功能

## Context

这是对 DesktoppetSwift 的重大功能扩展，从单纯的 AI 对话工具转变为生活陪伴助手。需要在保持轻量级的前提下，添加多个本地功能模块。

**关键约束**：
- 必须保持低资源消耗（内存 < 50MB，CPU < 1%）
- 优先使用本地 API，减少网络依赖和成本
- 离线可用性（核心功能不依赖网络）
- 为未来 iOS 版本预留架构空间

**利益相关者**：
- 用户：希望低成本、轻量级、有陪伴感的助手
- 开发者：需要清晰的模块划分和可维护性

## Goals / Non-Goals

### Goals
1. ✅ 实现完整的番茄钟系统（计时、统计、提醒）
2. ✅ 实现习惯提醒（喝水、久坐、眼睛休息）
3. ✅ 实现语音输入（STT）和本地命令识别
4. ✅ 建立 iCloud 同步基础架构
5. ✅ 保持应用轻量级和高性能
6. ✅ 尽可能减少 Token 消耗

### Non-Goals
- ❌ 完整的 iOS App（本阶段只做数据同步基础）
- ❌ TTS 语音输出（作为可选功能，默认关闭）
- ❌ IDE 集成功能（明确不做）
- ❌ 复杂的 AI 分析（保持简单）
- ❌ 在线协作功能

## Decisions

### 决策 1：本地优先架构

**选择**：核心功能完全本地化，AI 仅用于对话和图片分析

**理由**：
- 用户希望低成本运行（减少 Token 花费）
- 提高响应速度（本地处理更快）
- 离线可用性（网络中断也能用）
- 隐私友好（数据不离开设备）

**实现**：
```swift
// 本地功能（零 Token）
- 番茄钟：使用 Foundation.Timer
- 提醒：使用 UserNotifications.UNUserNotificationCenter
- 语音识别：使用 Speech.SFSpeechRecognizer（macOS 本地）
- 命令识别：本地正则匹配和规则引擎

// AI 功能（按需 Token）
- 仅在用户主动触发对话时调用
- 优先使用 Ollama 本地模型
- 云端 API 仅用于复杂任务
```

### 决策 2：音效 + 动画代替 TTS

**选择**：默认使用音效和动画反馈，TTS 作为可选功能

**理由**：
- 用户反馈："小宠物张口说话怪怪的"
- 音效更可爱、更符合宠物特性
- 避免 TTS API 成本（云端）或质量问题（本地）
- 更快的响应（音效播放即时）

**实现**：
```swift
enum SoundEffect {
    case bell         // 铃铛声 - 提醒
    case meow         // 喵喵叫 - 欢迎、庆祝
    case complete     // 完成音 - 番茄钟结束
    case gentle       // 柔和提示音 - 休息提醒
}

// 可选 TTS（设置中关闭）
struct TTSSettings {
    var enabled: Bool = false  // 默认关闭
    var voice: String = "com.apple.voice.compact.zh-CN.Tingting"
}
```

### 决策 3：单例管理器模式

**选择**：为番茄钟、提醒、语音使用单例管理器

**理由**：
- 全局状态需要统一管理（番茄钟状态、提醒队列）
- 避免重复实例（资源节约）
- 便于跨组件通信（SwiftUI + AppKit）

**实现**：
```swift
class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()
    @Published var state: PomodoroState = .idle
    @Published var timeRemaining: TimeInterval = 0
    @Published var todayCount: Int = 0
}

class HabitReminderManager {
    static let shared = HabitReminderManager()
    func scheduleReminder(_ type: ReminderType, interval: TimeInterval)
}

class VoiceManager: ObservableObject {
    static let shared = VoiceManager()
    func startRecording(completion: @escaping (String?) -> Void)
}
```

### 决策 4：iCloud CloudKit 同步

**选择**：使用 CloudKit 私有数据库同步用户数据

**理由**：
- Apple 原生方案，免费（用户 iCloud 配额）
- 支持 macOS 和 iOS
- 自动冲突解决
- 符合隐私要求（数据在用户 iCloud）

**数据模型**：
```swift
// CKRecord 类型
- PomodoroSession: 每个番茄钟会话
  - startTime: Date
  - duration: Int (分钟)
  - completed: Bool

- HabitLog: 习惯追踪记录
  - type: String (water, sitting, eye)
  - timestamp: Date
  - acknowledged: Bool

- Settings: 用户设置
  - pomodoroWorkDuration: Int
  - pomodoroShortBreak: Int
  - pomodoroLongBreak: Int
  - reminderIntervals: [String: Int]
```

**同步策略**：
- 写入时立即同步到 iCloud
- 启动时拉取最新数据
- 冲突解决：最新时间戳优先
- 离线队列：网络恢复后自动同步

### 决策 5：本地命令识别规则引擎

**选择**：使用正则表达式和关键词匹配识别常用命令

**理由**：
- 避免简单命令调用 AI（省 Token）
- 响应速度快（毫秒级）
- 可扩展性好（添加新命令容易）
- 离线可用

**命令列表**：
```swift
enum VoiceCommand: String, CaseIterable {
    case startPomodoro = "开始番茄钟|开始工作|专注"
    case pausePomodoro = "暂停|休息一下"
    case stopPomodoro = "停止|结束"
    case todayStats = "今天完成了|今天统计|今天几个"
    case drinkWater = "提醒喝水|喝水提醒"

    func matches(_ text: String) -> Bool {
        let patterns = self.rawValue.split(separator: "|")
        return patterns.contains { text.contains($0) }
    }
}

// 使用示例
func parseVoiceInput(_ text: String) -> VoiceCommand? {
    return VoiceCommand.allCases.first { $0.matches(text) }
}
```

**降级策略**：
- 无法匹配本地命令 → 调用 AI 处理
- AI 识别为功能请求 → 执行并学习（可选）
- 普通对话 → 正常 AI 回复

## Architecture

### 模块划分

```
┌─────────────────────────────────────────┐
│          ContentView (UI Layer)         │
│   - 显示小猫动画                          │
│   - 显示聊天气泡                          │
│   - 显示番茄钟状态                        │
└──────────────┬──────────────────────────┘
               │
       ObservableObject
               │
┌──────────────┴──────────────────────────┐
│       Managers (Business Logic)         │
├─────────────────────────────────────────┤
│  PomodoroManager                        │
│  - Timer 管理                            │
│  - 状态机（idle/working/break）          │
│  - 统计计算                              │
├─────────────────────────────────────────┤
│  HabitReminderManager                   │
│  - 调度提醒                              │
│  - 检测用户活动                          │
│  - 记录响应                              │
├─────────────────────────────────────────┤
│  VoiceManager                           │
│  - 录音控制                              │
│  - STT 调用                              │
│  - 命令识别                              │
├─────────────────────────────────────────┤
│  CloudSyncManager                       │
│  - CloudKit 操作                         │
│  - 冲突解决                              │
│  - 离线队列                              │
└──────────────┬──────────────────────────┘
               │
          依赖
               │
┌──────────────┴──────────────────────────┐
│     Services (Infrastructure)           │
├─────────────────────────────────────────┤
│  SoundEffectPlayer                      │
│  - 播放音效                              │
│  - 音效缓存                              │
├─────────────────────────────────────────┤
│  LocalCommandParser                     │
│  - 正则匹配                              │
│  - 命令路由                              │
├─────────────────────────────────────────┤
│  UserActivityMonitor                    │
│  - 鼠标/键盘事件监听                      │
│  - 空闲时间计算                          │
└─────────────────────────────────────────┘
```

### 数据流

```
用户语音输入
  → VoiceManager.startRecording()
  → SFSpeechRecognizer 转文字
  → LocalCommandParser.parse()
    ├─ 匹配成功 → 执行本地命令 (0 Token)
    └─ 匹配失败 → AIProviderManager.chat() (消耗 Token)

番茄钟流程
  → PomodoroManager.start()
  → Timer 每秒更新 timeRemaining
  → 状态变化 → 动画切换 (ContentView)
  → 完成时 → SoundEffectPlayer.play(.complete)
           → CloudSyncManager.saveSession()
           → 本地统计更新

习惯提醒流程
  → HabitReminderManager.scheduleReminder()
  → UserActivityMonitor 检测活动
  → 定时触发 → 显示气泡提示 + 音效
              → 用户确认 → 记录到 CloudKit
```

## Risks / Trade-offs

### 风险 1：语音识别准确度

**风险**：macOS 本地 Speech Framework 中文识别不如云端

**缓解**：
- 提供 OpenAI Whisper 作为备选（用户可选）
- 显示识别文本，允许用户修正
- 收集常见错误，优化命令匹配逻辑

### 风险 2：iCloud 同步冲突

**风险**：多设备同时修改可能导致数据丢失

**缓解**：
- 使用 CKRecord 的 `modificationDate` 最新优先
- 关键数据（番茄钟计数）使用原子操作
- 提供手动刷新和冲突查看功能

### 风险 3：资源消耗

**风险**：Timer + 语音 + 监听可能增加 CPU/内存

**缓解**：
- Timer 使用合理间隔（1 秒，不用毫秒）
- 语音录制仅在按键时激活
- 活动监听使用系统 API（NSEvent），不轮询
- 性能测试：< 50MB 内存，< 1% CPU

### Trade-off 1：本地 vs 云端智能

**选择**：优先本地规则，降低智能程度

**优点**：
- 成本低、速度快、离线可用

**缺点**：
- 命令识别不如 AI 灵活
- 无法理解复杂语义

**接受理由**：
- 核心功能（番茄钟、提醒）是确定性的，不需要 AI
- 用户明确要求减少 Token 消耗
- 可通过后续学习扩展命令库

### Trade-off 2：音效 vs TTS

**选择**：默认音效，TTS 可选

**优点**：
- 更可爱、更快、成本低

**缺点**：
- 无法传递复杂信息（如具体统计）
- 对视障用户不友好

**接受理由**：
- 用户反馈偏好音效
- 可通过文字气泡补充信息
- TTS 作为辅助功能保留

## Migration Plan

### 阶段 1：新功能开发（不影响现有）

1. 新增 Manager 类（独立模块）
2. 新增 UI 组件（番茄钟状态显示）
3. 新增设置页（Pomodoro & Reminders 标签）
4. 不修改现有 AI 对话、翻译、图片分析逻辑

### 阶段 2：集成和测试

1. 在 ContentView 添加番茄钟状态观察
2. 在 StatusBarController 添加快捷菜单
3. 集成语音到现有快捷键系统
4. 测试所有功能互不干扰

### 阶段 3：数据迁移

1. 用户首次启动新版本
2. 初始化 CloudKit schema
3. 本地数据（如有）迁移到 CloudKit
4. 显示功能介绍引导

### 回滚计划

- 番茄钟/提醒功能可单独禁用（设置开关）
- CloudKit 同步失败降级为纯本地
- 语音识别失败降级为文字输入
- 所有新功能对现有功能零影响

## Implementation Notes

### 文件组织

```
Sources/DesktoppetSwift/
├── Pomodoro/
│   ├── PomodoroManager.swift
│   ├── PomodoroState.swift
│   └── PomodoroView.swift
├── Habits/
│   ├── HabitReminderManager.swift
│   ├── ReminderType.swift
│   └── UserActivityMonitor.swift
├── Voice/
│   ├── VoiceManager.swift
│   ├── SpeechToTextService.swift
│   ├── LocalCommandParser.swift
│   └── VoiceCommand.swift
├── CloudSync/
│   ├── CloudSyncManager.swift
│   └── CloudKitModels.swift
├── Utilities/
│   └── SoundEffectPlayer.swift
└── Resources/
    └── Sounds/
        ├── bell.mp3
        ├── meow.mp3
        ├── complete.mp3
        └── gentle.mp3
```

### 性能目标

| 指标 | 目标 | 测量方法 |
|------|------|---------|
| 内存占用 | < 50 MB | Instruments Memory Profiler |
| CPU 使用 | < 1% 平均 | Activity Monitor |
| 启动时间 | < 2 秒 | Time Profiler |
| 语音识别延迟 | < 3 秒 | 手动计时 |
| UI 响应 | 60 FPS | Frame Rate Monitor |

### 测试策略

1. **单元测试**
   - PomodoroManager 状态机
   - LocalCommandParser 匹配逻辑
   - CloudSyncManager 冲突解决

2. **集成测试**
   - 番茄钟完整流程
   - 语音 → 命令 → 执行
   - 多设备同步

3. **性能测试**
   - 长时间运行（24 小时）
   - 多个 Timer 并发
   - 大量历史数据加载

## Open Questions

1. **番茄钟长休息触发条件**：4 个工作周期后？还是用户手动触发？
   - **建议**：默认 4 个，允许设置中调整

2. **习惯提醒优先级**：多个提醒同时触发如何处理？
   - **建议**：队列化，间隔 2 分钟依次提醒

3. **语音命令冲突**：多个命令匹配同一输入怎么办？
   - **建议**：优先级排序 + 用户确认

4. **iOS 版本数据结构**：现在设计是否足够兼容未来 iOS？
   - **建议**：CloudKit 模型保持向后兼容，新字段用 optional
