# Pomodoro Timer Capability

## ADDED Requirements

### Requirement: Pomodoro Timer Control
用户 SHALL 能够通过菜单或快捷键控制番茄钟。

#### Scenario: Start work session
- **WHEN** 用户点击菜单栏"开始番茄钟"或使用语音命令"开始番茄钟"
- **THEN** 系统启动 25 分钟工作计时器
- **AND** 小猫切换到安静/睡觉动画
- **AND** 播放柔和提示音

#### Scenario: Work session completes
- **WHEN** 25 分钟工作时间结束
- **THEN** 播放铃铛音效
- **AND** 显示"休息 5 分钟"气泡提示
- **AND** 自动切换到短休息状态
- **AND** 小猫切换到跳跃/玩耍动画

#### Scenario: Pause timer
- **WHEN** 用户在工作或休息期间点击"暂停"
- **THEN** 计时器暂停，保留剩余时间
- **AND** 小猫切换到 idle 动画

#### Scenario: Stop timer
- **WHEN** 用户点击"停止"
- **THEN** 计时器重置为 idle 状态
- **AND** 当前会话不计入统计

### Requirement: Long Break Trigger
系统 SHALL 在完成 4 个工作周期后自动触发长休息。

#### Scenario: Fourth work session completes
- **WHEN** 用户完成第 4 个工作周期
- **THEN** 系统触发 15 分钟长休息
- **AND** 显示"辛苦了！休息 15 分钟吧"气泡
- **AND** 播放庆祝音效
- **AND** 长休息结束后重置周期计数

#### Scenario: User skips long break
- **WHEN** 用户在长休息期间点击"跳过"或"停止"
- **THEN** 周期计数重置
- **AND** 回到 idle 状态

### Requirement: Pomodoro Statistics
系统 SHALL 记录和显示番茄钟统计数据。

#### Scenario: View today's count
- **WHEN** 用户查看菜单栏或使用语音命令"今天完成了几个番茄钟"
- **THEN** 显示今日完成的番茄钟数量
- **AND** 显示今日总工作时间（分钟）

#### Scenario: View weekly summary
- **WHEN** 用户在设置中查看统计标签页
- **THEN** 显示本周每日番茄钟数量图表
- **AND** 显示本周平均工作时长

#### Scenario: Persist statistics
- **WHEN** 用户完成一个番茄钟
- **THEN** 数据保存到本地 UserDefaults
- **AND** 如果 iCloud 同步开启，同步到 CloudKit

### Requirement: Animation Integration
小猫动画 SHALL 根据番茄钟状态自动切换。

#### Scenario: Working state animation
- **WHEN** 番茄钟处于工作状态
- **THEN** 小猫播放 `rest_sleeping` 或 `idle` 动画
- **AND** 点击小猫显示"主人在努力，我不打扰~"气泡

#### Scenario: Break state animation
- **WHEN** 番茄钟处于休息状态
- **THEN** 小猫播放 `happy_jump` 或 `eating` 动画
- **AND** 点击小猫显示"休息时间，放松一下吧"气泡

#### Scenario: Completion celebration
- **WHEN** 番茄钟完成（第 4 个或单个）
- **THEN** 小猫播放 `happy_jump` 动画 3 次
- **AND** 显示"完成 1 个番茄钟！"气泡

### Requirement: Configurable Durations
用户 SHALL 能够在设置中配置番茄钟时长。

#### Scenario: Customize work duration
- **WHEN** 用户在设置中修改工作时长（范围 15-60 分钟）
- **THEN** 新的番茄钟使用更新后的时长
- **AND** 设置立即保存到 UserDefaults

#### Scenario: Customize break durations
- **WHEN** 用户修改短休息（范围 3-10 分钟）或长休息（范围 10-30 分钟）
- **THEN** 下一个休息周期使用新时长
- **AND** 设置持久化

#### Scenario: Reset to defaults
- **WHEN** 用户点击"恢复默认"
- **THEN** 工作时长 = 25 分钟，短休息 = 5 分钟，长休息 = 15 分钟
- **AND** 周期数 = 4
