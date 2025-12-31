// 像素编辑器 - 格子填色版本

// 全局状态
const state = {
    currentColor: '#000000',
    canvases: {},
    contexts: {},
    pixelData: {}, // 存储每个视角的像素数据
    gridSize: 8, // 每个像素格子的大小（放大倍数）
    originalImages: {},
    versions: [],
    currentVersion: null,
    apiKey: '',
    imageWidth: 128,
    imageHeight: 128
};

// 初始化
document.addEventListener('DOMContentLoaded', () => {
    initPixelCanvases();
    loadApiKey();
    loadVersions();
});

// 初始化所有像素画布
function initPixelCanvases() {
    const views = ['front', 'back', 'left', 'right'];

    views.forEach(view => {
        const canvas = document.getElementById(`canvas-${view}`);
        const ctx = canvas.getContext('2d', { willReadFrequently: true });

        // Canvas 显示尺寸为 128x128 实际像素
        // 但我们用网格来编辑
        canvas.width = state.imageWidth;
        canvas.height = state.imageHeight;

        state.canvases[view] = canvas;
        state.contexts[view] = ctx;

        // 初始化像素数据（128x128 的二维数组）
        state.pixelData[view] = create2DArray(state.imageWidth, state.imageHeight, 'transparent');

        // 加载默认模板图作为参考
        loadDefaultTemplate(view);

        // 绑定点击事件（格子填色）
        canvas.addEventListener('click', (e) => fillPixel(e, view));
        canvas.addEventListener('mousemove', (e) => {
            if (e.buttons === 1) { // 鼠标左键按下时拖动填色
                fillPixel(e, view);
            }
        });

        // 绘制网格
        drawGrid(view);
    });
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

// 加载默认模板图（作为半透明参考）
function loadDefaultTemplate(view) {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
        const ctx = state.contexts[view];

        // 将模板图绘制到临时 canvas
        const tempCanvas = document.createElement('canvas');
        tempCanvas.width = state.imageWidth;
        tempCanvas.height = state.imageHeight;
        const tempCtx = tempCanvas.getContext('2d');

        tempCtx.drawImage(img, 0, 0, state.imageWidth, state.imageHeight);

        // 读取像素数据
        const imageData = tempCtx.getImageData(0, 0, state.imageWidth, state.imageHeight);
        const pixels = imageData.data;

        // 将模板图的像素转换为我们的 pixelData 格式（作为参考）
        for (let y = 0; y < state.imageHeight; y++) {
            for (let x = 0; x < state.imageWidth; x++) {
                const i = (y * state.imageWidth + x) * 4;
                const r = pixels[i];
                const g = pixels[i + 1];
                const b = pixels[i + 2];
                const a = pixels[i + 3];

                if (a > 0) {
                    const color = rgbToHex(r, g, b);
                    // 只在用户未填色时显示模板（半透明）
                    if (state.pixelData[view][y][x] === 'transparent') {
                        // 先不填充，只作为背景显示
                    }
                }
            }
        }

        // 绘制模板图作为背景（半透明）
        ctx.globalAlpha = 0.2;
        ctx.drawImage(img, 0, 0, state.imageWidth, state.imageHeight);
        ctx.globalAlpha = 1.0;

        // 绘制网格
        drawGrid(view);
    };
    img.src = `templates/${view}.png`;
}

// RGB 转 Hex
function rgbToHex(r, g, b) {
    return '#' + [r, g, b].map(x => {
        const hex = x.toString(16);
        return hex.length === 1 ? '0' + hex : hex;
    }).join('');
}

// 绘制网格线
function drawGrid(view) {
    const canvas = state.canvases[view];
    const ctx = state.contexts[view];

    // 绘制用户的像素
    renderPixels(view);

    // 绘制网格线（可选，更清晰）
    ctx.strokeStyle = 'rgba(200, 200, 200, 0.3)';
    ctx.lineWidth = 0.5;

    // 每 8 像素画一条粗线
    for (let x = 0; x <= state.imageWidth; x += 8) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, state.imageHeight);
        ctx.strokeStyle = 'rgba(150, 150, 150, 0.5)';
        ctx.lineWidth = 1;
        ctx.stroke();
    }

    for (let y = 0; y <= state.imageHeight; y += 8) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(state.imageWidth, y);
        ctx.strokeStyle = 'rgba(150, 150, 150, 0.5)';
        ctx.lineWidth = 1;
        ctx.stroke();
    }
}

