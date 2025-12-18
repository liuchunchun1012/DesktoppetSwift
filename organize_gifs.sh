#!/bin/bash

# GIF 文件组织脚本
# 请先将你的 GIF 文件放到当前目录，然后运行此脚本

echo "🎬 开始组织 GIF 文件..."
echo ""

# 定义文件映射
# 主演示 GIF
if [ -f "待机舔毛.gif" ]; then
    cp "待机舔毛.gif" demo.gif
    echo "✅ 主演示 GIF: demo.gif (待机舔毛)"
else
    echo "⚠️  未找到: 待机舔毛.gif"
fi

# 创建 assets 目录（如果不存在）
mkdir -p assets

# 移动其他 GIF 到 assets
if [ -f "开心跳跃.gif" ]; then
    cp "开心跳跃.gif" assets/happy-jump.gif
    echo "✅ assets/happy-jump.gif (开心跳跃)"
fi

if [ -f "睡觉中.gif" ]; then
    cp "睡觉中.gif" assets/sleeping.gif
    echo "✅ assets/sleeping.gif (睡觉中)"
fi

if [ -f "向下走.gif" ]; then
    cp "向下走.gif" assets/walking.gif
    echo "✅ assets/walking.gif (向下走)"
fi

if [ -f "对话.gif" ]; then
    cp "对话.gif" assets/chat-demo.gif
    echo "✅ assets/chat-demo.gif (对话)"
fi

echo ""
echo "📂 文件组织完成！"
echo ""
echo "当前结构："
ls -lh demo.gif 2>/dev/null && echo ""
ls -lh assets/*.gif 2>/dev/null

echo ""
echo "🎯 下一步："
echo "1. git add demo.gif assets/*.gif"
echo "2. git commit -m \"Add demo GIFs\""
