/**
 * Gemini API 集成模块
 * 用于将用户的宠物外观应用到所有动作帧
 */

const GEMINI_API_ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent';

/**
 * 生成单个精灵帧
 * @param {string} apiKey - Gemini API Key
 * @param {string} userTemplateBase64 - 用户绘制的模版图（base64）
 * @param {string} officialFrameBase64 - 官方动作帧图片（base64）
 * @param {string} viewAngle - 视角 (front/back/left/right)
 * @param {string} animationName - 动画名称
 * @returns {Promise<string>} 生成的图片 base64
 */
async function generateFrameWithGemini(apiKey, userTemplateBase64, officialFrameBase64, viewAngle, animationName) {
    // 构造 Prompt
    const prompt = buildPrompt(viewAngle, animationName);

    // 准备请求数据
    const requestBody = {
        contents: [{
            parts: [
                {
                    text: prompt
                },
                {
                    inline_data: {
                        mime_type: "image/png",
                        data: cleanBase64(userTemplateBase64)
                    }
                },
                {
                    inline_data: {
                        mime_type: "image/png",
                        data: cleanBase64(officialFrameBase64)
                    }
                }
            ]
        }],
        generationConfig: {
            temperature: 0.4,
            topK: 32,
            topP: 1,
            maxOutputTokens: 4096,
        }
    };

    try {
        const response = await fetch(`${GEMINI_API_ENDPOINT}?key=${apiKey}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(requestBody)
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(`Gemini API 错误: ${error.error?.message || response.statusText}`);
        }

        const data = await response.json();

        // 从响应中提取生成的图片
        // 注意：Gemini 2.0 Flash Exp 支持图片生成，但需要检查返回格式
        const generatedImage = extractGeneratedImage(data);

        return generatedImage;

    } catch (error) {
        console.error('Gemini API 调用失败:', error);
        throw error;
    }
}

/**
 * 构造生成 Prompt
 */
function buildPrompt(viewAngle, animationName) {
    const viewMap = {
        'front': '正面',
        'back': '背面',
        'left': '左侧面',
        'right': '右侧面'
    };

    return `你是一个专业的像素艺术生成器，擅长将真实照片转换为像素风桌宠动画。

任务：根据用户提供的宠物照片/像素图（第一张图），生成符合指定动作姿态（第二张图）的新精灵图。

核心要求：
1. **外观提取**：从第一张图中提取宠物的关键特征
   - 毛色、花纹、斑点分布
   - 眼睛颜色和形状
   - 耳朵形状
   - 整体体型特征

2. **动作姿态**：严格遵循第二张图（官方模版）的动作、姿势、比例
   - 保持动作的流畅性
   - 保持像素艺术的可爱风格
   - 确保与其他帧无缝衔接

3. **视角转换**：当前视角为 ${viewMap[viewAngle] || viewAngle}
   - 如果第一张图是正面，需要智能推断其他视角的外观
   - 背面：主要是背部毛色和尾巴
   - 左侧/右侧：侧面轮廓，保持花纹对称性

4. **动画名称**：${animationName}

5. **像素艺术规范**：
   - 128x128 像素 PNG 格式
   - 背景完全透明
   - 边缘清晰，颜色量化
   - 保持桌宠像素风格的简洁可爱感

特别注意：
- 第一张图可能是真实照片转换的像素图，需要保留其核心特征
- 如果视角不匹配（如第一张是正面，但需要生成背面），请合理推断
- 保持整体风格一致性，确保所有帧的宠物看起来是同一只

请生成符合要求的精灵图。`;
}

/**
 * 清理 base64 数据（移除 data:image/png;base64, 前缀）
 */
function cleanBase64(base64String) {
    if (base64String.includes(',')) {
        return base64String.split(',')[1];
    }
    return base64String;
}

/**
 * 从 Gemini 响应中提取生成的图片
 */
function extractGeneratedImage(apiResponse) {
    // Gemini 的响应格式可能是：
    // 1. 文本中包含图片描述
    // 2. 直接返回图片数据
    // 3. 返回图片 URL

    // 注意：Gemini 2.0 Flash Exp 目前主要是文本+视觉理解
    // 图片生成需要使用 Imagen 或其他专门模型
    // 这里先用文本引导 + 回退策略

    try {
        const candidates = apiResponse.candidates;
        if (!candidates || candidates.length === 0) {
            throw new Error('API 未返回有效结果');
        }

        const content = candidates[0].content;
        const parts = content.parts;

        // 尝试查找图片数据
        for (const part of parts) {
            if (part.inline_data) {
                return `data:${part.inline_data.mime_type};base64,${part.inline_data.data}`;
            }
            if (part.file_data) {
                // 如果是文件引用，需要额外下载
                return downloadFileFromGemini(part.file_data.file_uri);
            }
        }

        // 如果没有图片，抛出错误
        throw new Error('API 响应中未包含图片数据。提示：Gemini 2.0 Flash Exp 可能需要配合 Imagen 使用。');

    } catch (error) {
        console.error('解析 Gemini 响应失败:', error);
        throw error;
    }
}

/**
 * 批量生成所有动作帧
 * @param {string} apiKey
 * @param {Object} userTemplates - { front, back, left, right } base64 图片
 * @param {Object} manifest - 动作清单
 * @param {Function} progressCallback - 进度回调 (current, total, message)
 * @returns {Promise<Object>} { animationPath: base64Image }
 */
async function generateAllSprites(apiKey, userTemplates, manifest, progressCallback) {
    const result = {};
    const animations = manifest.animations;
    const animationList = Object.entries(animations);
    const totalAnimations = animationList.length;

    let completedFrames = 0;
    let totalFrames = 0;

    // 计算总帧数
    for (const [_, info] of animationList) {
        totalFrames += info.frames;
    }

    for (const [animPath, animInfo] of animationList) {
        const primaryView = animInfo.primaryView;
        const frameCount = animInfo.frames;
        const userTemplate = userTemplates[primaryView];

        if (!userTemplate) {
            console.warn(`缺少 ${primaryView} 视角的模版，跳过 ${animPath}`);
            continue;
        }

        // 为每个动作生成所有帧
        for (let i = 1; i <= frameCount; i++) {
            const frameName = `frame_${String(i).padStart(2, '0')}.png`;
            const fullPath = `${animPath}/${frameName}`;

            if (progressCallback) {
                progressCallback(
                    completedFrames,
                    totalFrames,
                    `生成中: ${animInfo.description} - 帧 ${i}/${frameCount}`
                );
            }

            try {
                // 加载官方动作帧
                const officialFrameBase64 = await loadOfficialFrame(fullPath);

                // 调用 Gemini 生成
                const generatedFrame = await generateFrameWithGemini(
                    apiKey,
                    userTemplate,
                    officialFrameBase64,
                    primaryView,
                    animInfo.description
                );

                result[fullPath] = generatedFrame;
                completedFrames++;

            } catch (error) {
                console.error(`生成 ${fullPath} 失败:`, error);
                // 失败时使用用户模版作为回退
                result[fullPath] = userTemplate;
                completedFrames++;
            }

            // 添加延迟避免 API 限流
            await sleep(200);
        }
    }

    return result;
}

/**
 * 加载官方动作帧图片
 */
async function loadOfficialFrame(path) {
    // 从 Sources/DesktoppetSwift/Resources/ 加载
    // 需要将图片转为 base64

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

        // 路径映射
        // path 格式: "eating/frame_01.png"
        // 实际路径: "Sources/DesktoppetSwift/Resources/eating/frame_01.png"
        // 注意：sprite-editor 目录下有 Sources 的符号链接
        img.src = `Sources/DesktoppetSwift/Resources/${path}`;
    });
}

/**
 * 工具函数：延迟
 */
function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 测试 API Key 是否有效
 */
async function testApiKey(apiKey) {
    try {
        const response = await fetch(`${GEMINI_API_ENDPOINT}?key=${apiKey}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                contents: [{
                    parts: [{ text: "Hello" }]
                }]
            })
        });

        return response.ok;
    } catch (error) {
        return false;
    }
}

// 导出函数
window.GeminiAPI = {
    generateFrameWithGemini,
    generateAllSprites,
    testApiKey,
    loadOfficialFrame
};