// 渲染所有像素
function renderPixels(view) {
    const ctx = state.contexts[view];
    const data = state.pixelData[view];

    for (let y = 0; y < state.imageHeight; y++) {
        for (let x = 0; x < state.imageWidth; x++) {
            const color = data[y][x];
            if (color !== 'transparent') {
                ctx.fillStyle = color;
                ctx.fillRect(x, y, 1, 1);
            }
        }
    }
}

// 填充像素（点击格子）
function fillPixel(e, view) {
    const canvas = state.canvases[view];
    const rect = canvas.getBoundingClientRect();

    // 计算点击位置对应的像素坐标
    const scaleX = canvas.width / rect.width;
    const scaleY = canvas.height / rect.height;

    const pixelX = Math.floor((e.clientX - rect.left) * scaleX);
    const pixelY = Math.floor((e.clientY - rect.top) * scaleY);

    if (pixelX >= 0 && pixelX < state.imageWidth && pixelY >= 0 && pixelY < state.imageHeight) {
        // 更新像素数据
        state.pixelData[view][pixelY][pixelX] = state.currentColor;

        // 重新绘制
        redrawCanvas(view);

        // 保存原始图像
        saveOriginalImage(view);
    }
}

// 重新绘制整个 canvas
function redrawCanvas(view) {
    const ctx = state.contexts[view];

    // 清空画布
    ctx.clearRect(0, 0, state.imageWidth, state.imageHeight);

    // 重新加载模板图作为背景
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
        ctx.globalAlpha = 0.2;
        ctx.drawImage(img, 0, 0, state.imageWidth, state.imageHeight);
        ctx.globalAlpha = 1.0;

        // 绘制用户填色的像素
        renderPixels(view);

        // 绘制网格
        drawGrid(view);
    };
    img.src = `templates/${view}.png`;
}

// 清空画布
function clearCanvas(view) {
    // 重置像素数据
    state.pixelData[view] = create2DArray(state.imageWidth, state.imageHeight, 'transparent');

    // 重新绘制
    redrawCanvas(view);
}

// 设置当前颜色
function setColor(color) {
    state.currentColor = color;

    // 更新 UI
    document.querySelectorAll('.color-btn').forEach(btn => {
        btn.classList.remove('active');
    });

    // 高亮当前颜色按钮
    const target = event ? event.target : null;
    if (target) {
        target.classList.add('active');
    }

    // 更新当前颜色显示
    const displayEl = document.getElementById('currentColorDisplay');
    if (displayEl) {
        displayEl.style.background = color;
    }
}

// 设置橡皮擦（透明色）
function setEraser() {
    state.currentColor = 'transparent';

    //更新 UI
    document.querySelectorAll('.color-btn').forEach(btn => {
        btn.classList.remove('active');
    });

    // 更新当前颜色显示为透明
    const displayEl = document.getElementById('currentColorDisplay');
    if (displayEl) {
        displayEl.style.background = 'transparent';
        displayEl.style.borderStyle = 'dashed';
    }
}

// 保存用户绘制的原始图像
function saveOriginalImage(view) {
    const canvas = state.canvases[view];

    // 创建临时 canvas 只保存用户填色的部分（不含背景）
    const tempCanvas = document.createElement('canvas');
    tempCanvas.width = state.imageWidth;
    tempCanvas.height = state.imageHeight;
    const tempCtx = tempCanvas.getContext('2d');

    // 绘制用户像素
    const data = state.pixelData[view];
    for (let y = 0; y < state.imageHeight; y++) {
        for (let x = 0; x < state.imageWidth; x++) {
            const color = data[y][x];
            if (color !== 'transparent') {
                tempCtx.fillStyle = color;
                tempCtx.fillRect(x, y, 1, 1);
            }
        }
    }

    state.originalImages[view] = tempCanvas.toDataURL('image/png');
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

                // 绘制参考图（半透明）
                ctx.clearRect(0, 0, state.imageWidth, state.imageHeight);
                ctx.globalAlpha = 0.3;
                ctx.drawImage(img, 0, 0, state.imageWidth, state.imageHeight);
                ctx.globalAlpha = 1.0;

                // 绘制用户像素
                renderPixels(view);
                drawGrid(view);
            };
            img.src = event.target.result;
        };
        reader.readAsDataURL(file);
    };
    fileInput.click();
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
        alert('请至少填色 4 个视角的模版图！');
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
