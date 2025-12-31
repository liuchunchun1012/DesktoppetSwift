# Cross-Device Sync Capability

## ADDED Requirements

### Requirement: iCloud CloudKit Integration
系统 SHALL 使用 CloudKit 同步用户数据到 iCloud。

#### Scenario: Initialize CloudKit on first launch
- **WHEN** 用户首次启动应用且 iCloud 登录
- **THEN** 应用请求 iCloud 权限（如需）
- **AND** 初始化 CloudKit 私有数据库
- **AND** 创建必要的 CKRecord 类型（PomodoroSession, HabitLog, Settings）

#### Scenario: iCloud not available
- **WHEN** 用户未登录 iCloud 或禁用 iCloud Drive
- **THEN** 应用降级为纯本地模式
- **AND** 显示提示："未启用 iCloud，数据仅保存在本地"
- **AND** 所有功能仍可正常使用

#### Scenario: Enable iCloud later
- **WHEN** 用户在未启用 iCloud 的状态下使用一段时间后登录 iCloud
- **THEN** 提示"发现 iCloud 账户，是否同步现有数据？"
- **AND** 确认后将本地数据上传到 CloudKit
- **AND** 后续自动同步

### Requirement: Pomodoro Session Sync
系统 SHALL 同步番茄钟会话记录。

#### Scenario: Save session to CloudKit
- **WHEN** 用户完成一个番茄钟会话
- **THEN** 创建 PomodoroSession CKRecord
- **AND** 包含字段：startTime, duration, completed, deviceID
- **AND** 保存到 CloudKit 私有数据库
- **AND** 如果网络不可用，加入离线队列

#### Scenario: Fetch sessions on launch
- **WHEN** 应用启动且 iCloud 可用
- **THEN** 拉取最近 30 天的 PomodoroSession 记录
- **AND** 合并到本地统计（去重）
- **AND** 更新今日/本周计数

#### Scenario: Sync conflict resolution
- **WHEN** 同一时间段有多个设备的会话记录
- **THEN** 保留所有记录（不冲突，番茄钟可并行）
- **AND** 按 startTime 排序显示

### Requirement: Habit Log Sync
系统 SHALL 同步习惯追踪记录。

#### Scenario: Save habit log
- **WHEN** 用户确认习惯提醒（喝水、久坐、眼睛休息）
- **THEN** 创建 HabitLog CKRecord
- **AND** 包含字段：type, timestamp, acknowledged, deviceID
- **AND** 立即同步到 CloudKit（或离线队列）

#### Scenario: Fetch habit logs
- **WHEN** 应用启动或用户手动刷新统计
- **THEN** 拉取最近 7 天的 HabitLog 记录
- **AND** 按类型汇总每日计数
- **AND** 更新习惯统计界面

#### Scenario: Delete old logs
- **WHEN** 习惯记录超过 90 天
- **THEN** 自动删除 CloudKit 和本地记录（可选）
- **AND** 保留汇总统计数据

### Requirement: Settings Sync
系统 SHALL 同步用户设置到 iCloud。

#### Scenario: Upload settings changes
- **WHEN** 用户修改番茄钟配置、提醒间隔等设置
- **THEN** 更新本地 UserDefaults
- **AND** 创建或更新 Settings CKRecord
- **AND** 包含所有用户自定义设置

#### Scenario: Download settings from iCloud
- **WHEN** 用户在新设备首次启动应用
- **THEN** 从 CloudKit 拉取 Settings 记录
- **AND** 如果本地无设置，应用 iCloud 设置
- **AND** 如果本地有设置，询问"使用本地设置还是 iCloud 设置？"

#### Scenario: Settings conflict
- **WHEN** 多个设备同时修改设置
- **THEN** 使用 modificationDate 最新的记录
- **AND** 显示通知："设置已从其他设备更新"

### Requirement: Offline Queue
系统 SHALL 在离线时缓存待同步数据。

#### Scenario: Save to offline queue
- **WHEN** CloudKit 操作失败（网络不可用、iCloud 错误）
- **THEN** 将待同步记录保存到本地离线队列
- **AND** 显示同步状态为"离线"（可选图标）

#### Scenario: Sync on network restore
- **WHEN** 网络恢复且 iCloud 可用
- **THEN** 自动处理离线队列中的记录
- **AND** 按顺序上传到 CloudKit
- **AND** 成功后从队列移除
- **AND** 显示同步状态为"已同步"

#### Scenario: Offline queue size limit
- **WHEN** 离线队列超过 1000 条记录
- **THEN** 保留最新 1000 条，删除最旧记录
- **AND** 显示警告："离线数据过多，部分旧数据已丢弃"

### Requirement: Sync Status Visibility
用户 SHALL 能够查看同步状态。

#### Scenario: View sync status in settings
- **WHEN** 用户打开设置的"同步"标签页
- **THEN** 显示当前同步状态：
  - iCloud 登录状态
  - 上次同步时间
  - 待同步记录数（离线队列）
  - CloudKit 存储使用量（可选）

#### Scenario: Manual sync trigger
- **WHEN** 用户点击"立即同步"按钮
- **THEN** 强制拉取最新 CloudKit 数据
- **AND** 上传离线队列中的记录
- **AND** 显示同步进度

#### Scenario: Sync error notification
- **WHEN** CloudKit 操作持续失败（3 次以上）
- **THEN** 显示错误通知："iCloud 同步失败，请检查网络和 iCloud 设置"
- **AND** 提供"重试"和"查看详情"按钮

### Requirement: Data Privacy
系统 SHALL 保护用户数据隐私。

#### Scenario: Use private database
- **WHEN** 保存数据到 CloudKit
- **THEN** 使用 CKContainer.default().privateCloudDatabase
- **AND** 数据仅用户本人可访问
- **AND** 不使用公共数据库或共享数据库

#### Scenario: Encrypt sensitive data
- **WHEN** 保存包含敏感信息的记录（暂无）
- **THEN** 使用 CloudKit 加密资产
- **AND** 遵守 Apple 数据保护最佳实践

#### Scenario: Delete all cloud data
- **WHEN** 用户在设置中点击"删除所有 iCloud 数据"
- **THEN** 弹出确认对话框警告不可恢复
- **AND** 确认后删除所有 CKRecord（PomodoroSession, HabitLog, Settings）
- **AND** 本地数据保留（仅删除云端）

### Requirement: Future iOS Compatibility
CloudKit 数据模型 SHALL 设计为兼容未来 iOS 版本。

#### Scenario: Schema versioning
- **WHEN** 创建 CKRecord 类型
- **THEN** 包含 schemaVersion 字段（当前为 1）
- **AND** 预留扩展字段（metadata: String）

#### Scenario: Cross-platform field mapping
- **WHEN** 定义 CKRecord 字段
- **THEN** 使用平台无关的数据类型（String, Int64, Date）
- **AND** 避免使用 macOS 特定类型

#### Scenario: Graceful degradation
- **WHEN** 未来 iOS 版本添加新字段
- **THEN** macOS 版本忽略未知字段（不报错）
- **AND** 新字段在下次同步时保留
