#!/bin/bash

# 桌宠精灵编辑器启动脚本

echo "🐱 启动桌宠精灵编辑器..."

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 检查端口是否已被占用
if lsof -i :8888 > /dev/null 2>&1; then
    echo "⚠️  端口 8888 已被占用，尝试使用端口 8889..."
    PORT=8889
else
    PORT=8888
fi

# 启动服务器
echo "🚀 启动 HTTP 服务器在端口 $PORT..."
python3 -m http.server $PORT &
SERVER_PID=$!

# 等待服务器启动
sleep 2

# 打开浏览器
echo "🌐 在浏览器中打开编辑器..."
if command -v open > /dev/null; then
    # macOS - 打开照片上传页面
    open "http://localhost:$PORT/photo-to-sprite.html"
elif command -v xdg-open > /dev/null; then
    # Linux
    xdg-open "http://localhost:$PORT/photo-to-sprite.html"
else
    echo "请手动打开浏览器访问: http://localhost:$PORT/photo-to-sprite.html"
fi

echo ""
echo "✅ 编辑器已启动！"
echo "   访问地址: http://localhost:$PORT"
echo ""
echo "   按 Ctrl+C 停止服务器"
echo ""

# 等待用户中断
wait $SERVER_PID
