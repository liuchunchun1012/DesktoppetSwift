# 快速入门 🚀

## 5 分钟上手教程

### 第一步：启动编辑器

```bash
cd sprite-editor
./start-editor.sh
```

或者手动启动：

```bash
python3 -m http.server 8888
# 然后访问 http://localhost:8888
```

### 第二步：配置 API Key

1. 访问 [Google AI Studio](https://aistudio.google.com/apikey)
2. 创建新的 API Key
3. 复制 Key（格式：`AIzaSy...`）
4. 在编辑器顶部粘贴并点击"保存 API Key"

### 第三步：设计宠物外观（2 分钟）

编辑器提供 4 个视角的画布：

#### 方法 1：从零开始绘制

1. 选择画笔工具
2. 选择颜色
3. 在每个视角的画布上绘制你的宠物

#### 方法 2：上传参考图

1. 点击"📁 加载参考图"
2. 选择你的宠物图片
3. 图片会以半透明形式显示
4. 用画笔描绘轮廓和填色

**提示**：
- 4 个视角对应原版的关键帧：
  - 正面 = `idle/grooming/frame_03.png`
  - 背面 = `walk/up/frame_02.png`
  - 左侧 = `walk/left/frame_03.png`
  - 右侧 = `walk/right/frame_03.png`
- 你可以先加载这些原版图作为参考

### 第四步：生成动画（5-10 分钟）

1. 点击"🚀 生成精灵动画"按钮
2. 等待 AI 生成（进度会实时显示）
3. 生成完成后会自动保存为版本 1

**注意**：
- 总共需要生成 74 帧动画
- 每帧约 2-3 秒
- 可能需要 5-10 分钟

### 第五步：下载和使用

1. 在"生成历史"中选择版本
2. 点击"💾 下载 ZIP 文件"
3. 解压 ZIP 到任意位置
4. 打开桌宠应用设置：
   - ✅ 勾选"使用自定义精灵图"
   - 📁 选择解压后的文件夹
   - 🔄 重启桌宠

完成！你的自定义桌宠就活了！🎉

## 常见问题

### Q: 没有 Gemini API Key 怎么办？

A: 访问 https://aistudio.google.com/apikey 免费创建一个。免费额度足够测试使用。

### Q: 生成失败了怎么办？

A:
1. 检查 API Key 是否正确
2. 检查网络连接
3. 查看浏览器控制台的错误信息
4. 你的 4 张原图会完好保存，可以重新生成

### Q: 能否跳过某些动作？

A: 可以！编辑 `sprite-manifest.json`，删除不需要的动作条目。

### Q: 能否使用其他 AI 模型？

A: 可以修改 `gemini-api.js` 中的 API 端点，替换为其他支持图像生成的 API。

## 进阶技巧

### 1. 批量导出多个版本

每次生成都会保存为新版本，你可以：
- 生成多个风格
- 对比选择最佳版本
- 混合使用不同版本的帧

### 2. 手动微调

下载 ZIP 后，可以用图片编辑器手动调整：
- 调整颜色
- 修复瑕疵
- 添加细节

### 3. 自定义动作

1. 在 `Sources/DesktoppetSwift/Resources/` 添加新动作的帧图片
2. 更新 `sprite-manifest.json` 添加动作定义
3. 重新生成

## 故障排除

### 错误：CORS 问题

如果浏览器报 CORS 错误：
```bash
# 使用带 CORS 支持的服务器
python3 -m http.server --bind 127.0.0.1 8888
```

### 错误：API 限流

如果遇到 429 错误（Too Many Requests）：
1. 增加 `gemini-api.js` 中的 `sleep` 延迟（当前 200ms）
2. 等待一段时间后重试
3. 升级到付费 API 配额

### 错误：图片加载失败

检查路径是否正确：
```javascript
// gemini-api.js 中的路径映射
img.src = `../Sources/DesktoppetSwift/Resources/${path}`;
```

确保精灵图文件存在。

## 资源链接

- [Gemini API 文档](https://ai.google.dev/docs)
- [桌宠主项目](https://github.com/yourusername/myDesktoppetSwift)
- [问题反馈](https://github.com/yourusername/myDesktoppetSwift/issues)

Happy Coding! 🐱✨
