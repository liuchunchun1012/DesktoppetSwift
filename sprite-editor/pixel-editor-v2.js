// 像素块填色编辑器 V2 - 真正的格子填色

const state = {
    currentView: 'front', // 当前编辑的视角
    currentColor: '#000000',
    canvases: {},
    contexts: {},
    pixelData: {}, // 存储像素数据
    originalImages: {},
    versions: [],
    currentVersion: null,
    apiKey: '',

    // 画布配置
    pixelSize: 128, // 实际精灵图尺寸 128x128
    baseDisplaySize: 640, // 基础显示尺寸
    zoom: 1.0, // 缩放比例
    minZoom: 0.5, // 最小缩放
    maxZoom: 4.0, // 最大缩放（可以放大到 4 倍）

    // 历史记录（用于撤销/重做）
    history: {},
    historyIndex: {},
    maxHistory: 50
};

// 计算当前显示尺寸
function getDisplaySize() {
    return Math.round(state.baseDisplaySize * state.zoom);
}

// 计算网格大小
function getGridSize() {
    return getDisplaySize() / state.pixelSize;
}

// 初始化
document.addEventListener('DOMContentLoaded', () => {
    initEditor();
    loadApiKey();
    loadVersions();
});

// 初始化编辑器
function initEditor() {
    const views = ['front', 'back', 'left', 'right'];

    views.forEach(view => {
        // 初始化像素数据
        state.pixelData[view] = create2DArray(state.pixelSize, state.pixelSize, null);

        // 初始化历史记录
        state.history[view] = [];
        state.historyIndex[view] = -1;
    });

    // 显示第一个视角
    switchView('front');

    // 设置快捷键
    setupKeyboardShortcuts();
}

// 创建二维数组
function create2DArray(width, height, defaultValue) {
    const arr = [];
    for (let y = 0; y < height; y++) {
        arr[y] = [];
        for (let x = 0; x < width; x++) {
            arr[y][x] = defaultValue;
        }
    }
    return arr;
}

// 切换视角
function switchView(view) {
    state.currentView = view;

    // 更新按钮状态
    document.querySelectorAll('.view-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    document.getElementById(`view-${view}`).classList.add('active');

    // 重新渲染画布
    renderCanvas();
}

// 渲染画布
function renderCanvas() {
    const canvas = document.getElementById('mainCanvas');
    const ctx = canvas.getContext('2d');

    const displaySize = getDisplaySize();

    // 设置画布尺寸
    canvas.width = displaySize;
    canvas.height = displaySize;

    // 更新缩放显示
    updateZoomDisplay();

    // 清空画布
    ctx.clearRect(0, 0, displaySize, displaySize);

    // 加载并显示模板图（半透明背景）
    loadTemplateBackground(state.currentView, ctx);

    // 绘制用户填色的像素
    drawPixels(ctx);

    // 绘制网格
    drawGrid(ctx);
}

// 加载模板图作为背景
function loadTemplateBackground(view, ctx) {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
        const displaySize = getDisplaySize();
        ctx.globalAlpha = 0.2;
        ctx.drawImage(img, 0, 0, displaySize, displaySize);
        ctx.globalAlpha = 1.0;

        // 重新绘制像素和网格
        drawPixels(ctx);
        drawGrid(ctx);
    };
    img.src = `templates/${view}.png`;
}

// 绘制用户填色的像素
function drawPixels(ctx) {
    const data = state.pixelData[state.currentView];
    const gridSize = getGridSize();

    for (let y = 0; y < state.pixelSize; y++) {
        for (let x = 0; x < state.pixelSize; x++) {
            const color = data[y][x];
            if (color) {
                ctx.fillStyle = color;
                // 每个像素格子放大 gridSize 倍
                ctx.fillRect(
                    x * gridSize,
                    y * gridSize,
                    gridSize,
                    gridSize
                );
            }
        }
    }
}

