# DesktoppetSwift 🐱

一个可爱的、由 AI 驱动的 macOS 桌面宠物！住在你的屏幕上，随时陪伴你聊天、工作。

![Demo](demo.gif)

## ✨ 特性

- 🎨 **宠物动画** - 流畅的像素风格动画（行走、休息、互动等）
- 🤖 **多 AI 提供商** - 支持 Ollama / OpenAI / Claude / Gemini / 通义千问 / 自定义 API
- ⚙️ **图形化设置** - 菜单栏一键配置，无需编辑代码
- 🔒 **安全存储** - API Key 存储在 macOS Keychain
- 🌐 **联网搜索** - 支持 API2D 等中转服务的联网功能
- 🧠 **聊天记忆** - 记住最近 20 轮对话，支持上下文追问
- ⌨️ **全局快捷键**
  - `Cmd+Shift+J` - 打开聊天对话框
  - `Cmd+Shift+T` - 翻译**剪贴板**文字（需要先复制）
  - `Cmd+Shift+L` - 分析**剪贴板**截图（需要先复制，可追问）
- 🔄 **翻译语言切换** - 支持中/英/日/韩四种语言
- 🪟 **悬浮窗口** - 始终置顶，不影响其他应用

## 🎬 更多展示

<table>
  <tr>
    <td align="center">
      <img src="assets/chat-demo.gif" width="250px" /><br />
      <b>💬 AI 智能对话</b>
    </td>
    <td align="center">
      <img src="assets/sleeping.gif" width="250px" /><br />
      <b>😴 休息睡觉</b>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center">
      <i>...还有更多可爱动画等你发现！</i>
    </td>
  </tr>
</table>

## 📋 前置要求

