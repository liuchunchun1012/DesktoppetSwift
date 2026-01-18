# Meowpal 🐱 v2.0

A cute, AI-powered macOS desktop pet! Lives on your screen, ready to chat and help you work.

![Demo](demo.gif)

## ✨ Features

### Core Features
- 🎨 **Pet Animations** - Smooth pixel-art animations (walking, resting, interacting, etc.)
- 🤖 **Multiple AI Providers** - Supports Ollama / OpenAI / Claude / Gemini / Grok / Qwen / Custom API

### Tools & Hotkeys
- ⌨️ **Global Hotkeys** (Customizable)
  - `Cmd+Shift+J` - Open chat dialog
  - `Cmd+Shift+T` - Translate clipboard text
  - `Cmd+Shift+L` - Analyze clipboard screenshot (with follow-up)
  - `Cmd+Shift+K` - Selection assistant toolbar
- ✂️ **Selection Assistant** - One-click translate, explain, summarize, or search selected text
- 🔄 **40+ Translation Languages** - Supports all major world languages (English, 简体中文, 繁體中文, Español, Français, Deutsch, 日本語, 한국어, and many more)

### Sync & Integrations
- 📓 **Obsidian Integration** - Auto-sync chats to Obsidian vault, one-click save valuable conversations
- 📝 **Notion Integration** - Daily chat summaries auto-sync to Notion, supports TodoList task creation

## 🎬 More Demos

<table>
  <tr>
    <td align="center">
      <img src="assets/chat-demo.gif" width="250px" /><br />
      <b>💬 AI Chat</b>
    </td>
    <td align="center">
      <img src="assets/sleeping.gif" width="250px" /><br />
      <b>😴 Sleeping</b>
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center">
      <i>...and more cute animations to discover!</i>
    </td>
  </tr>
</table>

## 📋 Requirements

