# DesktoppetSwift 🐱

一个可爱的、由 AI 驱动的 macOS 桌面宠物！住在你的屏幕上，随时陪伴你聊天、工作。

![Demo](demo.gif)

## ✨ 特性

- 🎨 **宠物动画** - 流畅的像素风格动画（行走、休息、互动等）
- 🤖 **本地 AI 驱动** - 使用 Ollama 提供智能对话功能
- 🧠 **聊天记忆** - 记住最近 20 轮对话，支持上下文追问
- ⌨️ **全局快捷键** - 随时随地快速调用
  - `Cmd+Shift+J` - 打开聊天对话框
  - `Cmd+Shift+T` - 翻译**剪贴板**文字（需要先复制）
  - `Cmd+Shift+L` - 分析**剪贴板**截图（需要先复制，可追问）
- 🔄 **翻译语言切换** - 菜单栏可切换翻译到的目标语言（中文/英文）
- 🎯 **高度可定制** - 宠物外观、AI 性格、UI 样式全可自定义
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
- [Ollama](https://ollama.ai) - 本地 LLM 运行环境
- 任意 Ollama 模型（推荐 `gemma3`、`qwen2.5vl`），具体参数视个人电脑配置而定
- （可选）支持视觉的模型用于截图分析（如 `gemma3`、`qwen2.5vl`）
- 推荐使用Quantization aware trained models (QAT)如`gemma3:12b-it-qat`

## 🚀 快速开始

### 1. 安装 Ollama

```bash
# 访问 https://ollama.ai 下载安装，或使用 Homebrew
brew install ollama

# 启动 Ollama 服务
ollama serve

# 拉取一个模型（新窗口）
ollama pull gemma3:12b-it-qat
```

### 2. 克隆并构建项目

> **需要先安装 Xcode**（App Store 免费下载），或安装 Command Line Tools：`xcode-select --install`

```bash
git clone https://github.com/liuchunchun1012/DesktoppetSwift.git
cd DesktoppetSwift
./package.sh
open DesktoppetSwift.app
```

**提示：** 首次运行时，如遇系统拦截，请在「系统设置 > 隐私与安全」中点击「仍要打开」。

---

## 🎨 自定义指南

> **重要：** 所有修改后需重新构建才能生效：
> ```bash
> ./package.sh && open DesktoppetSwift.app
> ```

### 1️⃣ 基础配置 (`Config.swift`)

编辑 `Sources/DesktoppetSwift/Config.swift`：

```swift
struct PetConfig {
    // 🐱 宠物名字
    static let petName = "喵喵"
    
    // 👤 主人名字
    static let ownerName = "主人"
    
    // 🤖 Ollama 模型（需先 ollama pull）
    static let defaultModel = "gemma3:12b-it-qat"
    
    // 🌐 Ollama 服务地址
    static let ollamaBaseURL = "http://localhost:11434"
    
    // 💬 AI 性格设定
    static let systemPrompt = """
    你是一只可爱的猫咪，名叫喵喵...
    请用简短可爱的方式回复（1-3句话）。
    """
    
    // 📸 图片分析时的人设
    static let imageAnalysisPrompt = """
    你是喵喵，正在帮主人分析图片...
    """
}
```

### 2️⃣ 更换宠物图

将你的宠物图放入 `Sources/DesktoppetSwift/Resources/`，按以下结构组织：

```
Resources/
├── idle/
│   └── grooming 1-12/    # 待机动画 (frame_01.png, frame_02.png...)
├── walk/                 # 行走动画
│   ├── left/
│   ├── right/
│   ├── up/
│   └── down/
├── eating/
├── happy/
│   └── jump/
├── rest/
│   ├── prepare/
│   ├── sleeping/
│   └── wakeup/
└── interact/
    ├── belly/
    └── refuse/
```

### 3️⃣ 自定义聊天气泡

编辑 `Sources/DesktoppetSwift/ChatBubbleView.swift`：

```swift
struct ChatBubbleView: View {
    // 🎨 配色方案
    private let bubbleBackground = Color(red: 1.0, green: 0.98, blue: 0.95) // 背景色
    private let textColor = Color(red: 0.2, green: 0.2, blue: 0.2)         // 文字色
    private let accentColor = Color(red: 0.4, green: 0.4, blue: 0.4)       // 强调色
    
    // 📝 修改加载提示
    Text("🐾 喵喵思考中...")  // 改成你喜欢的
    
    // 📐 调整圆角
    RoundedRectangle(cornerRadius: 16)  // 改数字调整圆角大小
}
```

**配色建议：**
- 奶牛猫风格：奶油白 `rgb(1.0, 0.98, 0.95)` + 黑色文字
- 橘猫风格：浅橙色 `rgb(1.0, 0.96, 0.88)` + 棕色文字
- 狗狗风格：米色 `rgb(0.96, 0.96, 0.86)` + 深棕色文字

### 4️⃣ 自定义输入窗口

编辑 `Sources/DesktoppetSwift/ChatInputWindow.swift`：

```swift
private func createWindow() {
    // 🎨 配色
    let creamColor = NSColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
    containerView.layer?.backgroundColor = creamColor.cgColor
    
    // 📝 窗口标题
    case .chat:
        title = "🐱 和喵喵聊天"
    
    // 💬 占位符文字
    case .chat:
        placeholder = "喵~ 说点什么吧..."
    
    // 🐾 发送按钮
    submitButton.title = "发送 🐾"
}
```

### 5️⃣ 调整记忆轮数

编辑 `Sources/DesktoppetSwift/OllamaClient.swift`：

```swift
class OllamaClient {
    // 修改这个数字调整记忆轮数（每轮 = 1问1答）
    private let maxHistoryRounds = 20  // 默认 20 轮
}
```

### 6️⃣ 修改快捷键

编辑 `Sources/DesktoppetSwift/HotkeyManager.swift`：

```swift
// 按键码对照（常用）
// J = 38, K = 40, L = 37, T = 17
```

---

## 📖 使用方法

### 基础交互

| 操作 | 说明 |
|------|------|
| 拖拽 | 移动宠物位置 |
| 点击 | 触发互动动画（默认跳跃） |
| 菜单栏图标 | 切换动作、翻译设置、退出 |

### 快捷键功能

#### 💬 聊天 `Cmd+Shift+J`
打开输入框，输入内容后按回车，宠物会用 AI 回复你。支持上下文追问！

#### 🌐 翻译 `Cmd+Shift+T`
1. 选中文字 → `Cmd+C` 复制
2. 按 `Cmd+Shift+T`
3. 默认翻译到**中文**，可在菜单栏切换到英文

#### 📸 截图分析 `Cmd+Shift+L`
1. 使用截图工具截图（推荐 [Shottr](https://shottr.cc/)）或微信截图
2. 按 `Cmd+Shift+L`，弹出输入框
3. 输入问题（如「这是什么？」「帮我看看这道题」）
4. 宠物会结合图片和问题回答，**可继续在聊天中追问**！

---

## 📝 项目结构

```
DesktoppetSwift/
├── Sources/DesktoppetSwift/
│   ├── Config.swift           # ⭐ 基础配置
│   ├── ChatBubbleView.swift   # 🎨 气泡样式
│   ├── ChatInputWindow.swift  # 🎨 输入窗口样式
│   ├── OllamaClient.swift     # 🧠 AI 客户端 & 记忆
│   ├── HotkeyManager.swift    # ⌨️ 快捷键
│   ├── ContentView.swift      # 主视图
│   └── Resources/             # 🐱 宠物图
├── package.sh                 # 打包脚本
└── README.md
```

---

## 🐛 常见问题

### 快捷键没反应？
1. 确认应用正在运行（菜单栏有猫头图标）
2. 重新运行 `./package.sh && open DesktoppetSwift.app`

### 宠物不说话？
```bash
# 测试 Ollama
curl http://localhost:11434/api/tags

# 没响应就启动 Ollama
ollama serve
```

### 截图分析不工作？
需要支持视觉的模型：
```bash
ollama pull gemma3:12b-it-qat
# 然后在 Config.swift 中配置 defaultModel
```

---

## 🛠️ 技术栈

- **SwiftUI** - UI 框架
- **AppKit** - 窗口管理
- **Ollama API** - 本地 LLM
- **Carbon Framework** - 全局快捷键（稳定、无权限焦虑）

## 📜 开源协议

本项目采用 MIT 协议 - 详见 [LICENSE](LICENSE) 文件

## 🎉 致谢

- 感谢 [Ollama](https://ollama.ai) 提供本地 LLM 方案
- 宠物图灵感来源：[星露谷物语 Stardew Valley]

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