- macOS 12.0 或更高版本
- **Intel Mac** 或 **Apple Silicon (M1/M2/M3/M4)**
- AI 服务（二选一）：
  - **云端 API**：OpenAI / Claude / Gemini / 通义千问 的 API Key（或 API2D 等中转服务）
  - **本地模型**：[Ollama](https://ollama.ai) + 任意模型

## 🚀 快速开始

### 方法一：下载 Release（推荐普通用户）

> 💡 无需安装任何开发工具！下载即用，解压直接运行。

1. 从 [Releases](https://github.com/liuchunchun1012/DesktoppetSwift/releases) 下载 **`DesktoppetSwift-Universal.zip`**
2. 解压后将 `DesktoppetSwift.app` 拖入「应用程序」文件夹（可选）
3. 双击运行。首次运行如遇系统拦截，请在「**系统设置 > 隐私与安全**」中点击「**仍要打开**」
4. 点击菜单栏 🐱 图标 → **设置**，选择 AI 提供商并填入 API Key

**支持架构**：Intel Mac (x86_64) 和 Apple Silicon (M1/M2/M3/M4)

---

### 方法二：一键安装脚本（推荐想用本地模型的用户）

> 💡 自动安装 Ollama 和模型，构建并启动应用。

```bash
git clone https://github.com/liuchunchun1012/DesktoppetSwift.git
cd DesktoppetSwift
./install.sh
```

脚本会自动：
- 检测并安装 Command Line Tools
- 可选安装 Homebrew 和 Ollama
- 可选下载推荐模型（gemma3、qwen3、llava 等）
- 构建并启动应用

---

### 方法三：手动从源码构建（开发者）

```bash
# 安装 Command Line Tools（如果没有）
xcode-select --install

# 克隆项目
git clone https://github.com/liuchunchun1012/DesktoppetSwift.git
cd DesktoppetSwift

# 构建通用版（Intel + Apple Silicon）
./package_universal.sh

# 运行
open DesktoppetSwift.app
```

---

## ⚙️ 配置指南

### 图形化设置（推荐）

点击菜单栏 🐱 图标 → **设置**，可配置：

| Tab | 可配置项 |
|-----|---------|
| **AI 设置** | 提供商选择、API Key、Base URL、模型选择、测试连接 |
| **高级设置** | Temperature、Top-P、Max Tokens、联网搜索开关 |
| **外观** | 自定义精灵图路径 |
| **语言** | 翻译目标语言（中/英/日/韩） |

### 支持的 AI 提供商

| 提供商 | 说明 | 需要 API Key |
|--------|------|-------------|
| **Ollama** | 本地运行，完全免费 | ❌ |
| **OpenAI** | 已同步最新模型 | ✅ |
| **Anthropic** | 已同步最新模型 | ✅ |
| **Google Gemini** | 已同步最新模型 | ✅ |
| **通义千问** | 已同步最新模型 | ✅ |
| **自定义 API** | 支持 OpenAI 兼容服务（如 API2D） | ✅ |

### 代码级自定义（可选）

如需修改宠物名称或精灵图，可编辑以下文件后重新构建：

| 文件 | 用途 |
|------|------|
| `Config.swift` | 宠物名称、默认 Prompt |
| `Resources/` | 精灵图目录 |

---

## 📖 使用方法

### 基础交互

| 操作 | 说明 |
|------|------|
| 拖拽 | 移动宠物位置 |
| 点击 | 触发跳跃动画 |
| 鼠标悬浮 | 触发随机互动（翻肚皮 / 拒绝互动） |
| 菜单栏图标 | 设置、切换动作、翻译设置、退出 |

### 快捷键功能

#### 💬 聊天 `Cmd+Shift+J`
打开输入框，输入内容后按回车，宠物会用 AI 回复你。支持上下文追问！

#### 🌐 翻译 `Cmd+Shift+T`
1. 选中文字 → `Cmd+C` 复制
2. 按 `Cmd+Shift+T`
3. 可在设置中切换翻译目标语言（中/英/日/韩）

#### 📸 截图分析 `Cmd+Shift+L`
1. 使用截图工具截图（推荐 [Shottr](https://shottr.cc/)）或微信截图
2. 按 `Cmd+Shift+L`，弹出输入框
3. 输入问题（如「这是什么？」「帮我看看这道题」）
4. 宠物会结合图片和问题回答，**可继续追问**！

---

## 📝 项目结构

```
DesktoppetSwift/
├── Sources/DesktoppetSwift/
│   ├── Config.swift              # 宠物名称等基础配置
│   ├── AIProvider.swift          # AI 提供商协议定义
│   ├── AIProviderManager.swift   # 提供商统一管理
│   ├── OllamaClient.swift        # Ollama 本地模型
│   ├── OpenAICompatibleClient.swift  # OpenAI/自定义 API
│   ├── AnthropicClient.swift     # Claude API
│   ├── GeminiClient.swift        # Gemini API
│   ├── SettingsWindow.swift      # 设置界面
│   ├── UserSettings.swift        # 用户配置持久化
│   ├── KeychainHelper.swift      # API Key 安全存储
│   ├── ChatBubbleView.swift      # 聊天气泡
│   ├── HotkeyManager.swift       # 快捷键管理
│   └── Resources/                # 精灵图
├── install.sh                    # 一键安装脚本
├── package_universal.sh          # 通用包（Intel + M芯片）
└── README.md
```

---

## 🐛 常见问题

### 快捷键没反应？
1. 确认应用正在运行（菜单栏有猫头图标）
2. 首次运行需要在「系统设置 > 隐私与安全 > 辅助功能」中授权

### 宠物不说话？

**使用 Ollama 时**：
```bash
# 测试 Ollama 是否运行
curl http://localhost:11434/api/tags

# 没响应就启动 Ollama
ollama serve
```

**使用云端 API 时**：
- 检查 API Key 是否正确填写
- 点击「设置 → 测试连接」验证

### 截图分析不工作？
需要支持视觉的模型：
- Ollama: `gemma3`、`llava` 等
- 云端: GPT-4o、Claude 3.5 Sonnet、Gemini 等

---

## 🛠️ 技术栈

- **SwiftUI** - UI 框架
- **AppKit** - 窗口管理
- **Keychain Services** - API Key 安全存储
- **Carbon Framework** - 全局快捷键

## 📜 开源协议

本项目采用 MIT 协议 - 详见 [LICENSE](LICENSE) 文件

## 🎉 致谢

- 感谢 [Ollama](https://ollama.ai) 提供本地 LLM 方案
- 宠物图灵感来源：[星露谷物语 Stardew Valley]

### ☕ 感谢打赏支持者

| 支持者 | 金额 | 日期 | 备注 |
|--------|------|------|------|
| **peachesmeow** | ¥66.66 | 2025-12-21 | 🎉 DesktoppetSwift 第一位使用者和支持者！ |

## 💖 支持项目

如果这个项目对你有帮助：
- 给个 Star ⭐️
- 分享给你的朋友
- 提交 Issue 或 PR

如果你愿意请我喝杯咖啡，可以扫码支持：

<table>
  <tr>
    <td align="center">
      <img src="assets/alipay.jpg" width="200px" /><br />
      <b>支付宝</b>
    </td>
    <td align="center">
      <img src="assets/wechat.jpg" width="200px" /><br />
      <b>微信</b>
    </td>
  </tr>
</table>

---

**Happy Coding!** 🐱