- macOS 12.0 or later
- **Intel Mac** or **Apple Silicon (M1/M2/M3/M4)**
- AI Service (choose one):
  - **Cloud API**: OpenAI / Claude / Gemini / Grok / Qwen API Key (or API2D proxy)
  - **Local Model**: [Ollama](https://ollama.ai) + any model

## 🚀 Quick Start

### Option 1: Download Release (Recommended)

> 💡 No development tools needed! Download, unzip, and run.

1. Download **`Meowpal-Universal.zip`** from [Releases](https://github.com/liuchunchun1012/Meowpal/releases)
2. Unzip and drag `Meowpal.app` to Applications folder (optional)
3. Double-click to run. If blocked by macOS, go to **System Settings > Privacy & Security** and click **Open Anyway**
4. Click the 🐱 menu bar icon → **Settings**, choose AI provider and enter API Key

**Supported**: Intel Mac (x86_64) and Apple Silicon (M1/M2/M3/M4)

---

### Option 2: One-Click Install Script (For Local Models)

> 💡 Automatically installs Ollama and models, builds and launches the app.

```bash
git clone https://github.com/liuchunchun1012/Meowpal.git
cd Meowpal
./install.sh
```

The script will:
- Detect and install Command Line Tools
- Optionally install Homebrew and Ollama
- Optionally download recommended models (gemma3, qwen3, llava, etc.)
- Build and launch the app

---

### Option 3: Build from Source (Developers)

```bash
# Install Command Line Tools (if needed)
xcode-select --install

# Clone the project
git clone https://github.com/liuchunchun1012/Meowpal.git
cd Meowpal

# Build universal version (Intel + Apple Silicon)
./package_universal.sh

# Run
open Meowpal.app
```

---

## ⚙️ Configuration Guide

### Visual Settings (Recommended)

Click the 🐱 menu bar icon → **Settings** to configure:

| Tab | Options |
|-----|---------|
| **AI Settings** | Provider selection, API Key, Base URL, Model selection, Test connection |
| **Advanced** | Temperature, Top-P, Max Tokens, Web search toggle |
| **Appearance** | Custom sprite path |
| **Tools** | Selection assistant toggle, Translation target language |
| **Hotkeys** | Customize Chat/Translate/Image/Selection hotkeys |
| **Notion** | API Token, Database ID, Test connection |
| **Obsidian** | Vault path, Quick save folder |

### Supported AI Providers

| Provider | Description | Requires API Key |
|----------|-------------|------------------|
| **Ollama** | Local, completely free | ❌ |
| **OpenAI** | Latest models synced | ✅ |
| **Anthropic** | Latest models synced | ✅ |
| **Google Gemini** | Latest models synced | ✅ |
| **xAI Grok** | Latest models synced | ✅ |
| **Qwen** | Latest models synced | ✅ |
| **Custom API** | OpenAI-compatible services (e.g., API2D) | ✅ |

---

## 📖 Usage

### Basic Interactions

| Action | Description |
|--------|-------------|
| Drag | Move pet position |
| Click | Trigger jump animation |
| Hover | Trigger random interaction (belly rub / refuse) |
| Menu Bar Icon | Settings, switch action, quit |

### Hotkey Features

> 💡 All hotkeys can be customized in Settings → Hotkeys

#### 💬 Chat `Cmd+Shift+J`
Opens input box. Type and press Enter, your pet responds with AI. Supports follow-up questions!

#### 🌐 Translate `Cmd+Shift+T`
1. Select text → `Cmd+C` to copy
2. Press `Cmd+Shift+T`
3. Translation appears in chat bubble

#### 📸 Screenshot Analysis `Cmd+Shift+L`
1. Take a screenshot (recommend [Shottr](https://shottr.cc/) or WeChat screenshot)
2. Press `Cmd+Shift+L`, input box appears
3. Enter your question (e.g., "What's this?" "Help me with this problem")
4. Your pet analyzes the image and answers. **Follow-up supported!**

#### ✂️ Selection Assistant `Cmd+Shift+K`
1. Select any text → `Cmd+C` to copy
2. Press `Cmd+Shift+K`, toolbar appears near cursor
3. Click: Translate / Explain / Summarize / Search

### 💾 One-Click Save to Obsidian

Chat bubble has a save button in the top-right corner. Click to save **full conversation** (question + answer + image) to Obsidian vault.

---

## 📝 Project Structure

```
Meowpal/
├── Sources/Meowpal/
│   ├── Config.swift              # Pet name, default prompts
│   ├── AIProvider.swift          # AI provider protocol
│   ├── AIProviderManager.swift   # Unified provider management
│   ├── OllamaClient.swift        # Ollama local model
│   ├── OpenAICompatibleClient.swift  # OpenAI/Grok/Custom API
│   ├── AnthropicClient.swift     # Claude API
│   ├── GeminiClient.swift        # Gemini API
│   ├── SettingsWindow.swift      # Settings UI
│   ├── UserSettings.swift        # User config persistence
│   ├── KeychainHelper.swift      # API Key secure storage
│   ├── ChatBubbleView.swift      # Chat bubble (with save button)
│   ├── HotkeyManager.swift       # Hotkey management (customizable)
│   ├── ObsidianClient.swift      # Obsidian sync
│   ├── TextSelectionAssistant.swift  # Selection assistant core
│   ├── SelectionToolbarWindow.swift  # Selection toolbar UI
│   └── Resources/                # Sprites
├── install.sh                    # One-click install script
├── package_universal.sh          # Universal build (Intel + M-chip)
└── README.md
```

---

## 🐛 Troubleshooting

### Hotkeys not working?
1. Confirm app is running (cat icon in menu bar)
2. First run requires authorization in System Settings > Privacy & Security > Accessibility

### Pet not responding?

**Using Ollama:**
```bash
# Test if Ollama is running
curl http://localhost:11434/api/tags

# If no response, start Ollama
ollama serve
```

**Using Cloud API:**
- Check if API Key is correct
- Click Settings → Test Connection to verify

### Screenshot analysis not working?
Requires vision-capable model:
- Ollama: `gemma3`, `llava`, etc.
- Cloud: GPT-4o, Claude 3.5 Sonnet, Gemini, Grok 2 Vision, etc.

---

## 🛠️ Tech Stack

- **SwiftUI** - UI framework
- **AppKit** - Window management
- **Keychain Services** - API Key secure storage
- **Carbon Framework** - Global hotkeys

## 📜 License

This project is licensed under MIT License - see [LICENSE](LICENSE) file.

## 🎉 Credits

- Thanks to [Ollama](https://ollama.ai) for local LLM solution
- Pet sprite inspiration: [Stardew Valley]

### ☕ Supporters

| Supporter | Amount | Date | Note |
|-----------|--------|------|------|
| **peachesmeow** | ¥66.66 | 2025-12-21 | 🎉 First user and supporter of Meowpal! |

## 💖 Support the Project

If this project helps you:
- Give it a Star ⭐️
- Share with friends
- Submit Issues or PRs

If you'd like to buy me a coffee:

<table>
  <tr>
    <td align="center">
      <img src="assets/alipay.jpg" width="200px" /><br />
      <b>Alipay</b>
    </td>
    <td align="center">
      <img src="assets/wechat.jpg" width="200px" /><br />
      <b>WeChat</b>
    </td>
  </tr>
</table>

---

**Happy Coding!** 🐱
