# Implementation Tasks

## 1. Permissions & Setup
- [ ] 1.1 添加麦克风权限到 Info.plist
- [ ] 1.2 创建 `VoiceRecorder.swift` 基础录音组件
- [ ] 1.3 测试录音功能在 macOS 12.0+ 上工作

## 2. Speech-to-Text Integration
- [ ] 2.1 创建 `SpeechToText` 协议
- [ ] 2.2 实现 `OpenAIWhisperClient` (使用 /v1/audio/transcriptions)
- [ ] 2.3 实现本地 STT 选项（备选：macOS 内置 Speech Framework）
- [ ] 2.4 添加 STT 提供商配置到 SettingsWindow

## 3. UI Integration
- [ ] 3.1 添加录音快捷键到 StatusBarController (Cmd+Shift+V)
- [ ] 3.2 显示录音状态指示器（宠物动画或气泡提示）
- [ ] 3.3 录音结束后自动发送转换的文本到 AI

## 4. Error Handling
- [ ] 4.1 处理麦克风权限被拒绝
- [ ] 4.2 处理 STT API 错误（网络失败、配额超限）
- [ ] 4.3 添加录音时长限制（避免无限录音）

## 5. Testing
- [ ] 5.1 手动测试录音 → 转文字 → AI 回复流程
- [ ] 5.2 测试不同 STT 提供商（OpenAI/本地）
- [ ] 5.3 测试快捷键冲突处理
