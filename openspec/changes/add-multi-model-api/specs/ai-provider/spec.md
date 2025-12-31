## ADDED Requirements

### Requirement: AI Provider Protocol
系统 SHALL 定义统一的 `AIProvider` 协议，所有 AI 服务必须实现此协议。

#### Scenario: 协议定义
- **WHEN** 创建新的 AI 客户端
- **THEN** 必须实现 `chatStream`、`analyzeImageStream`、`checkHealth` 方法

#### Scenario: 提供商切换
- **WHEN** 用户在设置中切换 AI 提供商
- **THEN** 系统 SHALL 使用新提供商处理后续对话请求

---

### Requirement: OpenAI Compatible API Support
系统 SHALL 支持所有 OpenAI 兼容格式的 API，包括 OpenAI、Qwen、DeepSeek、Moonshot 和中转服务。

#### Scenario: 使用 OpenAI API
- **WHEN** 用户配置 OpenAI API Key 和模型（如 gpt-4o-mini）
- **THEN** 系统 SHALL 成功连接并返回流式对话响应

#### Scenario: 使用中转 API
- **WHEN** 用户配置自定义 Base URL 和 API Key
- **THEN** 系统 SHALL 使用该 Base URL 发送请求

---

### Requirement: Anthropic Claude Support
系统 SHALL 支持 Anthropic Messages API 格式的 Claude 模型。

#### Scenario: 使用 Claude
- **WHEN** 用户配置 Anthropic API Key 和模型（如 claude-3-5-sonnet）
- **THEN** 系统 SHALL 成功连接 Anthropic API 并返回流式响应

---

### Requirement: Google Gemini Support
系统 SHALL 支持 Google Gemini REST API。

#### Scenario: 使用 Gemini
- **WHEN** 用户配置 Gemini API Key 和模型（如 gemini-2.0-flash）
- **THEN** 系统 SHALL 成功连接 Gemini API 并返回流式响应

---

### Requirement: Secure API Key Storage
系统 SHALL 使用 macOS Keychain 安全存储所有 API Key。

#### Scenario: 保存 API Key
- **WHEN** 用户在设置界面输入 API Key
- **THEN** 系统 SHALL 将其加密存储到 Keychain

#### Scenario: 读取 API Key
- **WHEN** 系统需要发送 API 请求
- **THEN** 系统 SHALL 从 Keychain 读取对应 API Key

---

### Requirement: Settings Interface
系统 SHALL 提供图形化设置界面，允许用户配置 AI 提供商。

#### Scenario: 打开设置
- **WHEN** 用户点击菜单栏 → 设置
- **THEN** 系统 SHALL 显示设置窗口

#### Scenario: 配置提供商
- **WHEN** 用户选择提供商、输入 API Key、选择模型
- **THEN** 系统 SHALL 保存配置并应用

#### Scenario: 测试连接
- **WHEN** 用户点击"测试连接"按钮
- **THEN** 系统 SHALL 验证配置并显示结果

---

### Requirement: Easy Installation Script
系统 SHALL 提供傻瓜式安装脚本，自动处理依赖安装。

#### Scenario: 检测 Command Line Tools
- **WHEN** 用户运行 `./install.sh`
- **THEN** 脚本 SHALL 检测 Command Line Tools 是否已安装

#### Scenario: 安装缺失依赖
- **WHEN** Command Line Tools 未安装
- **THEN** 脚本 SHALL 引导用户安装（触发 xcode-select --install）

#### Scenario: 自动构建
- **WHEN** 所有依赖就绪
- **THEN** 脚本 SHALL 自动运行 package.sh 并打开应用
