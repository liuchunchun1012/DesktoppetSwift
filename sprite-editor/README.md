# 桌宠精灵生成器 🐱

一个基于 Web 的桌宠精灵图生成工具，通过 AI 技术将你设计的宠物外观应用到所有动作帧。

## 功能特点

- ✨ **4 视角编辑**：编辑正面、背面、左侧、右侧 4 个视角的宠物外观
- 🎨 **Canvas 绘图工具**：画笔、橡皮擦、调色板
- 🤖 **AI 生成**：使用 Gemini API 将你的设计应用到 74 帧动画
- 📦 **版本管理**：保存多个生成版本，随时切换
- 💾 **一键导出**：生成符合桌宠目录结构的 ZIP 文件

## 使用步骤

### 1. 准备 Gemini API Key

1. 访问 [Google AI Studio](https://aistudio.google.com/apikey)
2. 创建一个新的 API Key
3. 复制 API Key（格式：`AIza...`）

### 2. 启动编辑器

```bash
# 进入编辑器目录
cd sprite-editor

# 使用本地服务器打开（推荐）
python3 -m http.server 8000

# 或者使用 PHP
php -S localhost:8000

# 或者使用 Node.js
npx serve
```

然后在浏览器中打开：`http://localhost:8000`

### 3. 编辑宠物外观

1. **配置 API Key**：在页面顶部输入你的 Gemini API Key 并保存
2. **编辑 4 个视角**：
   - 正面视角（idle/grooming）
   - 背面视角（walk/up）
   - 左侧视角（walk/left）
   - 右侧视角（walk/right）
3. **使用绘图工具**：
   - 画笔：涂色
   - 橡皮擦：擦除
   - 调色板：选择颜色
   - 加载参考图：上传已有图片作为底图

### 4. 生成动画

1. 点击"🚀 生成精灵动画"按钮
2. 等待 AI 生成（约 5-10 分钟，取决于网络和 API 速度）
3. 生成完成后会自动保存为新版本

### 5. 下载和使用

1. 在"生成历史"中选择想要的版本
2. 点击"💾 下载 ZIP 文件"
3. 解压 ZIP 文件到任意位置
4. 在桌宠设置中：
   - 勾选"使用自定义精灵图"
   - 选择解压后的文件夹路径
   - 重启桌宠应用

## 技术架构

### 核心技术

- **前端**：纯 HTML5 + Canvas API + Vanilla JavaScript
- **AI 生成**：Gemini 2.0 Flash Exp (Vision API)
- **文件处理**：JSZip
- **存储**：LocalStorage（版本历史和设置）

### 文件结构

```
sprite-editor/
├── index.html              # 主界面
├── app.js                  # 核心逻辑
├── gemini-api.js           # Gemini API 集成
├── jszip.min.js            # ZIP 生成库
├── sprite-manifest.json    # 精灵图清单
├── templates/              # 4 个视角模版图
│   ├── front.png
│   ├── back.png
│   ├── left.png
│   └── right.png
└── README.md               # 说明文档
```

## AI 生成原理

### 工作流程

1. **用户输入**：用户绘制 4 个视角的宠物外观
2. **动作模版**：加载官方 nano banana 的所有动作帧（74 帧）
3. **风格迁移**：
   - 根据动作帧的视角，选择对应的用户模版
   - 调用 Gemini Vision API
   - Prompt：将动作保持不变，只替换宠物外观
4. **批量生成**：逐帧生成，保存为版本
5. **ZIP 导出**：按照桌宠目录结构打包

### Prompt 设计

```
任务：根据用户提供的宠物外观设计（第一张图），
      生成符合指定动作姿态（第二张图）的新精灵图。

要求：
1. 保持动作姿态：严格遵循第二张图的动作、姿势、比例
2. 替换外观：将宠物的颜色、花纹、特征替换为第一张图的样式
3. 视角一致：当前视角为 [front/back/left/right]
4. 像素风格：保持像素艺术风格，边缘清晰
5. 透明背景：背景必须完全透明
6. 尺寸统一：输出 128x128 像素的 PNG 图片
```

## 注意事项

### Gemini API 限制

⚠️ **重要**：Gemini 2.0 Flash Exp 目前主要用于视觉理解和文本生成，图像生成功能可能有限。

如果遇到图像生成失败，建议：

1. **使用 Imagen 3**：Google 的专业图像生成模型
2. **降级方案**：手动使用 Photoshop/GIMP 的批处理功能
3. **混合方案**：AI 生成关键帧，手动调整细节

### 性能优化

- 每次 API 调用间隔 200ms，避免限流
- 生成失败时自动回退到用户模版
- 所有原始图像完好保存，可重新生成

### 浏览器兼容性

- ✅ Chrome 90+
- ✅ Safari 14+
- ✅ Firefox 88+
- ✅ Edge 90+

## 常见问题

### Q: 生成速度很慢？

A: 74 帧的生成需要调用 74 次 Gemini API，每次约 2-3 秒，总计约 5-10 分钟。可以减少帧数或使用更快的 API。

### Q: API Key 安全吗？

A: API Key 仅保存在浏览器本地（LocalStorage），不会上传到任何服务器。建议使用有配额限制的 API Key。

### Q: 生成的图片质量不好？

A: 可以尝试：
- 更详细地描述 Prompt
- 调整 Gemini 的 temperature 参数
- 使用更高质量的用户模版图
- 手动微调生成的图片

### Q: 能否添加更多动作？

A: 可以！编辑 `sprite-manifest.json`，添加新的动作定义，并将对应的帧图片放到 `Sources/DesktoppetSwift/Resources/` 目录。

## 未来计划

- [ ] 支持更多视角（例如 8 方向）
- [ ] 实时预览动画播放
- [ ] 导出 GIF 动画
- [ ] 集成 Imagen 3 提升生成质量
- [ ] 支持批量编辑和样式预设
- [ ] 云端保存和分享

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License
