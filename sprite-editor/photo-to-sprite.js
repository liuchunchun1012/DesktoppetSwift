/**
 * 照片转桌宠精灵 - 主逻辑
 */

const state = {
    apiKey: '',
    uploadedPhoto: null,
    uploadedPhotoBase64: null,
    pixelizedPhoto: null,
    styleReferenceBase64: null,
    generatedSprites: null
};

// 初始化
document.addEventListener('DOMContentLoaded', () => {
    loadApiKey();
    setupDragDrop();
    setupFileInput();
});

// API Key 管理
function saveApiKey() {
    const apiKey = document.getElementById('apiKeyInput').value.trim();
    if (!apiKey) {
        alert('请输入有效的 API Key！');
        return;
    }
    state.apiKey = apiKey;
    localStorage.setItem('gemini_api_key', apiKey);

    // 保存模型选择
    const model = document.getElementById('modelSelect').value;
    state.selectedModel = model;
    localStorage.setItem('gemini_model', model);

    alert('配置已保存！');
}

function loadApiKey() {
    const saved = localStorage.getItem('gemini_api_key');
    if (saved) {
        state.apiKey = saved;
        const input = document.getElementById('apiKeyInput');
        if (input) {
            input.value = saved;
        }
    }

    // 加载模型选择
    const savedModel = localStorage.getItem('gemini_model');
    if (savedModel) {
        state.selectedModel = savedModel;
        const select = document.getElementById('modelSelect');
        if (select) {
            select.value = savedModel;
        }
    } else {
        state.selectedModel = 'gemini-3-pro-image-preview';
    }
}

// 拖拽上传
function setupDragDrop() {
    const uploadSection = document.getElementById('uploadSection');

    uploadSection.addEventListener('dragover', (e) => {
        e.preventDefault();
        uploadSection.classList.add('dragging');
    });

    uploadSection.addEventListener('dragleave', () => {
        uploadSection.classList.remove('dragging');
    });

    uploadSection.addEventListener('drop', (e) => {
        e.preventDefault();
        uploadSection.classList.remove('dragging');

        const files = e.dataTransfer.files;
        if (files.length > 0) {
            handlePhotoUpload(files[0]);
        }
    });
}

// 文件选择
function setupFileInput() {
    document.getElementById('photoInput').addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handlePhotoUpload(e.target.files[0]);
        }
    });
}

// 处理照片上传
async function handlePhotoUpload(file) {
    if (!file.type.startsWith('image/')) {
        alert('请上传图片文件！');
        return;
    }

    // 读取图片
    const reader = new FileReader();
    reader.onload = async (e) => {
        const base64Data = e.target.result;
        state.uploadedPhotoBase64 = base64Data;

        const img = new Image();
        img.onload = async () => {
            state.uploadedPhoto = img;

            // 显示原图
            document.getElementById('originalPhoto').src = base64Data;

            // 自动转换为像素风格预览
            await convertToPixelArt(img);

            // 显示预览区域
            document.getElementById('previewSection').style.display = 'block';
        };
        img.src = base64Data;
    };
    reader.readAsDataURL(file);
}

// 显示像素风预览（展示 nano banana 模版，让用户知道最终效果的风格）
async function convertToPixelArt(img) {
    const canvas = document.getElementById('pixelPreview');
    const ctx = canvas.getContext('2d');

    // 清空画布
    ctx.clearRect(0, 0, 128, 128);

    // 直接加载 nano banana 正面模版作为预览
    // 让用户知道最终生成的精灵会是这个风格
    const templateImg = new Image();
    templateImg.src = 'templates/front.png';

    await new Promise((resolve) => {
        templateImg.onload = () => {
            // 绘制 nano banana 模版
            ctx.drawImage(templateImg, 0, 0, 128, 128);

            // 保存预览
            state.pixelizedPhoto = canvas.toDataURL('image/png');
            resolve();
        };
        templateImg.onerror = () => {
            console.error('Failed to load template');
            resolve();
        };
    });
}

