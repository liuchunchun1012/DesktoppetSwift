# Event Parser Specification

## ADDED Requirements

### Requirement: Error Translation Rules
系统 SHALL 使用正则表达式匹配错误消息，并翻译为用户友好的中文。

#### Scenario: 翻译文件未找到错误
- **WHEN** 错误消息为 `"Error: ENOENT: no such file or directory, open 'config.json'"`
- **THEN** 翻译为："找不到 config.json 文件喵~"

#### Scenario: 翻译端口占用错误
- **WHEN** 错误消息包含 `"Error: listen EADDRINUSE: address already in use :::3000"`
- **THEN** 翻译为："3000 端口被占用了"

#### Scenario: 翻译数据库连接错误
- **WHEN** 错误消息包含 `"Error: connect ECONNREFUSED"`
- **THEN** 翻译为："数据库连接不上，检查配置"

#### Scenario: 翻译依赖缺失错误
- **WHEN** 错误消息为 `"Error: Cannot find module 'express'"`
- **THEN** 翻译为："缺少 express 包"

#### Scenario: 翻译权限错误
- **WHEN** 错误消息包含 `"Error: EACCES: permission denied"`
- **THEN** 翻译为："权限不够，可能需要 sudo"

#### Scenario: 未匹配的错误保持原样
- **WHEN** 错误消息不匹配任何规则
- **THEN** 返回原始错误消息

---

### Requirement: Error Rule Engine
系统 SHALL 提供可扩展的错误规则引擎。

#### Scenario: 注册新规则
- **WHEN** 添加新的 `ErrorRule`：
  ```swift
  ErrorRule(
      pattern: /port (\d+).*EADDRINUSE/,
      template: "{$1} 端口被占用了",
      action: .showProcesses
  )
  ```
- **THEN** 规则被添加到规则库

#### Scenario: 规则匹配并替换变量
- **WHEN** 错误消息为 `"port 3000 EADDRINUSE"`
- **AND** 匹配到上述规则
- **THEN** 提取变量 `$1 = "3000"`
- **AND** 返回 "3000 端口被占用了"

#### Scenario: 规则按顺序匹配
- **WHEN** 有多个规则可能匹配
- **THEN** 使用第一个匹配的规则

---

### Requirement: Progress Information Extraction
系统 SHALL 从消息中提取进度信息。

#### Scenario: 提取百分比进度
- **WHEN** 消息为 `"Building... 60% complete"`
- **THEN** 提取进度为 60

#### Scenario: 提取分数形式进度
- **WHEN** 消息为 `"Test Suites: 12 passed, 33 total"`
- **THEN** 提取进度为 "12/33"

#### Scenario: 无进度信息时返回 nil
- **WHEN** 消息为 `"Starting build..."`
- **THEN** 进度为 nil

---

### Requirement: Task Name Simplification
系统 SHALL 简化技术性任务名称为用户友好的描述。

#### Scenario: 简化构建任务
- **WHEN** 任务名为 `"npm run build"`
- **THEN** 简化为 "构建项目"

#### Scenario: 简化测试任务
- **WHEN** 任务名为 `"swift test"`
- **THEN** 简化为 "运行测试"

#### Scenario: 简化 AI 分析任务
- **WHEN** 任务名为 `"Analyzing codebase with Claude"`
- **THEN** 简化为 "Claude 正在分析代码"

#### Scenario: 未知任务保持原样
- **WHEN** 任务名不匹配任何简化规则
- **THEN** 返回原始任务名
