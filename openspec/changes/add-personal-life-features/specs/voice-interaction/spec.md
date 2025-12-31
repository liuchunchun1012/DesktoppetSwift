# Voice Interaction Capability

## ADDED Requirements

### Requirement: Voice Recording
用户 SHALL 能够通过快捷键录制语音。

#### Scenario: Start recording with hotkey
- **WHEN** 用户按下 Cmd+Shift+V
- **THEN** 系统请求麦克风权限（首次使用）
- **AND** 开始录制音频
- **AND** 小猫显示"正在聆听..."气泡
- **AND** 小猫播放特定动画（如竖起耳朵）

#### Scenario: Stop recording on release
- **WHEN** 用户释放 Cmd+Shift+V 或录音超过 60 秒
- **THEN** 停止录制并保存临时音频文件
- **AND** 自动触发语音转文字处理
- **AND** 显示"正在识别..."气泡

#### Scenario: Cancel recording
- **WHEN** 录音时长 < 0.5 秒
- **THEN** 视为误触，取消录音
- **AND** 不调用 STT 服务
- **AND** 临时文件删除

#### Scenario: Microphone permission denied
- **WHEN** 用户拒绝麦克风权限
- **THEN** 显示错误气泡："需要麦克风权限才能使用语音输入"
- **AND** 提供"打开系统设置"快捷链接
- **AND** 录音功能禁用直到权限授予

### Requirement: Speech-to-Text Conversion
系统 SHALL 将录制的语音转换为文字。

#### Scenario: Convert using local Speech Framework
- **WHEN** 用户选择"本地识别"作为 STT 提供商（默认）
- **THEN** 使用 macOS SFSpeechRecognizer 进行转换
- **AND** 支持中文、英文语音识别
- **AND** 识别结果显示在气泡中供确认

#### Scenario: Convert using OpenAI Whisper
- **WHEN** 用户选择"OpenAI Whisper"并配置 API Key
- **THEN** 上传音频到 /v1/audio/transcriptions API
- **AND** 返回识别文本
- **AND** 识别成功后删除本地音频文件

#### Scenario: STT conversion failure
- **WHEN** 语音识别失败（网络错误、API 错误、识别为空）
- **THEN** 显示错误气泡："抱歉，没听清楚"
- **AND** 提供"重试"按钮重新录音
- **AND** 音频文件被删除

#### Scenario: Show recognition result
- **WHEN** 语音识别成功
- **THEN** 显示"你说：[识别文本]"气泡 2 秒
- **AND** 自动触发命令识别或 AI 对话

### Requirement: Local Command Recognition
系统 SHALL 识别常用语音命令并直接执行，不调用 AI。

#### Scenario: Recognize Pomodoro command
- **WHEN** 识别文本包含"开始番茄钟"、"开始工作"、"专注"
- **THEN** 直接调用 PomodoroManager.start()
- **AND** 显示"番茄钟已启动"气泡
- **AND** 不调用 AI Provider（0 Token）

#### Scenario: Recognize stats command
- **WHEN** 识别文本包含"今天完成了"、"今天几个"、"统计"
- **THEN** 读取本地番茄钟统计
- **AND** 显示"今天完成了 X 个番茄钟"气泡
- **AND** 不调用 AI（0 Token）

#### Scenario: Recognize reminder command
- **WHEN** 识别文本包含"提醒喝水"、"提醒休息"
- **THEN** 立即触发相应提醒
- **AND** 显示确认气泡
- **AND** 不调用 AI

#### Scenario: Fallback to AI
- **WHEN** 识别文本不匹配任何本地命令
- **THEN** 将文本作为用户消息发送给 AI Provider
- **AND** 显示 AI 回复（正常流程）

### Requirement: Command Configuration
用户 SHALL 能够查看和管理语音命令。

#### Scenario: View available commands
- **WHEN** 用户在设置的"语音"标签页点击"命令列表"
- **THEN** 显示所有支持的本地命令及示例
- **AND** 分类展示（番茄钟、统计、提醒、通用）

#### Scenario: Test voice recognition
- **WHEN** 用户在设置中点击"测试录音"
- **THEN** 弹出录音窗口，按住按钮录音
- **AND** 显示识别结果和匹配的命令（如果有）
- **AND** 不执行实际操作

### Requirement: TTS Response (Optional)
系统 SHALL 提供可选的语音回复功能。

#### Scenario: Enable TTS in settings
- **WHEN** 用户在设置中打开"语音回复"开关
- **THEN** AI 回复的文字将通过 TTS 播报
- **AND** 使用 macOS AVSpeechSynthesizer
- **AND** 同时显示文字气泡

#### Scenario: TTS disabled by default
- **WHEN** 用户首次安装或未修改设置
- **THEN** TTS 开关为 OFF
- **AND** 仅显示文字气泡和音效
- **AND** 不播报语音

#### Scenario: Adjust TTS voice
- **WHEN** TTS 启用且用户选择语音（中文女声、男声等）
- **THEN** 下一次回复使用新语音
- **AND** 提供"试听"按钮

#### Scenario: TTS during DND
- **WHEN** macOS 勿扰模式启用且 TTS 开启
- **THEN** TTS 静音（遵守系统设置）
- **AND** 仅显示文字气泡

### Requirement: Voice Interaction Settings
用户 SHALL 能够配置语音交互行为。

#### Scenario: Choose STT provider
- **WHEN** 用户在设置中选择 STT 提供商
- **THEN** 选项包括："本地（免费）"、"OpenAI Whisper（需 API Key）"
- **AND** 选择 Whisper 时显示 API Key 输入框
- **AND** 提供"测试连接"按钮验证 API Key

#### Scenario: Adjust recognition language
- **WHEN** 用户选择主要识别语言（中文/英文）
- **THEN** STT 引擎优先识别该语言
- **AND** 本地识别下载对应语言包（如需）

#### Scenario: Toggle local commands
- **WHEN** 用户关闭"启用本地命令识别"
- **THEN** 所有语音输入直接发送给 AI
- **AND** 不进行本地匹配（适合希望自然对话的用户）
