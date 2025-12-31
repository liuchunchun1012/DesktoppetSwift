# IDE Companion Specification

## ADDED Requirements

### Requirement: IDE Status Monitoring
系统 SHALL 监听 IDE 状态文件的变化，并实时更新桌宠显示。

#### Scenario: 检测到构建进度更新
- **WHEN** IDE 写入 `status.json` 包含 `"status": "running", "progress": 60`
- **THEN** 桌宠显示气泡："构建中...60%"

#### Scenario: 检测到任务完成
- **WHEN** IDE 写入 `status.json` 包含 `"status": "success"`
- **THEN** 桌宠播放跳跃动画，显示气泡："完成！🎉"

#### Scenario: 检测到错误
- **WHEN** IDE 写入 `status.json` 包含 `"status": "error"`
- **THEN** 桌宠显示错误气泡（红色背景或错误图标）

---

### Requirement: File System Event Monitoring
系统 SHALL 使用 macOS FSEvents API 监听指定目录的文件变化。

#### Scenario: 监听 IDE 状态文件
- **WHEN** 桌宠启动
- **THEN** 开始监听 `~/.desktoppet/ide-status/status.json` 文件变化
- **AND** 文件变化延迟 < 2 秒

#### Scenario: 状态文件被修改
- **WHEN** 监听到 `status.json` 被修改
- **THEN** 立即读取文件内容并解析为 `IDEStatus` 结构
- **AND** 通过 NotificationCenter 广播 `.ideStatusUpdated` 事件

---

### Requirement: Approval Request Handling
系统 SHALL 支持 IDE 的确认请求，并通过点击小猫完成确认。

#### Scenario: 显示确认请求
- **WHEN** IDE 写入 `status.json` 包含 `"status": "waiting_approval"` 和 `approvalRequest`
- **THEN** 桌宠显示确认气泡："将删除 10 个文件，点我允许"
- **AND** 进入"等待确认"状态（小猫可点击）

#### Scenario: 用户点击小猫允许操作
- **WHEN** 桌宠处于"等待确认"状态
- **AND** 用户点击小猫
- **THEN** 播放 `happy_jump` 动画
- **AND** 写入 `~/.desktoppet/ide-status/commands/approve-{taskId}.json`
- **AND** 气泡更新为："已允许 ✅"

#### Scenario: 命令文件格式正确
- **WHEN** 写入允许命令文件
- **THEN** 文件内容为：
  ```json
  {
    "command": "approve",
    "taskId": "task-123",
    "timestamp": "2025-12-21T10:31:00Z"
  }
  ```

---

### Requirement: Status File Format Validation
系统 SHALL 验证 IDE 状态文件格式的正确性。

#### Scenario: 解析合法的状态文件
- **WHEN** 读取到以下 JSON：
  ```json
  {
    "version": "1.0",
    "status": "running",
    "task": {
      "id": "task-123",
      "name": "构建项目",
      "progress": 60
    },
    "message": "Processing file 10/20"
  }
  ```
- **THEN** 成功解析为 `IDEStatus` 结构
- **AND** `currentTask` 为 "构建项目"
- **AND** `progress` 为 60

#### Scenario: 处理非法 JSON
- **WHEN** 读取到格式错误的 JSON
- **THEN** 记录错误日志
- **AND** 不更新 UI（保持上一次状态）

---

### Requirement: Real-time Progress Display
系统 SHALL 实时显示 IDE 任务进度。

#### Scenario: 显示百分比进度
- **WHEN** 接收到进度为 45%
- **THEN** 气泡显示："构建中...45%"

#### Scenario: 显示分数形式进度
- **WHEN** 消息为 "Test: 12/45 passed"
- **THEN** 气泡显示："测试中...12/45 通过"

#### Scenario: 无进度信息时显示任务名
- **WHEN** 状态为 "running" 但无 progress 字段
- **THEN** 气泡显示："正在执行：{任务名称}"
