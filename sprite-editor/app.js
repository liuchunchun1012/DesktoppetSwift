// 全局状态
const state = {
    currentTool: 'brush',
    currentColor: '#000000',
    brushSize: 5,
    canvases: {},
    contexts: {},
    isDrawing: false,
    currentCanvas: null,
    originalImages: {}, // 保存用户的原始4张图
    versions: [], // 生成历史
    currentVersion: null,
    apiKey: ''
};

// 初始化
document.addEventListener('DOMContentLoaded', () => {
    initCanvases();
    loadApiKey();
    loadVersions();
    setupBrushSizeSlider();
});

// 初始化所有 Canvas
function initCanvases() {
    const views = ['front', 'back', 'left', 'right'];

    views.forEach(view => {
        const canvas = document.getElementById(`canvas-${view}`);
        const ctx = canvas.getContext('2d', { willReadFrequently: true });

        state.canvases[view] = canvas;
        state.contexts[view] = ctx;

        // 设置白色背景
        ctx.fillStyle = 'white';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // 加载默认模板图
        loadDefaultTemplate(view);

        // 绑定鼠标事件
        canvas.addEventListener('mousedown', (e) => startDrawing(e, view));
        canvas.addEventListener('mousemove', (e) => draw(e, view));
        canvas.addEventListener('mouseup', () => stopDrawing());
        canvas.addEventListener('mouseleave', () => stopDrawing());

        // 触摸事件支持
        canvas.addEventListener('touchstart', (e) => {
            e.preventDefault();
            const touch = e.touches[0];
            const mouseEvent = new MouseEvent('mousedown', {
                clientX: touch.clientX,
                clientY: touch.clientY
            });
            canvas.dispatchEvent(mouseEvent);
        });

        canvas.addEventListener('touchmove', (e) => {
            e.preventDefault();
            const touch = e.touches[0];
            const mouseEvent = new MouseEvent('mousemove', {
                clientX: touch.clientX,
                clientY: touch.clientY
            });
            canvas.dispatchEvent(mouseEvent);
        });

        canvas.addEventListener('touchend', (e) => {
            e.preventDefault();
            stopDrawing();
        });
    });
}

// 加载默认模板图
function loadDefaultTemplate(view) {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
        const ctx = state.contexts[view];
        // 清空画布
        ctx.fillStyle = 'white';
        ctx.fillRect(0, 0, 128, 128);
        // 绘制模板图（半透明）
        ctx.globalAlpha = 0.3;
        ctx.drawImage(img, 0, 0, 128, 128);
        ctx.globalAlpha = 1.0;
    };
    img.src = `templates/${view}.png`;
}

// 加载用户上传的参考图
function loadTemplate(view) {
    const fileInput = document.getElementById('fileInput');
    fileInput.onchange = (e) => {
        const file = e.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (event) => {
            const img = new Image();
            img.onload = () => {
                const ctx = state.contexts[view];
                ctx.fillStyle = 'white';
                ctx.fillRect(0, 0, 128, 128);
                ctx.globalAlpha = 0.5;
                ctx.drawImage(img, 0, 0, 128, 128);
                ctx.globalAlpha = 1.0;
            };
            img.src = event.target.result;
        };
        reader.readAsDataURL(file);
    };
    fileInput.click();
}

// 清空画布
function clearCanvas(view) {
    const ctx = state.contexts[view];
    ctx.fillStyle = 'white';
    ctx.fillRect(0, 0, 128, 128);
    // 重新加载模板
    loadDefaultTemplate(view);
}

// 设置工具
function setTool(tool) {
    state.currentTool = tool;
    document.getElementById('brush-tool').classList.toggle('active', tool === 'brush');
    document.getElementById('eraser-tool').classList.toggle('active', tool === 'eraser');
}

