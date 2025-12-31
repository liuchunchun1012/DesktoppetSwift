# 对话记录摘要 - 个人生活助手功能讨论

**日期**：2025-12-28
**主题**：桌面宠物产品定位重塑和核心功能规划

---

## 核心决策

### 1. 产品定位明确

**不做**：工作效率工具（IDE 伴侣、项目管理）
**要做**：个人生活陪伴助手

**四大原则**：
- ✅ **个人化** - 关注生活节奏和习惯
- ✅ **轻量级** - 小功能、小交互、小播报
- ✅ **本地优先** - 减少 Token 消耗，降低成本
- ✅ **陪伴感** - 温暖的朋友，不是冷冰冰的工具

### 2. 明确否决的功能

- ❌ **IDE 伴侣** - 太冗余，不符合个人化定位
- ❌ 项目管理
- ❌ 代码分析

### 3. 确定要做的核心功能

1. **番茄钟系统**
   - 25 分钟工作 + 5 分钟短休息 + 15 分钟长休息
   - 小猫动画状态切换
   - 本地统计和记录
   - 零 Token

2. **习惯提醒**
   - 喝水提醒（可配置间隔）
   - 久坐提醒（检测活动）
   - 眼睛休息提醒（20-20-20 规则）
   - 本地规则引擎，零 Token

3. **语音交互（STT）**
   - Cmd+Shift+V 录音
   - macOS Speech Framework 或 OpenAI Whisper
   - 本地命令识别（减少 AI 调用）
   - **TTS 作为可选功能**（默认关闭）

4. **跨设备同步**
   - iCloud CloudKit 同步
   - 为 iOS 版本铺路
   - 本地优先，离线可用

### 4. 关于 TTS 的决策

**用户反馈**："小宠物张口说话怪怪的"

**解决方案**：
- 默认使用音效 + 动画（铃铛、喵喵叫、完成音）
- TTS 作为可选功能，设置中可开启
- 符合"可爱宠物"的定位

### 5. 技术策略：本地优先

**零 Token 本地功能**：
- 番茄钟计时器（Foundation.Timer）
- 习惯提醒（UserNotifications）
- 语音识别（Speech Framework）
- 命令识别（正则匹配规则引擎）

**免费 API**：
- 天气（OpenWeatherMap）
- OCR（Vision Framework）
- 本地 AI（Ollama）

**AI 按需调用**：
- 仅在用户主动对话时
- 优先 Ollama 本地模型
- 云端 API 仅用于复杂任务

---

## 跨设备互通讨论

### 用户问题：Mac 和 iPhone 能否互通？

**答案**：可以！Apple 生态互通性很好

**可实现的功能**：
- 对话同步（iCloud CloudKit）
- 任务接力（Handoff）
- 剪贴板共享（Universal Clipboard）
- 距离感应"传送"（Multipeer Connectivity）
- Siri 集成（App Intents）

### iPhone 悬浮球方案

**现实**：iOS 不允许系统级悬浮窗

**替代方案**（用户选择 1 和 4）：
1. ✅ **App 内悬浮球** - 可拖动，仅在 App 内
4. ✅ **主屏幕 Widget** - 快速入口

**其他可选方案**：
- Live Activity + 灵动岛（锁屏常驻）
- StandBy 模式（充电时全屏）

---

## Siri 集成可能性

### 用户问题：小猫和 Siri 能否联动？

**答案**：完全可以！

**通过 App Intents 框架**：
```
"嘿 Siri，问喵喵今天天气怎么样"
"嘿 Siri，让喵喵翻译这段话"
"嘿 Siri，开始番茄钟"
```

**其他 Siri 触发方式**：
- 双击 iPhone 背面 → 唤起小猫
- NFC 标签触发
- 定时提醒

---

## 功能价值分析

### 小猫 vs 现有工具

| 工具 | 小猫的优势 |
|------|-----------|
| Focus/番茄钟 App | ✅ 有陪伴感 + 可爱 |
| Siri/语音助手 | ✅ 个性化 + 记忆习惯 |
| ChatGPT/Claude | ✅ 轻量 + 本地优先 + 省钱 |
| 提醒事项 App | ✅ 温暖的小猫提醒 |

**独特性**：真正关心你生活的小伙伴，而非工具

---

## 实施路线

### 阶段 1：轻量核心（1 周）
- 番茄钟（计时 + 动画 + 通知）
- 喝水/久坐提醒
- 快速笔记
- **零 Token，纯本地**

### 阶段 2：语音交互（3-5 天）
- STT（本地 Speech Framework）
- 语音命令识别（本地规则）
- 音效反馈系统
- TTS 可选

### 阶段 3：跨设备同步（1-2 周）
- iCloud CloudKit 同步
- iPhone App（悬浮球 + Widget）
- Handoff 番茄钟接力

### 阶段 4：智能增强（按需）
- Siri 集成
- 每周总结（可选 AI 分析）
- 习惯建议

---

## 已完成的工作

### OpenSpec 文档创建

**位置**：`openspec/changes/add-personal-life-features/`

**文件列表**：
1. ✅ `proposal.md` - 为什么做、改什么、影响范围
2. ✅ `design.md` - 技术决策和架构设计
3. ✅ `tasks.md` - 详细实施清单（6 周计划）
4. ✅ `specs/pomodoro/spec.md` - 番茄钟功能规范
5. ✅ `specs/habit-reminders/spec.md` - 习惯提醒功能规范
6. ✅ `specs/voice-interaction/spec.md` - 语音交互功能规范
7. ✅ `specs/cross-device-sync/spec.md` - 跨设备同步功能规范

**验证状态**：✅ 通过 `openspec validate --strict`

---

## 明天继续工作的入口

### 快速回顾
```bash
# 查看 proposal
cat openspec/changes/add-personal-life-features/proposal.md

# 查看任务清单
cat openspec/changes/add-personal-life-features/tasks.md

# 查看技术设计
cat openspec/changes/add-personal-life-features/design.md
```

### 开始实施
```bash
# 列出所有待办任务
openspec show add-personal-life-features

# 开始第一个任务（阶段 1.1：项目结构）
# 参考 tasks.md 的清单逐步实现
```

---

## 关键设计文档引用

### 数据模型（design.md）
- PomodoroState: idle | working | shortBreak | longBreak
- ReminderType: water | sitting | eye
- VoiceCommand: 正则匹配规则
- CloudKit: PomodoroSession, HabitLog, Settings

### 架构模式（design.md）
- 单例管理器（PomodoroManager, HabitReminderManager, VoiceManager）
- 本地优先，AI 按需
- 音效 + 动画代替 TTS（默认）
- iCloud CloudKit 私有数据库

### 性能目标
- 内存 < 50MB
- CPU < 1%
- 启动时间 < 2 秒
- 语音识别延迟 < 3 秒

---

## 遗留问题（Open Questions in design.md）

1. **长休息触发**：4 个周期后？还是手动？
   - 建议：默认 4 个，允许设置调整

2. **多提醒同时触发**：如何处理？
   - 建议：队列化，间隔 2 分钟

3. **语音命令冲突**：多个匹配怎么办？
   - 建议：优先级 + 用户确认

4. **iOS 兼容性**：数据结构足够吗？
   - 建议：CloudKit 保持向后兼容，新字段用 optional

---

## 核心理念总结

> "个人生活中的一切涉及到电脑/手机的**小交互、小记录、小播报、小功能**，在**不需要过多 Token 花费**的基础上，**尽可能多的本地调用**。"

**这就是桌面宠物的核心定位！** 🐱✨
