# DesktoppetSwift 🐱

一个可爱的、由 AI 驱动的 macOS 桌面宠物！住在你的屏幕上，随时陪伴你聊天、工作。

![Demo](demo.gif)

## ✨ 特性

- 🎨 **宠物动画** - 流畅的像素风格动画（行走、休息、互动等）
- 🤖 **本地 AI 驱动** - 使用 Ollama 提供智能对话功能
- ⌨️ **全局快捷键** - 随时随地快速调用
  - `Cmd+Shift+J` - 打开聊天对话框
  - `Cmd+Shift+K` - 翻译选中的文字
  - `Cmd+Shift+L` - 分析剪贴板中的截图
- 🎯 **可自定义** - 轻松更换宠物图、AI 性格、模型等
- 🪟 **悬浮窗口** - 始终置顶，不影响其他应用
- 💬 **智能对话** - 支持聊天、翻译、图片分析

## 🎬 更多展示

<table>
  <tr>
    <td align="center">
      <img src="assets/chat-demo.gif" width="200px" /><br />
      <b>💬 AI 对话</b>
    </td>
    <td align="center">
      <img src="assets/happy-jump.gif" width="200px" /><br />
      <b>😸 开心跳跃</b>
    </td>
    <td align="center">
      <img src="assets/sleeping.gif" width="200px" /><br />
      <b>😴 睡觉中</b>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="assets/walking.gif" width="200px" /><br />
      <b>🚶 到处走走</b>
    </td>
    <td colspan="2" align="center">
      <i>...还有更多可爱动画等你发现！</i>
    </td>
  </tr>
</table>

## 📋 前置要求

- macOS 12.0 或更高版本
- [Ollama](https://ollama.ai) - 本地 LLM 运行环境
- 任意 Ollama 模型（推荐 `gemma3`、`qwenvl2.5`、`llava` 等）
- （可选）支持视觉的模型用于截图分析（如 `gemma3`、`qwenvl2.5`）
- （推荐）使用Quantization aware trained models (QAT) 模型，如 `gemma3:12b-it-qat`

## 🚀 快速开始

### 1. 安装 Ollama

```bash
# 访问 https://ollama.ai 下载安装
# 或使用 Homebrew
brew install ollama

# 启动 Ollama 服务
ollama serve

# 拉取一个模型（新窗口）
ollama pull gemma3:12b-it-qat
```

### 2. 克隆并构建项目

```bash
# 克隆仓库
git clone https://github.com/yourusername/DesktoppetSwift.git
cd DesktoppetSwift

# 使用 Swift Package Manager 构建
swift build -c release

# 或者在 Xcode 中打开
open Package.swift
```

### 3. 打包应用

使用提供的打包脚本：

```bash
bash package.sh
```

这会在当前目录生成 `DesktoppetSwift.app`。

### 4. 运行

```bash
open DesktoppetSwift.app
```

首次运行时，系统会请求**辅助功能权限**（用于全局快捷键）。请在：
**系统设置 > 隐私与安全 > 辅助功能** 中允许。

## 🎨 自定义你的宠物

### 更换宠物图

1. 准备你的宠物图序列（PNG 格式）
2. 按照以下目录结构组织：

```
Resources/
├── idle/
│   ├── grooming/
│   │   ├── frame_01.png
│   │   ├── frame_02.png
│   │   └── ...
│   └── ...
├── walk/
│   ├── left/
│   ├── right/
│   └── ...
├── interact/
├── eating/
└── ...
```

3. 替换 `Sources/DesktoppetSwift/Resources/` 目录中的文件
4. 重新构建应用

### 自定义 AI 性格

编辑 `Sources/DesktoppetSwift/Config.swift`：

```swift
struct PetConfig {
    // 修改宠物名字
    static let petName = "你的宠物名"

    // 修改主人名字
    static let ownerName = "你的名字"

    // 修改 Ollama 模型
    static let defaultModel = "gemma3:12b-it-qat"  // 或其他模型

    // 自定义 AI 性格
    static let systemPrompt = """
    你是一只......（在这里定义你的宠物性格）
    """
}
```

### 修改快捷键

编辑 `Sources/DesktoppetSwift/HotkeyManager.swift`：

```swift
// 修改快捷键组合
private let modifierMask: NSEvent.ModifierFlags = [.command, .shift]

// 修改按键码
case 38: // J key -> 改成其他按键码
```

常用按键码参考：
- J: 38
- K: 40
- L: 37
- H: 4
- N: 45
- M: 46

## 📖 使用方法

### 基础交互

- **拖拽移动** - 直接拖动宠物即可
- **点击互动** - 点击宠物触发互动动画
- **菜单栏** - 点击菜单栏图标退出应用

### 快捷键功能

#### 💬 聊天（Cmd+Shift+J）

按下快捷键打开输入框，输入你想说的话，宠物会用 AI 回复你！

#### 🌐 翻译（Cmd+Shift+K）

1. 选中任意文字
2. 按 `Cmd+Shift+K`
3. 宠物会自动翻译（中文↔英文智能识别）

#### 📸 截图分析（Cmd+Shift+L）

1. 使用截图工具（推荐 [Shottr](https://shottr.cc/)），或者直接微信截图，截图后复制到剪切板
2. 按 `Cmd+Shift+L`
3. 宠物会分析剪切板中的截图内容并告诉你

> 注意：截图分析需要支持视觉的模型，如 `gemma3:12b-it-qat`

## 🛠️ 技术栈

- **SwiftUI** - UI 框架
- **AppKit** - 窗口管理、快捷键
- **Ollama API** - 本地 LLM
- **Carbon Framework** - 全局快捷键监听

## 📝 项目结构

```
DesktoppetSwift/
├── Sources/
│   └── DesktoppetSwift/
│       ├── DesktoppetSwiftApp.swift    # 应用入口
│       ├── AppDelegate.swift           # 应用代理
│       ├── ContentView.swift           # 主视图
│       ├── Config.swift                # 配置文件 ⭐
│       ├── OllamaClient.swift          # Ollama API 客户端
│       ├── HotkeyManager.swift         # 快捷键管理
│       ├── StatusBarController.swift   # 菜单栏控制
│       ├── PassthroughView.swift       # 鼠标穿透视图
│       ├── ChatInputWindow.swift       # 聊天输入窗口
│       └── Resources/                  # 宠物图资源
├── Package.swift                        # SPM 配置
├── package.sh                          # 打包脚本
└── README.md                           # 本文件
```

## 🐛 常见问题

### 快捷键不工作？

确保已授予**辅助功能权限**：
1. 打开 **系统设置 > 隐私与安全 > 辅助功能**
2. 找到并勾选 `DesktoppetSwift`
3. 重启应用

### 宠物不说话？

检查 Ollama 是否正常运行：

```bash
# 测试 Ollama API
curl http://localhost:11434/api/tags

# 如果没响应，启动 Ollama
ollama serve
```

### 截图分析不工作？

确保使用支持视觉的模型：

```bash
# 拉取支持视觉的模型
ollama pull gemma3:12b-it-qat

# 在 Config.swift 中配置
static let defaultModel = "gemma3:12b-it-qat"
```

### 宠物图不显示？

确保宠物图已正确复制到 app bundle：
1. 检查 `package.sh` 中的复制逻辑
2. 确认 Resources 目录结构正确
3. 重新运行 `bash package.sh`

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📜 开源协议

本项目采用 MIT 协议 - 详见 [LICENSE](LICENSE) 文件

## 🎉 致谢

- 感谢 [Ollama](https://ollama.ai) 提供本地 LLM 方案
- 宠物图灵感来源：[星露谷物语Stardew Valley]

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
