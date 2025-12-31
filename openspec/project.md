# Project Context

## Purpose
DesktoppetSwift 是一个桌面宠物应用，让可爱的像素风格猫咪住在用户桌面上。宠物由本地 AI 驱动，支持智能对话、翻译、截图分析等功能。
该项目最初为 macOS 开发，目前正在扩展以支持 Windows 平台。

**核心价值**：为用户提供陪伴感和实用的 AI 助手功能。

## Tech Stack
### macOS (DesktoppetSwift)
- **语言**: Swift 5.9+
- **UI 框架**: SwiftUI + AppKit (窗口管理)
- **快捷键**: Carbon Framework
- **构建**: Swift Package Manager

### Windows (Desktoppet-RS) [Planning]
- **底座**: Tauri v2 (Rust + Webview2)
- **UI 框架**: React + Tailwind CSS
- **集成**: Rust (Windows API)

### 共享组件
- **AI 逻辑**: 统一的 AI Provider 协议（macOS 使用 Swift 实现，Windows 使用 Rust 或 JS 实现）
- **监控服务**: Python MCP Server (HTTP/JSON)
- **资源**: 通用的像素精灵图 (Resources/sprites_aligned)

## Project Conventions

### Code Style
- macOS: Swift 命名规范 (camelCase)
- Windows: Rust/JS 命名规范 (snake_case/camelCase)

### Architecture Patterns
- **单例模式**: AI 客户端单例管理
- **跨端协作**: 通过 `~/.desktoppet/ide-status/` 文件或 MCP 服务器同步状态
- **提供商模式**: 统一的 `AIProvider` 接口

## Roadmap
- [x] macOS 1.0 Release
- [/] Windows Porting (Design Phase)
- [ ] Cross-platform Animation Engine
- [ ] Universal Desktop Pet Ecosystem

## Important Constraints
- 必须保持轻量级，避免过度消耗资源。
- 保证离线可用性（优先支持 Ollama）。
- 透明窗口和置顶显示是核心交互要求。