// 绘制网格线
function drawGrid(ctx) {
    const gridSize = getGridSize();
    const displaySize = getDisplaySize();

    ctx.strokeStyle = 'rgba(0, 0, 0, 0.1)';
    ctx.lineWidth = 0.5;

    // 绘制每个像素格子的边框
    for (let x = 0; x <= state.pixelSize; x++) {
        ctx.beginPath();
        ctx.moveTo(x * gridSize, 0);
        ctx.lineTo(x * gridSize, displaySize);

        // 每 8 格画粗线
        if (x % 8 === 0) {
            ctx.strokeStyle = 'rgba(0, 0, 0, 0.3)';
            ctx.lineWidth = 1;
        } else {
            ctx.strokeStyle = 'rgba(0, 0, 0, 0.1)';
            ctx.lineWidth = 0.5;
        }
        ctx.stroke();
    }

    for (let y = 0; y <= state.pixelSize; y++) {
        ctx.beginPath();
        ctx.moveTo(0, y * gridSize);
        ctx.lineTo(displaySize, y * gridSize);

        if (y % 8 === 0) {
            ctx.strokeStyle = 'rgba(0, 0, 0, 0.3)';
            ctx.lineWidth = 1;
        } else {
            ctx.strokeStyle = 'rgba(0, 0, 0, 0.1)';
            ctx.lineWidth = 0.5;
        }
        ctx.stroke();
    }
}

// 设置画布事件
function setupCanvasEvents() {
    const canvas = document.getElementById('mainCanvas');

    // 点击填色
    canvas.addEventListener('click', handleCanvasClick);

    // 拖动填色
    let isDrawing = false;
    canvas.addEventListener('mousedown', (e) => {
        isDrawing = true;
        handleCanvasClick(e);
    });
    canvas.addEventListener('mousemove', (e) => {
        if (isDrawing) {
            handleCanvasClick(e);
        }
    });
    canvas.addEventListener('mouseup', () => {
        isDrawing = false;
    });
    canvas.addEventListener('mouseleave', () => {
        isDrawing = false;
    });
}

// 处理画布点击
function handleCanvasClick(e) {
    const canvas = document.getElementById('mainCanvas');
    const rect = canvas.getBoundingClientRect();
    const gridSize = getGridSize();

    // 计算点击位置对应的像素坐标
    const x = Math.floor((e.clientX - rect.left) / gridSize);
    const y = Math.floor((e.clientY - rect.top) / gridSize);

    if (x >= 0 && x < state.pixelSize && y >= 0 && y < state.pixelSize) {
        // 填色
        state.pixelData[state.currentView][y][x] = state.currentColor;

        // 重新渲染
        renderCanvas();
    }
}

// 设置颜色
function setColor(color, event) {
    state.currentColor = color;

    // 更新 UI
    document.querySelectorAll('.color-btn').forEach(btn => {
        btn.classList.remove('active');
    });

    if (event && event.target) {
        event.target.classList.add('active');
    }

    // 更新颜色显示
    const display = document.getElementById('currentColorDisplay');
    if (display) {
        display.style.background = color;
        display.style.borderStyle = 'solid';
    }
}

// 设置橡皮擦
function setEraser() {
    state.currentColor = null;

    // 更新 UI
    document.querySelectorAll('.color-btn').forEach(btn => {
        btn.classList.remove('active');
    });

    const display = document.getElementById('currentColorDisplay');
    if (display) {
        display.style.background = 'transparent';
        display.style.borderStyle = 'dashed';
    }
}

// 清空当前视角
function clearCanvas(view) {
    if (!view) view = state.currentView;

    state.pixelData[view] = create2DArray(state.pixelSize, state.pixelSize, null);

    if (view === state.currentView) {
        renderCanvas();
    }
}

// 加载参考图
function loadTemplate(view) {
    if (!view) view = state.currentView;

    const fileInput = document.getElementById('fileInput');
    fileInput.onchange = (e) => {
        const file = e.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (event) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.getElementById('mainCanvas');
                const ctx = canvas.getContext('2d');

                // 清空并绘制参考图
                ctx.clearRect(0, 0, state.displaySize, state.displaySize);
                ctx.globalAlpha = 0.3;
                ctx.drawImage(img, 0, 0, state.displaySize, state.displaySize);
                ctx.globalAlpha = 1.0;

                // 重新绘制像素和网格
                drawPixels(ctx);
                drawGrid(ctx);
            };
            img.src = event.target.result;
        };
        reader.readAsDataURL(file);
    };
    fileInput.click();
}

