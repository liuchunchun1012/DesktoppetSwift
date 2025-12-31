# Voice Interaction Capability

## ADDED Requirements

### Requirement: Voice Input Recording
用户 SHALL 能够通过快捷键触发语音录制。

#### Scenario: Start recording with hotkey
- **WHEN** 用户按下 Cmd+Shift+V
- **THEN** 系统开始录制音频
- **AND** 宠物显示"正在聆听"的视觉提示（例如耳朵动画）

#### Scenario: Stop recording automatically
- **WHEN** 用户释放快捷键或录音超过 60 秒
- **THEN** 系统停止录制并保存音频文件
- **AND** 自动触发语音转文字处理

### Requirement: Speech-to-Text Conversion
系统 SHALL 将录制的音频转换为文本。

#### Scenario: Convert using OpenAI Whisper
- **WHEN** 用户选择 OpenAI 作为 STT 提供商
- **THEN** 音频通过 /v1/audio/transcriptions API 转换
- **AND** 返回的文本自动发送给当前 AI 提供商

#### Scenario: Convert using local Speech Framework
- **WHEN** 用户选择本地 STT（或 OpenAI 不可用）
- **THEN** 使用 macOS Speech Framework 进行转换
- **AND** 转换结果发送给 AI 提供商

#### Scenario: Handle conversion failure
- **WHEN** STT 转换失败（网络错误、API 错误）
- **THEN** 向用户显示错误消息气泡
- **AND** 音频文件被丢弃，不重试

### Requirement: Microphone Permission
应用 SHALL 请求并管理麦克风权限。

#### Scenario: Request permission on first use
- **WHEN** 用户首次按下录音快捷键
- **THEN** macOS 显示麦克风权限请求对话框
- **AND** 录音仅在用户授权后开始

#### Scenario: Handle permission denied
- **WHEN** 用户拒绝麦克风权限
- **THEN** 显示错误气泡："需要麦克风权限才能使用语音输入"
- **AND** 提供快捷链接打开系统设置

### Requirement: STT Provider Configuration
用户 SHALL 能够在设置中选择 STT 提供商。

#### Scenario: Configure STT provider
- **WHEN** 用户打开设置窗口的"语音"标签页
- **THEN** 显示 STT 提供商选择器（OpenAI Whisper / 本地）
- **AND** 对于 OpenAI，要求输入 API Key（复用现有 Keychain 存储）

#### Scenario: Default to local STT
- **WHEN** 用户未配置 STT 提供商
- **THEN** 默认使用 macOS 本地 Speech Framework
- **AND** 不需要额外配置或 API Key
