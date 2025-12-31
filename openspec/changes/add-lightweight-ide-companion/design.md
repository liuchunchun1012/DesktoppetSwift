# Technical Design

## Context

桌宠需要与 IDE（Claude Code、Cursor 等）实时互动，但要保持轻量级：
- **约束**：不能消耗大量 Token（成本考虑）
- **约束**：不能做重型分析（性能考虑）
- **机会**：填补 IDE 的用户体验空白（进度提示、错误简化、趣味交互）

## Goals / Non-Goals

### Goals
- 提供实时、轻量级的 IDE 进度反馈
- 简化技术错误信息，降低新手门槛
- 通过趣味交互（点击=允许）提升开发体验
- 零 Token 消耗（核心功能使用规则引擎）

### Non-Goals
- 不做代码分析或智能建议（那是 IDE 的工作）
- 不做深度项目理解（MVP 阶段）
- 不做复杂的双向控制（仅支持简单的确认/拒绝）

## Decisions

### 1. 通信协议：文件监听（FSEvents）

**决策**：使用文件监听而非 WebSocket/HTTP。

**理由**：
- ✅ **极简**：IDE 只需写 JSON 文件，无需启动服务器
- ✅ **跨平台**：任何 IDE 都能支持（只要能写文件）
- ✅ **低延迟**：FSEvents 延迟 < 100ms
- ✅ **易调试**：直接查看文件内容

**替代方案**：
- WebSocket：更实时，但需要桌宠启动服务器，增加复杂度
- HTTP 轮询：延迟高，浪费资源

**文件格式**：
```json
// ~/.claude-code/status.json
{
  "version": "1.0",
  "timestamp": "2025-12-21T10:30:00Z",
  "status": "running",  // idle | running | error | success | waiting_approval
  "task": {
    "id": "task-123",
    "name": "重构用户认证模块",
    "progress": 60,       // 0-100 or null
    "currentStep": "正在分析现有代码"
  },
  "message": "Found 15 files to modify",
  "approvalRequest": {  // 仅在 status=waiting_approval 时存在
    "action": "delete_files",
    "description": "将删除 10 个测试文件",
    "files": ["test1.ts", "test2.ts"]
  }
}
```

**命令文件**（桌宠 → IDE）：
```json
// ~/.claude-code/commands/approve-task-123.json
{
  "command": "approve",
  "taskId": "task-123",
  "timestamp": "2025-12-21T10:31:00Z"
}
```

---

### 2. 错误翻译：规则引擎

**决策**：使用正则表达式匹配 + 模板替换，而非 AI。

**理由**：
- ✅ **零成本**：不调用 AI API
- ✅ **低延迟**：毫秒级响应
- ✅ **可控**：规则可预测、可调试
- ✅ **覆盖率高**：80% 常见错误可用规则处理

**实现**：
```swift
struct ErrorRule {
    let pattern: Regex<Substring>
    let template: String
    let action: ErrorAction?
}

enum ErrorAction {
    case openFile(String)
    case runCommand(String)
    case showProcesses
    case none
}

let rules = [
    ErrorRule(
        pattern: /ENOENT.*'(.+?)'/,
        template: "找不到 {$1} 文件喵~",
        action: .none
    ),
    ErrorRule(
        pattern: /port (\d+).*EADDRINUSE/,
        template: "{$1} 端口被占用了",
        action: .showProcesses
    )
]
```

**替代方案**：
- AI 翻译：成本高，延迟大，但能处理未知错误
- **混合方案**（未来）：规则未命中时才调用 AI

---

### 3. 记忆系统：仅内存（MVP）

**决策**：MVP 阶段仅使用内存存储，不持久化。

**理由**：
- ✅ **简单**：无需管理文件系统
- ✅ **隐私友好**：重启后自动清空
- ✅ **够用**：单次会话已足够支持"现在在做什么"查询

**数据结构**：
```swift
class SessionMemory {
    static let shared = SessionMemory()

    // 当前任务
    var currentTask: TaskContext?

    // 最近事件（循环缓冲区）
    var recentEvents: [IDEEvent] = []
    let maxEvents = 50

    // 统计
    var sessionStartTime: Date = Date()
    var errorCount: Int = 0
}

struct TaskContext {
    let id: String
    let name: String
    let startTime: Date
    var progress: Int?
}

struct IDEEvent {
    let timestamp: Date
    let type: EventType
    let message: String
    let details: [String: String]?
}

enum EventType {
    case taskStart
    case taskProgress
    case taskComplete
    case error
    case approvalRequest
}
```