// 提取照片的主要颜色
async function extractMainColors(img) {
    const tempCanvas = document.createElement('canvas');
    const size = 100; // 缩小以加快处理
    tempCanvas.width = size;
    tempCanvas.height = size;
    const ctx = tempCanvas.getContext('2d');

    // 裁剪并缩放
    const imgSize = Math.min(img.width, img.height);
    const offsetX = (img.width - imgSize) / 2;
    const offsetY = (img.height - imgSize) / 2;

    ctx.drawImage(
        img,
        offsetX, offsetY, imgSize, imgSize,
        0, 0, size, size
    );

    const imageData = ctx.getImageData(0, 0, size, size);
    const data = imageData.data;

    // 收集所有非背景颜色
    const colors = [];
    for (let i = 0; i < data.length; i += 4) {
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];
        const a = data[i + 3];

        // 忽略接近白色/黑色的背景
        const brightness = (r + g + b) / 3;
        if (a > 128 && brightness > 20 && brightness < 235) {
            colors.push({ r, g, b });
        }
    }

    // 计算平均颜色（主要毛色）
    if (colors.length === 0) {
        return { main: '#888888', dark: '#555555', light: '#aaaaaa' };
    }

    const avgR = Math.round(colors.reduce((sum, c) => sum + c.r, 0) / colors.length);
    const avgG = Math.round(colors.reduce((sum, c) => sum + c.g, 0) / colors.length);
    const avgB = Math.round(colors.reduce((sum, c) => sum + c.b, 0) / colors.length);

    const mainColor = rgbToHex(avgR, avgG, avgB);
    const darkColor = rgbToHex(
        Math.max(0, avgR - 40),
        Math.max(0, avgG - 40),
        Math.max(0, avgB - 40)
    );
    const lightColor = rgbToHex(
        Math.min(255, avgR + 40),
        Math.min(255, avgG + 40),
        Math.min(255, avgB + 40)
    );

    return { main: mainColor, dark: darkColor, light: lightColor };
}

// RGB 转 Hex
function rgbToHex(r, g, b) {
    return '#' + [r, g, b].map(x => {
        const hex = x.toString(16);
        return hex.length === 1 ? '0' + hex : hex;
    }).join('');
}

// Hex 转 RGB
function hexToRgb(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
    } : null;
}

// 重新着色模版（保持 nano banana 形状，只换颜色）
function recolorTemplate(imageData, colors) {
    const data = imageData.data;
    const mainColor = hexToRgb(colors.main);
    const darkColor = hexToRgb(colors.dark);
    const lightColor = hexToRgb(colors.light);

    for (let i = 0; i < data.length; i += 4) {
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];
        const a = data[i + 3];

        // 跳过透明像素
        if (a < 128) continue;

        // 计算当前像素的亮度
        const brightness = (r + g + b) / 3;

        // 根据亮度映射到新颜色
        let newColor;
        if (brightness < 85) {
            newColor = darkColor; // 暗色部分
        } else if (brightness < 170) {
            newColor = mainColor; // 主色
        } else {
            newColor = lightColor; // 亮色部分
        }

        data[i] = newColor.r;
        data[i + 1] = newColor.g;
        data[i + 2] = newColor.b;
    }
}

