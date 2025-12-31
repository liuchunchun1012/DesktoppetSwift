# Implementation Tasks

## 1. 基础架构
- [ ] 1.1 创建 `IDEMonitor.swift` - 文件监听系统
- [ ] 1.2 创建 `EventParser.swift` - 事件解析和规则引擎
- [ ] 1.3 创建 `SessionMemory.swift` - 会话记忆管理
- [ ] 1.4 创建 `IDECommandWriter.swift` - 命令信号写入
- [ ] 1.5 定义 `IDEEvent` 和 `IDEStatus` 数据结构

## 2. IDE 状态监听
- [ ] 2.1 实现 FSEvents 文件监听（监听 `~/.claude-code/status.json`）
- [ ] 2.2 解析 IDE 状态文件（JSON 格式）
- [ ] 2.3 将解析结果转换为内部 `IDEEvent` 结构
- [ ] 2.4 通过 NotificationCenter 广播事件

## 3. 错误翻译规则引擎
- [ ] 3.1 定义 `ErrorRule` 数据结构（pattern, template, action）
- [ ] 3.2 实现规则匹配引擎（正则表达式）
- [ ] 3.3 添加 5 条核心错误规则
- [ ] 3.4 实现错误消息简化逻辑

## 4. 进度显示
- [ ] 4.1 检测进度信息（百分比、分数形式）
- [ ] 4.2 在聊天气泡中显示进度
- [ ] 4.3 实时更新进度（流式更新）

## 5. 点击小猫确认操作
- [ ] 5.1 定义确认请求数据结构
- [ ] 5.2 修改 `ContentView.swift` - 检测确认请求时改变点击行为
- [ ] 5.3 点击触发跳跃动画 + 写入允许信号
- [ ] 5.4 实现 `IDECommandWriter` - 写入 `~/.claude-code/commands/approve.json`
- [ ] 5.5 显示确认气泡（不同样式）

## 6. 会话记忆
- [ ] 6.1 实现 `SessionMemory` 单例
- [ ] 6.2 记录当前任务信息
- [ ] 6.3 记录最近 50 条事件（循环缓冲区）
- [ ] 6.4 支持查询"现在在做什么"

## 7. UI 集成
- [ ] 7.1 在 `ContentView` 中监听 IDE 事件通知
- [ ] 7.2 根据事件类型显示不同的气泡
- [ ] 7.3 处理确认请求的特殊 UI（高亮小猫边框？）
- [ ] 7.4 添加"允许"后的成功反馈

## 8. IDE Hook 示例脚本
- [ ] 8.1 编写 Claude Code Hook 脚本示例（`.claude/hooks/tool-use.sh`）
- [ ] 8.2 编写状态文件格式文档
- [ ] 8.3 编写命令文件格式文档
- [ ] 8.4 添加到 README

## 9. 测试
- [ ] 9.1 手动测试文件监听功能
- [ ] 9.2 测试错误规则匹配
- [ ] 9.3 测试点击确认流程
- [ ] 9.4 测试记忆功能

## 10. 文档
- [ ] 10.1 更新 README - 添加 IDE 集成说明
- [ ] 10.2 添加 IDE Hook 配置指南
- [ ] 10.3 添加功能演示 GIF
