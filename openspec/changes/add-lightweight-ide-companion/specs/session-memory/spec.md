# Session Memory Specification

## ADDED Requirements

### Requirement: Current Task Tracking
系统 SHALL 跟踪当前正在执行的任务。

#### Scenario: 记录任务开始
- **WHEN** 接收到 `taskStart` 事件
- **THEN** `SessionMemory.currentTask` 更新为新任务
- **AND** 记录任务开始时间

#### Scenario: 更新任务进度
- **WHEN** 接收到 `taskProgress` 事件
- **THEN** 更新 `currentTask.progress`
- **AND** 保持任务 ID 和名称不变

#### Scenario: 清除已完成任务
- **WHEN** 接收到 `taskComplete` 事件
- **THEN** `currentTask` 设置为 nil

---

### Requirement: Event History Storage
系统 SHALL 存储最近 50 条 IDE 事件。

#### Scenario: 添加新事件
- **WHEN** 收到新的 `IDEEvent`
- **THEN** 添加到 `recentEvents` 数组
- **AND** 如果数组长度超过 50，移除最旧的事件

#### Scenario: 查询最近事件
- **WHEN** 用户询问"刚才发生了什么？"
- **THEN** 返回最近 5 条事件的摘要

---

### Requirement: Session Statistics
系统 SHALL 统计本次会话的开发活动。

#### Scenario: 统计错误次数
- **WHEN** 收到 `error` 类型事件
- **THEN** `errorCount` 增加 1

#### Scenario: 查询会话时长
- **WHEN** 用户询问"工作多久了？"
- **THEN** 返回从 `sessionStartTime` 到现在的时长

---

### Requirement: Context Query Support
系统 SHALL 支持查询当前上下文。

#### Scenario: 查询当前任务
- **WHEN** 用户询问"现在在做什么？"
- **AND** `currentTask` 不为 nil
- **THEN** 返回："正在执行：{任务名称}（已完成 {progress}%）"

#### Scenario: 无当前任务时
- **WHEN** 用户询问"现在在做什么？"
- **AND** `currentTask` 为 nil
- **THEN** 返回："暂时没有任务在执行喵~"

---

### Requirement: Memory Lifecycle
系统 SHALL 在会话期间保持记忆，应用退出时清空。

#### Scenario: 应用启动时初始化
- **WHEN** 应用启动
- **THEN** `SessionMemory` 初始化为空状态
- **AND** `sessionStartTime` 设置为当前时间

#### Scenario: 应用退出时清空
- **WHEN** 应用退出
- **THEN** 所有记忆数据被清空
- **AND** 不写入磁盘（隐私保护）
