#!/usr/bin/env python3
"""
Meow Gateway - 将消息发送给桌面小猫

Usage:
    python send_to_meow.py "要发送的内容"
    python send_to_meow.py "内容" --title "标题" --context "上下文"
    
    # 发送完整对话（JSON格式）
    python send_to_meow.py --messages '[{"role":"user","content":"hello"},{"role":"assistant","content":"hi"}]'
"""

import argparse
import json
import sys
import urllib.request
import urllib.error

MEOW_URL = "http://127.0.0.1:1012/meow"

def send_to_meow(content=None, title=None, context=None, messages=None, source="claude"):
    """发送消息到小猫 HTTP 网关"""
    
    payload = {
        "source": source
    }
    
    if content:
        payload["content"] = content
    if title:
        payload["title"] = title
    if context:
        payload["context"] = context
    if messages:
        payload["messages"] = messages
    
    try:
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            MEOW_URL,
            data=data,
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        
        with urllib.request.urlopen(req, timeout=5) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result
            
    except urllib.error.URLError as e:
        return {
            "success": False,
            "message": f"无法连接到小猫：{e.reason}。请确保 DesktoppetSwift 正在运行。"
        }
    except Exception as e:
        return {
            "success": False,
            "message": f"发送失败：{str(e)}"
        }

def check_connection():
    """检查小猫是否在运行"""
    try:
        req = urllib.request.Request(MEOW_URL, method='GET')
        with urllib.request.urlopen(req, timeout=2) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result.get("success", False)
    except:
        return False

def main():
    parser = argparse.ArgumentParser(description='发送消息给桌面小猫')
    parser.add_argument('content', nargs='?', help='要发送的内容')
    parser.add_argument('--title', '-t', help='标题')
    parser.add_argument('--context', '-c', help='额外上下文')
    parser.add_argument('--messages', '-m', help='完整对话（JSON数组格式）')
    parser.add_argument('--source', '-s', default='claude', help='来源标识')
    parser.add_argument('--check', action='store_true', help='只检查连接状态')
    
    args = parser.parse_args()
    
    if args.check:
        if check_connection():
            print("✅ 小猫 HTTP 网关运行中")
            sys.exit(0)
        else:
            print("❌ 无法连接到小猫，请确保 DesktoppetSwift 正在运行")
            sys.exit(1)
    
    if not args.content and not args.messages:
        parser.print_help()
        sys.exit(1)
    
    messages = None
    if args.messages:
        try:
            messages = json.loads(args.messages)
        except json.JSONDecodeError:
            print("❌ messages 参数必须是有效的 JSON 数组")
            sys.exit(1)
    
    result = send_to_meow(
        content=args.content,
        title=args.title,
        context=args.context,
        messages=messages,
        source=args.source
    )
    
    if result.get("success"):
        print(f"✅ {result.get('message', '发送成功')}")
    else:
        print(f"❌ {result.get('message', '发送失败')}")
        sys.exit(1)

if __name__ == "__main__":
    main()