// 生成精灵动画（使用 Gemini 图片生成）
async function generateSprites() {
    if (!state.apiKey) {
        alert('请先配置 Gemini API Key！');
        return;
    }

    if (!state.uploadedPhotoBase64) {
        alert('请先上传照片！');
        return;
    }

    const generateBtn = document.getElementById('generateBtn');
    const statusBox = document.getElementById('statusBox');
    const statusText = document.getElementById('statusText');
    const progressBar = document.getElementById('progressBar'); // Assuming you have a progress bar element
    const progressFill = document.getElementById('progressFill'); // Assuming you have a progress fill element

    let failedFrames = 0;

    try {
        generateBtn.disabled = true;
        statusBox.style.display = 'block';
        progressBar.style.display = 'block'; // Show progress bar
        statusText.innerHTML = '<div class="spinner"></div>正在加载动画清单与风格参考...';

        // 1. 加载风格参考图
        if (!state.styleReferenceBase64) {
            try {
                // 使用用户指定的 frame_03.png 作为风格锚点
                const styleRefResponse = await fetch('../../idle 3/grooming 1-12/frame_03.png');
                if (styleRefResponse.ok) {
                    const blob = await styleRefResponse.blob();
                    state.styleReferenceBase64 = await new Promise(resolve => {
                        const reader = new FileReader();
                        reader.onloadend = () => resolve(reader.result);
                        reader.readAsDataURL(blob);
                    });
                    console.log('✅ 风格参考图加载成功');
                }
            } catch (e) {
                console.warn('⚠️ 风格参考图加载失败，将仅依赖模版帧', e);
            }
        }

        // 重置并显示结果画廊
        const resultsGallery = document.getElementById('resultsGallery');
        const resultsGrid = document.getElementById('resultsGrid');
        if (resultsGallery) resultsGallery.style.display = 'block';
        if (resultsGrid) resultsGrid.innerHTML = '';

        // 加载动作清单
        const manifest = await fetch('sprite-manifest.json').then(r => r.json());
        const animations = manifest.animations;
        const animationList = Object.entries(animations);

        let totalFrames = 0;
        for (const [_, info] of animationList) {
            totalFrames += info.frames;
        }

        let completedFrames = 0;
        const generatedSprites = {};
        let firstFrameBase64 = null; // 记录第一帧作为风格锚点

        // 遍历所有动画帧，使用 Gemini 生成
        for (const [animPath, animInfo] of animationList) {
            const frameCount = animInfo.frames;

            for (let i = 1; i <= frameCount; i++) {
                const frameName = `frame_${String(i).padStart(2, '0')}.png`;
                const fullPath = `${animPath}/${frameName}`;

                // 更新进度
                // Removed the old statusText update here, replaced by updateProgress call later

                try {
                    // 加载官方 nano banana 帧（作为参考）
                    const nanoFrameBase64 = await loadOfficialFrameAsBase64(fullPath);

                    // 调用 Gemini API 生成
                    const generatedFrame = await generateFrameWithGemini(
                        state.apiKey,
                        state.uploadedPhotoBase64,
                        nanoFrameBase64,
                        animInfo.description,
                        state.styleReferenceBase64, // 传入全局风格参考
                        firstFrameBase64 // 传入同一个 session 的色彩锚点
                    );

                    generatedSprites[fullPath] = generatedFrame;

                    // 如果是生成的第 1 帧，将其存为锚点，供后续帧参考
                    if (!firstFrameBase64) {
                        firstFrameBase64 = generatedFrame;
                        console.log('✨ 已锁定第一帧作为风格参考锚点');
                    }

                    completedFrames++;

                    // 实时添加到画廊
                    addResultToGallery(generatedFrame, fullPath);

                } catch (error) {
                    console.error(`生成 ${fullPath} 失败:`, error);
                    // 标记失败，但不中断，也不进行静默回退（让用户知道出错了）
                    failedFrames++;
                    completedFrames++;
                }

                // 更新进度条
                updateProgress(completedFrames, totalFrames, failedFrames);

                // 添加延迟避免 API 限流
                await sleep(500);
            }
        }

        state.generatedSprites = generatedSprites;

        // 生成成功
        statusBox.className = 'status-box success';
        statusText.innerHTML = `
            ✅ 生成成功！<br>
            共生成 ${Object.keys(generatedSprites).length} 帧动画<br>
            <small>已将 nano banana 替换成你的猫咪</small>
        `;

        // 显示下载按钮
        document.getElementById('downloadSection').style.display = 'block';

    } catch (error) {
        console.error('生成失败:', error);
        statusBox.className = 'status-box error';
        statusText.innerHTML = `
            ❌ 生成失败: ${error.message}<br>
            <button class="btn btn-secondary" onclick="resetStatus()" style="margin-top: 10px;">重试</button>
        `;
    } finally {
        generateBtn.disabled = false;
    }
}

