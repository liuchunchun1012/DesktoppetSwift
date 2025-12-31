# Change: Add Voice Chat Capability

## Why
用户希望通过语音与桌面宠物交互，而不仅仅是打字。语音交互更自然，特别是在用户双手忙碌时（如编程、设计工作）。

## What Changes
- 添加语音录制功能（通过快捷键触发）
- 集成语音转文字服务（OpenAI Whisper API 或本地模型）
- 支持语音输入触发 AI 对话
- 可选：AI 回复文字转语音播放（TTS）

**注意**：第一版仅实现语音输入（STT），语音输出（TTS）作为未来功能。

## Impact
- **新增能力**: voice-interaction
- **受影响代码**:
  - `StatusBarController.swift` - 添加语音录制快捷键
  - `AIProviderManager.swift` - 处理语音输入转换的文本
  - 新增 `VoiceRecorder.swift` - 录音管理
  - 新增 `SpeechToText.swift` - STT 服务抽象
- **依赖**: 需要麦克风权限（Info.plist 更新）
- **配置**: 用户可在设置中选择 STT 提供商（OpenAI/本地）
