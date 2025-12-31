# Change: 添加多模型 API 支持、设置界面和自动安装脚本

## Why
当前应用仅支持本地 Ollama，对非技术用户安装门槛高，且配置需要修改代码。用户需要：
1. 傻瓜式安装脚本，自动处理依赖，可选安装 Ollama 和推荐模型
2. 多云端 AI 模型支持（OpenAI、Claude、Gemini、Qwen 等）
3. 图形化设置界面，无需改代码即可配置 AI、宠物外观、翻译语言等

## What Changes
- **新增** 一键安装脚本 `install.sh`
  - 自动检测并安装 Command Line Tools
  - 可选安装 Ollama 和推荐模型（gemma3:4b-it-qat, qwen3:4b 等）
- **新增** `AIProvider` 协议抽象层
- **新增** `OpenAICompatibleClient` (OpenAI/Qwen/DeepSeek/中转)
- **新增** `AnthropicClient` (Claude)
- **新增** `GeminiClient` (Google Gemini)
- **新增** `AIProviderManager` 提供商管理器
- **新增** `KeychainHelper` API Key 安全存储
- **新增** `SettingsWindow` 综合设置界面
  - AI 提供商选择和配置
  - **自定义宠物精灵图**（用户可导入自己的动画帧）
  - **翻译目标语言设置**
  - **Ollama 模型选择**
- **修改** `OllamaClient` 实现 `AIProvider` 协议
- **修改** `StatusBarController` 添加 "⚙️ 设置..." 菜单项
- **修改** `Config.swift` 默认值改为从用户配置读取

## Impact
- Affected specs: `ai-provider` (新增), `settings` (新增)
- Affected code:
  - `Sources/DesktoppetSwift/OllamaClient.swift`
  - `Sources/DesktoppetSwift/StatusBarController.swift`
  - `Sources/DesktoppetSwift/Config.swift`
  - `Sources/DesktoppetSwift/ContentView.swift` (精灵图路径)
  - 新增 ~10 个源文件