// 使用 Gemini 生成单帧
async function generateFrameWithGemini(apiKey, userPhotoBase64, templateFrameBase64, animationName, styleRefBase64 = null, colorAnchorBase64 = null) {
    // 使用用户选择的模型
    const model = state.selectedModel || 'gemini-3-pro-image-preview';
    const GEMINI_API_ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

    const prompt = `Input 1: Pixel art template.
Input 2: Reference photo.
Task: Reskin Input 1 with the colors and patterns from Input 2. 
Keep it clean: Solid colors, 1px black outlines, eyes are just simple black lines.
128x128 PNG, transparent background. No text.`;

    const parts = [
        { text: prompt },
        {
            inline_data: {
                mime_type: "image/png",
                data: cleanBase64(templateFrameBase64)
            }
        },
        {
            inline_data: {
                mime_type: "image/jpeg",
                data: cleanBase64(userPhotoBase64)
            }
        }
    ];

    if (styleRefBase64) {
        parts.push({
            inline_data: {
                mime_type: "image/png",
                data: cleanBase64(styleRefBase64)
            }
        });
    }

    if (colorAnchorBase64) {
        parts.push({
            inline_data: {
                mime_type: "image/png",
                data: cleanBase64(colorAnchorBase64)
            }
        });
    }

    const requestBody = {
        contents: [{ parts: parts }],
        generationConfig: {
            temperature: 0.4,
            topK: 32,
            topP: 0.95,
            responseModalities: ["image"]
        },
        safetySettings: [
            { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" }
        ]
    };

    const response = await fetch(`${GEMINI_API_ENDPOINT}?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody)
    });

    if (!response.ok) {
        const errorData = await response.json();
        console.error('Gemini API Error:', errorData);
        throw new Error(`Gemini API 错误: ${errorData.error?.message || response.statusText}`);
    }

    const data = await response.json();
    console.log('Gemini Full Response:', data);

    // 检查是否有错误信息
    if (data.error) {
        throw new Error(`Gemini API 错误: ${data.error.message}`);
    }

    // 检查是否有候选结果
    if (!data.candidates || data.candidates.length === 0) {
        throw new Error('API 未返回有效结果 (Candidate list empty)');
    }

    const candidate = data.candidates[0];

    // 检查内容是否存在（可能被安全策略拦截）
    if (!candidate.content || !candidate.content.parts) {
        const reason = candidate.finishReason || '未知';
        throw new Error(`API 未返回内容。原因: ${reason}。可能是安全过滤或模型限制。`);
    }

    const responseParts = candidate.content.parts;
    // 使用 JSON.stringify 记录完整结构，以便在 Console 中直接看到字段名
    console.log('Candidate Parts (Detailed):', JSON.stringify(responseParts, null, 2));

    let textResponse = '';
    let hasFunctionCall = false;

    // 尝试寻找图片数据
    for (const part of responseParts) {
        // 记录每一个 Part 的所有字段名，排查是否是字段名大小写或拼写问题
        console.log('Part keys:', Object.keys(part));

        if (part.inline_data) {
            console.log('✅ 成功获取图像数据, mime type:', part.inline_data.mime_type);
            return `data:${part.inline_data.mime_type};base64,${part.inline_data.data}`;
        }
        // 兼容某些模型使用的 camelCase 字段名
        if (part.inlineData) {
            const mType = part.inlineData.mimeType || part.inlineData.mime_type;
            const b64 = part.inlineData.data;
            console.log('✅ 成功获取图像数据 (inlineData), mime type:', mType);
            return `data:${mType};base64,${b64}`;
        }
        if (part.text) {
            textResponse += part.text;
        }
        if (part.functionCall || part.function_call) {
            hasFunctionCall = true;
            console.warn('⚠️ 模型尝试调用函数:', part.functionCall || part.function_call);
        }
    }

    // 处理无图情况
    if (hasFunctionCall) {
        throw new Error('AI 尝试调用函数而不是生成图片。说明当前模型（如 2.0 Flash）不支持直接图片生成，请使用 Nano Banana Pro (Gemini 3 Pro)。');
    }

    if (textResponse) {
        console.warn('⚠️ 模型仅返回了文本:', textResponse);

        // 尝试从文本中寻找 Base64 数据
        const base64Match = textResponse.match(/data:image\/[a-zA-Z]+;base64,([a-zA-Z0-9+/=]+)/);
        if (base64Match) {
            return base64Match[0];
        }

        throw new Error(`AI 返回了文本而不是图片。请确保使用的是支持图片生成的模型。内容摘要: "${textResponse.substring(0, 100)}..."`);
    }

    throw new Error('API 响应不完整。这通常意味着选中的模型（如 2.0 Flash）无法生成图片。请务必选择 Nano Banana Pro (Gemini 3 Pro)。');
}

// 清理 base64
function cleanBase64(base64String) {
    if (base64String.includes(',')) {
        return base64String.split(',')[1];
    }
    return base64String;
}

// 加载官方动画帧为 base64
async function loadOfficialFrameAsBase64(path) {
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';

        img.onload = () => {
            const canvas = document.createElement('canvas');
            canvas.width = img.width;
            canvas.height = img.height;
            const ctx = canvas.getContext('2d');
            ctx.drawImage(img, 0, 0);
            const base64 = canvas.toDataURL('image/png');
            resolve(base64);
        };

        img.onerror = () => {
            reject(new Error(`无法加载图片: ${path}`));
        };

        img.src = `Sources/DesktoppetSwift/Resources/${path}`;
    });
}

// 延迟函数
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// 下载 ZIP
async function downloadZip() {
    if (!state.generatedSprites) {
        alert('还没有生成的精灵图！');
        return;
    }

    try {
        const zip = new JSZip();

        // 添加所有生成的帧
        for (const [path, base64Data] of Object.entries(state.generatedSprites)) {
            const base64 = base64Data.split(',')[1];
            zip.file(path, base64, { base64: true });
        }

        // 生成 ZIP 文件
        const statusBox = document.getElementById('statusBox');
        const statusText = document.getElementById('statusText');
        statusBox.style.display = 'block';
        statusBox.className = 'status-box generating';
        statusText.innerHTML = '<div class="spinner"></div>正在打包 ZIP 文件...';

        const blob = await zip.generateAsync({
            type: 'blob',
            compression: 'DEFLATE',
            compressionOptions: { level: 6 }
        });

        // 下载
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `my-pet-sprite-${Date.now()}.zip`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        statusBox.className = 'status-box success';
        statusText.innerHTML = `
            ✅ 下载成功！<br>
            <small>解压后在桌宠设置中选择该文件夹即可使用</small>
        `;

    } catch (error) {
        console.error('生成 ZIP 失败:', error);
        alert(`生成 ZIP 失败: ${error.message}`);
    }
}

// 重置状态
function resetStatus() {
    const statusBox = document.getElementById('statusBox');
    if (statusBox) statusBox.style.display = 'none';

    const downloadSection = document.getElementById('downloadSection');
    if (downloadSection) downloadSection.style.display = 'none';
}

// 更新进度条
function updateProgress(current, total, failed = 0) {
    const progressFill = document.getElementById('progressFill');
    const statusText = document.getElementById('statusText');
    const progressBar = document.getElementById('progressBar');

    if (progressBar) progressBar.style.display = 'block';
    if (progressFill) {
        const percentage = Math.round((current / total) * 100);
        progressFill.style.width = `${percentage}%`;
    }

    if (statusText) {
        let msg = `正在生成: ${current}/${total} 帧 (${Math.round((current / total) * 100)}%)`;
        if (failed > 0) {
            msg += ` - <span style="color: #ff4d4d; font-weight: bold;">${failed} 帧生成失败</span>`;
        }
        statusText.innerHTML = msg;
    }
}

// 实时添加到画廊
function addResultToGallery(base64, path) {
    const grid = document.getElementById('resultsGrid');
    if (!grid) return;

    const item = document.createElement('div');
    item.className = 'result-item';

    // 提取文件名作为标题
    const fileName = path.split('/').pop();
    item.title = fileName;

    const img = document.createElement('img');
    img.src = base64;

    item.appendChild(img);
    grid.appendChild(item);

    // 自动滚动到底部
    grid.scrollTop = grid.scrollHeight;
}