// 设置颜色
function setColor(color) {
    state.currentColor = color;
    document.querySelectorAll('.color-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    event.target.classList.add('active');
}

// 设置画笔大小
function setupBrushSizeSlider() {
    const slider = document.getElementById('brushSize');
    const value = document.getElementById('brushSizeValue');

    slider.addEventListener('input', (e) => {
        state.brushSize = parseInt(e.target.value);
        value.textContent = state.brushSize;
    });
}

// 开始绘制
function startDrawing(e, view) {
    state.isDrawing = true;
    state.currentCanvas = view;
    draw(e, view);
}

// 绘制
function draw(e, view) {
    if (!state.isDrawing || state.currentCanvas !== view) return;

    const canvas = state.canvases[view];
    const ctx = state.contexts[view];
    const rect = canvas.getBoundingClientRect();
    const x = (e.clientX - rect.left) * (canvas.width / rect.width);
    const y = (e.clientY - rect.top) * (canvas.height / rect.height);

    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.lineWidth = state.brushSize;

    if (state.currentTool === 'brush') {
        ctx.globalCompositeOperation = 'source-over';
        ctx.strokeStyle = state.currentColor;
    } else {
        ctx.globalCompositeOperation = 'destination-out';
    }

    ctx.lineTo(x, y);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(x, y);
}

// 停止绘制
function stopDrawing() {
    if (state.isDrawing) {
        state.isDrawing = false;
        const view = state.currentCanvas;
        if (view) {
            state.contexts[view].beginPath();
            // 保存原始图像
            saveOriginalImage(view);
        }
    }
}

// 保存用户绘制的原始图像
function saveOriginalImage(view) {
    const canvas = state.canvases[view];
    state.originalImages[view] = canvas.toDataURL('image/png');
}

// API Key 管理
function loadApiKey() {
    const saved = localStorage.getItem('gemini_api_key');
    if (saved) {
        state.apiKey = saved;
        document.getElementById('apiKeyInput').value = saved;
    }
}

function saveApiKey() {
    const input = document.getElementById('apiKeyInput');
    state.apiKey = input.value.trim();
    localStorage.setItem('gemini_api_key', state.apiKey);
    alert('API Key 已保存！');
}

// 生成精灵动画
async function generateSprites() {
    if (!state.apiKey) {
        alert('请先配置 Gemini API Key！');
        return;
    }

    // 保存所有原始图像
    ['front', 'back', 'left', 'right'].forEach(view => {
        saveOriginalImage(view);
    });

    // 检查是否有绘制内容
    if (Object.keys(state.originalImages).length < 4) {
        alert('请至少绘制 4 个视角的模版图！');
        return;
    }

    const statusBox = document.getElementById('statusBox');
    const statusText = document.getElementById('statusText');
    const generateBtn = document.getElementById('generateBtn');

    statusBox.className = 'status-box generating';
    statusText.innerHTML = '<div class="spinner"></div>正在生成中，请稍候...';
    generateBtn.disabled = true;

    try {
        // 创建新版本
        const version = {
            id: Date.now(),
            timestamp: new Date().toISOString(),
            userTemplates: { ...state.originalImages },
            generatedSprites: {}
        };

        // 调用 Gemini API 生成所有动作帧
        statusText.innerHTML = '<div class="spinner"></div>正在调用 AI 生成动画...';

        // TODO: 实际调用 Gemini API
        // 这里先模拟生成过程
        await generateAllAnimations(version);

        // 保存版本
        state.versions.unshift(version);
        state.currentVersion = version.id;
        saveVersions();

        statusBox.className = 'status-box success';
        statusText.innerHTML = '✅ 生成成功！';

        // 显示版本列表
        renderVersionList();
        document.getElementById('versionSection').classList.remove('hidden');
        document.getElementById('noVersions').classList.add('hidden');

    } catch (error) {
        console.error('生成失败:', error);
        statusBox.className = 'status-box error';
        statusText.innerHTML = `❌ 生成失败: ${error.message}<br><button class="btn btn-secondary" onclick="resetStatus()" style="margin-top: 10px;">重试</button>`;
    } finally {
        generateBtn.disabled = false;
    }
}

// 生成所有动画帧（使用 Gemini API）
async function generateAllAnimations(version) {
    // 读取动作清单
    const manifest = await fetch('sprite-manifest.json').then(r => r.json());

    // 使用 Gemini API 批量生成
    const progressCallback = (current, total, message) => {
        const progress = Math.round((current / total) * 100);
        document.getElementById('statusText').innerHTML =
            `<div class="spinner"></div>${message}<br>进度: ${current}/${total} (${progress}%)`;
    };

    try {
        const generatedSprites = await window.GeminiAPI.generateAllSprites(
            state.apiKey,
            state.originalImages,
            manifest,
            progressCallback
        );

        version.generatedSprites = generatedSprites;
    } catch (error) {
        throw new Error(`AI 生成失败: ${error.message}`);
    }
}

// 版本管理
function saveVersions() {
    localStorage.setItem('sprite_versions', JSON.stringify(state.versions));
}

function loadVersions() {
    const saved = localStorage.getItem('sprite_versions');
    if (saved) {
        state.versions = JSON.parse(saved);
        if (state.versions.length > 0) {
            state.currentVersion = state.versions[0].id;
            renderVersionList();
            document.getElementById('versionSection').classList.remove('hidden');
            document.getElementById('noVersions').classList.add('hidden');
        }
    }
}

function renderVersionList() {
    const listEl = document.getElementById('versionList');
    listEl.innerHTML = '';

    state.versions.forEach((version, index) => {
        const item = document.createElement('div');
        item.className = 'version-item';
        if (version.id === state.currentVersion) {
            item.classList.add('active');
        }

        const date = new Date(version.timestamp);
        const timeStr = date.toLocaleString('zh-CN');

        item.innerHTML = `
            <div class="version-info">
                <div style="font-weight: 600;">版本 ${state.versions.length - index}</div>
                <div class="version-time">${timeStr}</div>
            </div>
            <button class="btn btn-secondary" onclick="selectVersion(${version.id})">
                ${version.id === state.currentVersion ? '✨ 当前' : '选择'}
            </button>
        `;

        listEl.appendChild(item);
    });

    // 更新预览
    updatePreview();
}

function selectVersion(versionId) {
    state.currentVersion = versionId;
    renderVersionList();
}

function updatePreview() {
    const version = state.versions.find(v => v.id === state.currentVersion);
    if (!version) return;

    const canvas = document.getElementById('previewCanvas');
    const ctx = canvas.getContext('2d');

    // 显示正面视角
    const img = new Image();
    img.onload = () => {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.drawImage(img, 0, 0, 128, 128);
    };
    img.src = version.userTemplates.front;
}

// 下载 ZIP
async function downloadZip() {
    const version = state.versions.find(v => v.id === state.currentVersion);
    if (!version) {
        alert('请先选择一个版本！');
        return;
    }

    if (!version.generatedSprites || Object.keys(version.generatedSprites).length === 0) {
        alert('该版本没有生成的精灵图！');
        return;
    }

    try {
        const zip = new JSZip();

        // 按照桌宠目录结构组织文件
        for (const [path, base64Data] of Object.entries(version.generatedSprites)) {
            // path 格式: "eating/frame_01.png"
            // 移除 data:image/png;base64, 前缀
            const base64 = base64Data.split(',')[1];
            zip.file(path, base64, { base64: true });
        }

        // 生成 ZIP 文件
        const blob = await zip.generateAsync({
            type: 'blob',
            compression: 'DEFLATE',
            compressionOptions: { level: 6 }
        });

        // 下载
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `custom-sprite-${version.id}.zip`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        alert('下载成功！\n\n解压后直接在桌宠设置中选择该文件夹即可使用。');

    } catch (error) {
        console.error('生成 ZIP 失败:', error);
        alert(`生成 ZIP 失败: ${error.message}`);
    }
}

// 重置状态
function resetStatus() {
    const statusBox = document.getElementById('statusBox');
    statusBox.className = 'status-box';
    document.getElementById('statusText').textContent = '准备就绪，点击下方按钮开始生成';
}
