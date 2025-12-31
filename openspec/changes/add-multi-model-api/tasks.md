## 1. 自动安装脚本 ✅
- [x] 1.1 创建 `install.sh` 脚本框架
- [x] 1.2 添加 Command Line Tools 检测与安装
- [x] 1.3 添加 Ollama 可选安装
- [x] 1.4 添加推荐模型选择安装（gemma3:4b-it-qat, qwen3:4b, llava 等）
- [x] 1.5 集成自动构建和打开应用

## 2. AI 提供商抽象层 ✅
- [x] 2.1 创建 `AIProvider.swift` 协议定义
- [x] 2.2 创建 `AIProviderType` 枚举
- [ ] 2.3 重构 `OllamaClient` 实现协议

## 3. 云端 API 客户端 ✅
- [x] 3.1 创建 `OpenAICompatibleClient.swift`
- [x] 3.2 创建 `AnthropicClient.swift`
- [x] 3.3 创建 `GeminiClient.swift`
- [x] 3.4 实现流式输出支持

## 4. 提供商管理与配置 ✅
- [x] 4.1 创建 `AIProviderManager.swift`
- [x] 4.2 创建 `KeychainHelper.swift`
- [x] 4.3 创建 `UserSettings.swift` 用户配置持久化

## 5. 综合设置界面 ✅
- [x] Restore `sendStreamRequest` implementation and fix compilation error
- [x] Fix connection test hang (weak self issue)
- [x] Fix streaming output (buffer issue)
- [x] Fix HTTP 400 error by streamlining request parameters
- [ ] Final verification of universal build and packaging
- [x] Integrate `SettingsWindow` into the main app menu
- [x] Ensure settings persistence
- [x] Enhance `OpenAICompatibleClient` to support Anthropic response format (fix for API2D)
- [x] Improve `checkHealth` with fallback to dry-run chat (fix for connection issues)
- [x] AI 设置 Tab：提供商选择、API Key、模型
- [x] 5.3 外观设置 Tab：自定义精灵图路径
- [x] 5.4 语言设置 Tab：翻译目标语言
- [x] 5.5 Ollama 设置：本地模型选择（下拉已安装模型）
- [x] 5.6 修改 `StatusBarController` 添加 "⚙️ 设置..." 菜单

## 6. 集成与重构 ✅
- [x] 6.1 修改 `ContentView` 支持动态精灵图路径
- [x] 6.2 修改 `OllamaClient` 支持动态模型选择
- [x] 6.3 统一使用 `UserSettings` 读取配置

## 7. 验证与文档 ✅
- [x] 7.1 测试本地 Ollama 功能
- [x] 7.2 测试各云端 API (API2D + GPT-4o 联网验证通过)
- [x] 7.3 测试设置界面各项功能
- [ ] 7.4 更新 README.md