// 保存当前视角的图像
function saveCurrentViewImage() {
    const canvas = document.createElement('canvas');
    canvas.width = state.pixelSize;
    canvas.height = state.pixelSize;
    const ctx = canvas.getContext('2d');

    const data = state.pixelData[state.currentView];

    for (let y = 0; y < state.pixelSize; y++) {
        for (let x = 0; x < state.pixelSize; x++) {
            const color = data[y][x];
            if (color) {
                ctx.fillStyle = color;
                ctx.fillRect(x, y, 1, 1);
            }
        }
    }

    state.originalImages[state.currentView] = canvas.toDataURL('image/png');
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

    // 保存所有视角的图像
    ['front', 'back', 'left', 'right'].forEach(view => {
        const tempView = state.currentView;
        state.currentView = view;
        saveCurrentViewImage();
        state.currentView = tempView;
    });

    if (Object.keys(state.originalImages).length < 4) {
        alert('请完成 4 个视角的填色！');
        return;
    }

    const statusBox = document.getElementById('statusBox');
    const statusText = document.getElementById('statusText');
    const generateBtn = document.getElementById('generateBtn');

    statusBox.className = 'status-box generating';
    statusText.innerHTML = '<div class="spinner"></div>正在生成中，请稍候...';
    generateBtn.disabled = true;

    try {
        const version = {
            id: Date.now(),
            timestamp: new Date().toISOString(),
            userTemplates: { ...state.originalImages },
            generatedSprites: {}
        };

        await generateAllAnimations(version);

        state.versions.unshift(version);
        state.currentVersion = version.id;
        saveVersions();

        statusBox.className = 'status-box success';
        statusText.innerHTML = '✅ 生成成功！';

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

async function generateAllAnimations(version) {
    const manifest = await fetch('sprite-manifest.json').then(r => r.json());

    const progressCallback = (current, total, message) => {
        const progress = Math.round((current / total) * 100);
        document.getElementById('statusText').innerHTML =
            `<div class="spinner"></div>${message}<br>进度: ${current}/${total} (${progress}%)`;
    };

    const generatedSprites = await window.GeminiAPI.generateAllSprites(
        state.apiKey,
        state.originalImages,
        manifest,
        progressCallback
    );

    version.generatedSprites = generatedSprites;
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

    const img = new Image();
    img.onload = () => {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.drawImage(img, 0, 0, 128, 128);
    };
    img.src = version.userTemplates.front;
}

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

        for (const [path, base64Data] of Object.entries(version.generatedSprites)) {
            const base64 = base64Data.split(',')[1];
            zip.file(path, base64, { base64: true });
        }

        const blob = await zip.generateAsync({
            type: 'blob',
            compression: 'DEFLATE',
            compressionOptions: { level: 6 }
        });

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

function resetStatus() {
    const statusBox = document.getElementById('statusBox');
    statusBox.className = 'status-box';
    document.getElementById('statusText').textContent = '准备就绪，点击下方按钮开始生成';
}

// 初始化画布事件
window.addEventListener('load', () => {
    setupCanvasEvents();
});

// ==================== 缩放功能 ====================

// 缩放画布
function zoomCanvas(delta) {
    const oldZoom = state.zoom;
    state.zoom += delta;
    state.zoom = Math.max(state.minZoom, Math.min(state.maxZoom, state.zoom));

    if (oldZoom !== state.zoom) {
        renderCanvas();
    }
}

// 更新缩放显示
function updateZoomDisplay() {
    const zoomPercent = Math.round(state.zoom * 100);
    const display = document.getElementById('zoomDisplay');
    if (display) {
        display.textContent = `${zoomPercent}%`;
    }
}

// 重置缩放
function resetZoom() {
    state.zoom = 1.0;
    renderCanvas();
}

// ==================== 历史记录（撤销/重做）====================

// 保存当前状态到历史
function saveToHistory() {
    const view = state.currentView;

    // 深拷贝当前像素数据
    const snapshot = JSON.parse(JSON.stringify(state.pixelData[view]));

    // 删除当前索引之后的历史
    state.history[view] = state.history[view].slice(0, state.historyIndex[view] + 1);

    // 添加新快照
    state.history[view].push(snapshot);

    // 限制历史记录数量
    if (state.history[view].length > state.maxHistory) {
        state.history[view].shift();
    } else {
        state.historyIndex[view]++;
    }

    updateUndoRedoButtons();
}

// 撤销
function undo() {
    const view = state.currentView;

    if (state.historyIndex[view] > 0) {
        state.historyIndex[view]--;
        state.pixelData[view] = JSON.parse(JSON.stringify(state.history[view][state.historyIndex[view]]));
        renderCanvas();
        updateUndoRedoButtons();
    }
}

// 重做
function redo() {
    const view = state.currentView;

    if (state.historyIndex[view] < state.history[view].length - 1) {
        state.historyIndex[view]++;
        state.pixelData[view] = JSON.parse(JSON.stringify(state.history[view][state.historyIndex[view]]));
        renderCanvas();
        updateUndoRedoButtons();
    }
}

// 更新撤销/重做按钮状态
function updateUndoRedoButtons() {
    const view = state.currentView;
    const undoBtn = document.getElementById('undoBtn');
    const redoBtn = document.getElementById('redoBtn');

    if (undoBtn) {
        undoBtn.disabled = state.historyIndex[view] <= 0;
    }

    if (redoBtn) {
        redoBtn.disabled = state.historyIndex[view] >= state.history[view].length - 1;
    }
}

// ==================== 快捷键 ====================

function setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
        // Ctrl/Cmd + Z: 撤销
        if ((e.ctrlKey || e.metaKey) && e.key === 'z' && !e.shiftKey) {
            e.preventDefault();
            undo();
        }

        // Ctrl/Cmd + Shift + Z 或 Ctrl/Cmd + Y: 重做
        if ((e.ctrlKey || e.metaKey) && (e.shiftKey && e.key === 'z' || e.key === 'y')) {
            e.preventDefault();
            redo();
        }

        // +/=: 放大
        if (e.key === '+' || e.key === '=') {
            e.preventDefault();
            zoomCanvas(0.05);
        }

        // -: 缩小
        if (e.key === '-') {
            e.preventDefault();
            zoomCanvas(-0.05);
        }

        // 0: 重置缩放
        if (e.key === '0') {
            e.preventDefault();
            resetZoom();
        }

        // E: 橡皮擦
        if (e.key === 'e' || e.key === 'E') {
            setEraser();
        }
    });
}

