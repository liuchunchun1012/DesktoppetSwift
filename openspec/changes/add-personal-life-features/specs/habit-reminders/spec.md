# Habit Reminders Capability

## ADDED Requirements

### Requirement: Water Reminder
系统 SHALL 定时提醒用户喝水。

#### Scenario: Schedule water reminder
- **WHEN** 用户启用喝水提醒（设置中开关 ON）
- **THEN** 系统按配置间隔（默认 60 分钟）调度提醒
- **AND** 启动后首次提醒在 1 个间隔后触发

#### Scenario: Trigger water reminder
- **WHEN** 喝水提醒时间到达
- **THEN** 小猫播放 `happy_jump` 动画
- **AND** 显示"该喝水啦~💧"气泡
- **AND** 播放铃铛音效
- **AND** 提醒气泡显示"确认"按钮

#### Scenario: Acknowledge reminder
- **WHEN** 用户点击"确认"按钮或点击小猫
- **THEN** 记录确认时间到本地
- **AND** 如果 iCloud 开启，同步到 CloudKit
- **AND** 气泡消失，调度下一次提醒

#### Scenario: Dismiss reminder
- **WHEN** 用户忽略提醒 30 秒
- **THEN** 气泡自动消失
- **AND** 不记录到统计
- **AND** 正常调度下一次提醒

### Requirement: Sitting Reminder
系统 SHALL 检测久坐并提醒用户起身活动。

#### Scenario: Monitor user activity
- **WHEN** 应用启动且久坐提醒启用
- **THEN** 系统开始监听鼠标和键盘事件
- **AND** 计算最后活动时间

#### Scenario: Detect prolonged sitting
- **WHEN** 用户持续活动超过阈值（默认 50 分钟）且无中断超过 5 分钟
- **THEN** 触发久坐提醒
- **AND** 显示"已经坐 50 分钟了，站起来走走吧"气泡
- **AND** 小猫播放 `interact_belly` 动画（伸懒腰）
- **AND** 播放柔和提示音

#### Scenario: User becomes active
- **WHEN** 触发提醒后检测到用户离开（5 分钟无活动）
- **THEN** 记录为成功响应
- **AND** 重置计时器

#### Scenario: Ignore sitting reminder
- **WHEN** 用户持续活动不理会提醒
- **THEN** 10 分钟后再次提醒（最多 3 次）
- **AND** 第 3 次后停止，等待下一周期

### Requirement: Eye Rest Reminder
系统 SHALL 按 20-20-20 规则提醒用户休息眼睛。

#### Scenario: Schedule eye rest
- **WHEN** 眼睛休息提醒启用
- **THEN** 每 20 分钟触发一次提醒

#### Scenario: Trigger eye rest reminder
- **WHEN** 20 分钟计时到达
- **THEN** 显示"20-20-20 规则：看向 20 英尺外 20 秒"气泡
- **AND** 小猫播放眨眼动画（如果有）
- **AND** 播放柔和提示音
- **AND** 提供 20 秒倒计时（可选）

#### Scenario: Complete eye rest
- **WHEN** 用户点击"完成"或等待 20 秒倒计时结束
- **THEN** 记录到本地统计
- **AND** 调度下一次 20 分钟后提醒

### Requirement: Reminder Configuration
用户 SHALL 能够在设置中配置所有提醒。

#### Scenario: Adjust water interval
- **WHEN** 用户修改喝水提醒间隔（30-180 分钟）
- **THEN** 下一次提醒使用新间隔
- **AND** 设置保存到 UserDefaults

#### Scenario: Adjust sitting threshold
- **WHEN** 用户修改久坐阈值（30-90 分钟）
- **THEN** 监听逻辑使用新阈值
- **AND** 当前计时不受影响，下一周期生效

#### Scenario: Disable specific reminder
- **WHEN** 用户关闭某个提醒开关
- **THEN** 该提醒立即停止调度
- **AND** 已触发的气泡消失
- **AND** 不再记录该类型统计

#### Scenario: Enable all reminders
- **WHEN** 用户点击"启用所有提醒"
- **THEN** 所有提醒类型开关打开
- **AND** 使用默认间隔重新调度

### Requirement: Reminder Statistics
系统 SHALL 记录用户的提醒响应数据。

#### Scenario: Track daily habits
- **WHEN** 用户确认任意提醒
- **THEN** 记录类型、时间戳到本地
- **AND** 计算当日各类提醒确认次数

#### Scenario: View weekly habits
- **WHEN** 用户在设置中查看"习惯统计"
- **THEN** 显示本周每日喝水次数、久坐响应次数、眼睛休息次数
- **AND** 可选：显示 AI 生成的建议（需用户确认）

#### Scenario: Clear history
- **WHEN** 用户点击"清空历史"
- **THEN** 弹出确认对话框
- **AND** 确认后删除本地和 CloudKit 的习惯记录
- **AND** 保留当前设置

### Requirement: Smart Scheduling
系统 SHALL 智能调整提醒时机，避免打扰。

#### Scenario: Avoid during Pomodoro work
- **WHEN** 番茄钟处于工作状态且习惯提醒时间到达
- **THEN** 延迟提醒到休息时段
- **AND** 休息开始时集中显示待处理提醒

#### Scenario: Avoid during DND
- **WHEN** macOS 勿扰模式启用
- **THEN** 提醒静默（不播放音效）
- **AND** 仍显示气泡（如果小猫窗口可见）

#### Scenario: Multiple reminders
- **WHEN** 多个提醒同时触发
- **THEN** 按优先级依次显示（眼睛 > 喝水 > 久坐）
- **AND** 每个提醒间隔 2 分钟