**未来扩展**：
- 项目记忆（持久化到 `~/Library/Application Support/`）
- 学习常见错误的解决方案

---

### 4. 交互设计：点击小猫 = 跳跃 = 允许

**决策**：在确认请求状态下，点击小猫触发"允许"操作。

**流程**：
1. IDE 写入 `status.json`（`status: "waiting_approval"`）
2. 桌宠检测到确认请求 → 显示气泡："将删除 10 个文件，点我允许"
3. 桌宠进入"等待确认"状态（视觉提示：气泡高亮？边框闪烁？）
4. 用户点击小猫 → 触发 `happy_jump` 动画
5. 桌宠写入 `~/.claude-code/commands/approve-{taskId}.json`
6. 气泡更新："已允许 ✅"
7. IDE 检测到命令文件 → 继续执行

**替代方案**：
- 弹出确认对话框：更明确，但破坏沉浸感
- 双击确认：更安全，但不够直观

**拒绝操作**（未来）：
- 按 ESC 键 → 写入 `deny-{taskId}.json`
- 或拖拽小猫到屏幕边缘

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  DesktoppetSwift                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────┐         ┌──────────────┐          │
│  │ IDEMonitor  │ ─────> │ EventParser  │          │
│  │ (FSEvents)  │         │ (Rules)      │          │
│  └─────────────┘         └──────────────┘          │
│        │                        │                   │
│        │                        ▼                   │
│        │                ┌──────────────┐            │
│        └──────────────> │SessionMemory │            │
│                         └──────────────┘            │
│                                │                    │
│                                ▼                    │
│                        ┌──────────────┐             │
│                        │ ContentView  │             │
│                        │ (UI Update)  │             │
│                        └──────────────┘             │
│                                │                    │
│                         (User Click)                │
│                                │                    │
│                                ▼                    │
│                    ┌──────────────────────┐         │
│                    │ IDECommandWriter     │         │
│                    │ (Write approve.json) │         │
│                    └──────────────────────┘         │
└─────────────────────────────────────────────────────┘
                            │
                            ▼
            ┌──────────────────────────────┐
            │ ~/.claude-code/              │
            │   ├── status.json (read)     │
            │   └── commands/              │
            │       └── approve-xxx.json   │
            └──────────────────────────────┘
                            ▲
                            │
                ┌───────────────────────────┐
                │   Claude Code / Cursor    │
                │   (Writes status,         │
                │    Reads commands)        │
                └───────────────────────────┘
```

---

## Risks / Trade-offs

### 风险 1：文件监听延迟
- **风险**：FSEvents 可能有 1-2 秒延迟
- **缓解**：对于进度更新，1-2 秒延迟可接受；对于确认请求，可能需要优化
- **备选**：未来可添加 WebSocket 作为可选协议

### 风险 2：规则覆盖率不足
- **风险**：仅 5 条规则可能无法覆盖所有错误
- **缓解**：MVP 阶段优先覆盖最常见错误；未命中时显示原始消息
- **未来**：支持用户自定义规则 + AI 兜底

### 风险 3：误操作风险
- **风险**：用户可能不小心点击小猫导致误允许
- **缓解**：
  - 在气泡中明确说明操作内容
  - 未来可添加"危险操作"二次确认
  - 记录所有确认操作到日志

### 风险 4：IDE 兼容性
- **风险**：不同 IDE 可能有不同的状态文件格式
- **缓解**：
  - 定义标准格式，提供适配器
  - 优先支持 Claude Code，其他 IDE 逐步适配

---

## Migration Plan

### 阶段 1：功能开发（本次）
1. 实现核心功能
2. 提供 Claude Code Hook 示例
3. 手动测试验证

### 阶段 2：用户测试（下次）
1. 邀请用户试用
2. 收集反馈
3. 调整规则库和交互方式

### 阶段 3：扩展（未来）
1. 添加更多规则
2. 支持项目记忆持久化
3. 支持更多 IDE
4. 添加用户自定义规则

---

## Open Questions

1. **文件路径**：`~/.claude-code/` 还是 `~/.desktoppet/ide-status/`？
   - 建议：使用通用路径 `~/.desktoppet/ide-status/` 以支持多 IDE

2. **确认超时**：如果用户 5 分钟不响应，是否自动拒绝？
   - 建议：MVP 不处理，由 IDE 自己决定超时策略

3. **多任务并发**：如果 IDE 同时执行多个任务怎么办？
   - 建议：MVP 只显示最新任务；未来支持任务队列

4. **隐私**：是否需要让用户手动启用 IDE 集成？
   - 建议：默认启用，但在设置中提供开关