// 设置画布滚轮缩放
function setupCanvasZoom() {
    const canvas = document.getElementById('mainCanvas');

    canvas.addEventListener('wheel', (e) => {
        e.preventDefault();

        // 降低滚轮灵敏度
        const delta = e.deltaY > 0 ? -0.05 : 0.05;
        zoomCanvas(delta);
    }, { passive: false });
}

// ==================== 初始化画布事件（重写）====================

// 初始化画布事件
window.addEventListener('load', () => {
    setupCanvasEvents();
    setupCanvasZoom();

    // 初始保存一次历史
    Object.keys(state.pixelData).forEach(view => {
        const snapshot = JSON.parse(JSON.stringify(state.pixelData[view]));
        state.history[view].push(snapshot);
        state.historyIndex[view] = 0;
    });

    updateUndoRedoButtons();
});

// 重写 handleCanvasClick 以支持历史记录
const originalHandleCanvasClick = handleCanvasClick;

window.handleCanvasClick = function(e) {
    // 保存操作前的状态
    const view = state.currentView;
    const oldData = JSON.parse(JSON.stringify(state.pixelData[view]));

    // 执行填色
    const canvas = document.getElementById('mainCanvas');
    const rect = canvas.getBoundingClientRect();
    const gridSize = getGridSize();

    const x = Math.floor((e.clientX - rect.left) / gridSize);
    const y = Math.floor((e.clientY - rect.top) / gridSize);

    if (x >= 0 && x < state.pixelSize && y >= 0 && y < state.pixelSize) {
        state.pixelData[view][y][x] = state.currentColor;
        renderCanvas();

        // 检查是否有变化，有则保存
        if (JSON.stringify(oldData) !== JSON.stringify(state.pixelData[view])) {
            // 延迟保存，避免拖动时频繁保存
            clearTimeout(window.historySaveTimeout);
            window.historySaveTimeout = setTimeout(() => {
                saveToHistory();
            }, 300);
        }
    }
};

handleCanvasClick = window.handleCanvasClick;
