## ADDED Requirements

### Requirement: Settings Window
系统 SHALL 提供图形化设置窗口，用户可配置应用的各项设置。

#### Scenario: 打开设置
- **WHEN** 用户点击菜单栏 → "⚙️ 设置..."
- **THEN** 系统 SHALL 显示设置窗口

#### Scenario: 设置分组显示
- **WHEN** 设置窗口打开
- **THEN** 系统 SHALL 以 Tab 页形式展示不同类别的设置

---

### Requirement: Custom Pet Sprites
系统 SHALL 允许用户自定义宠物精灵图。

#### Scenario: 导入自定义精灵图
- **WHEN** 用户在外观设置中选择自定义精灵图文件夹
- **THEN** 系统 SHALL 使用该文件夹中的图片作为宠物动画

#### Scenario: 重置为默认
- **WHEN** 用户点击"重置为默认"
- **THEN** 系统 SHALL 恢复使用内置精灵图

---

### Requirement: Translation Language Settings
系统 SHALL 允许用户配置翻译目标语言。

#### Scenario: 更改翻译语言
- **WHEN** 用户在语言设置中选择目标语言（如中文、英文、日文）
- **THEN** 系统 SHALL 将该语言用于后续翻译操作

#### Scenario: 持久化语言设置
- **WHEN** 用户更改翻译语言后关闭应用
- **THEN** 系统 SHALL 在下次启动时记住该设置

---

### Requirement: Ollama Model Selection
系统 SHALL 允许用户选择已安装的 Ollama 模型。

#### Scenario: 列出已安装模型
- **WHEN** 用户在 Ollama 设置中查看模型列表
- **THEN** 系统 SHALL 显示本地已安装的所有 Ollama 模型

#### Scenario: 切换模型
- **WHEN** 用户选择不同的 Ollama 模型
- **THEN** 系统 SHALL 使用新模型处理后续对话

---

### Requirement: Settings Persistence
系统 SHALL 持久化保存所有用户设置。

#### Scenario: 保存设置
- **WHEN** 用户修改任何设置
- **THEN** 系统 SHALL 立即保存到 UserDefaults 或配置文件

#### Scenario: 加载设置
- **WHEN** 应用启动
- **THEN** 系统 SHALL 自动加载用户保存的设置
