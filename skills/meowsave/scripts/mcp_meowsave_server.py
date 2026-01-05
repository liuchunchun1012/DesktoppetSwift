#!/usr/bin/env python3
"""
MeowSave MCP Server - 让 Claude Desktop/Code 可以发送对话给小猫

MCP (Model Context Protocol) 是 Anthropic 定义的标准协议，
允许 Claude 调用外部工具。

安装依赖:
    pip install mcp

配置 Claude Desktop:
    编辑 ~/Library/Application Support/Claude/claude_desktop_config.json:
    {
      "mcpServers": {
        "meowsave": {
          "command": "python3",
          "args": ["/path/to/mcp_meowsave_server.py"]
        }
      }
    }
"""

import json
import sys
import urllib.request
import urllib.error
from datetime import datetime

# MCP 协议版本
PROTOCOL_VERSION = "2025-06-18"
MEOW_URL = "http://127.0.0.1:1012/meow"

def send_to_meow(content: str = None, title: str = None, messages: list = None, source: str = "claude") -> dict:
    """发送消息到小猫 HTTP 网关"""
    payload = {"source": source}
    if content:
        payload["content"] = content
    if title:
        payload["title"] = title
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
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.URLError as e:
        return {"success": False, "message": f"无法连接到小猫：{e.reason}"}
    except Exception as e:
        return {"success": False, "message": f"发送失败：{str(e)}"}

def check_meow_status() -> dict:
    """检查小猫是否在运行"""
    try:
        req = urllib.request.Request(MEOW_URL, method='GET')
        with urllib.request.urlopen(req, timeout=2) as response:
            return json.loads(response.read().decode('utf-8'))
    except:
        return {"success": False, "message": "小猫未运行"}

# ===== MCP Protocol Handlers =====

def handle_initialize(params: dict) -> dict:
    """处理初始化请求"""
    return {
        "protocolVersion": PROTOCOL_VERSION,
        "capabilities": {
            "tools": {}
        },
        "serverInfo": {
            "name": "meowsave",
            "version": "1.0.0"
        }
    }

def handle_tools_list(params: dict) -> dict:
    """返回可用工具列表"""
    return {
        "tools": [
            {
                "name": "meowsave",
                "description": "将对话内容发送给桌面小猫，保存到 Obsidian。用于保存重要对话、笔记或想法。",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "content": {
                            "type": "string",
                            "description": "要保存的内容或对话摘要"
                        },
                        "title": {
                            "type": "string",
                            "description": "可选的标题"
                        },
                        "messages": {
                            "type": "array",
                            "description": "可选的完整对话消息列表，格式为 [{role, content}, ...]",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "role": {"type": "string"},
                                    "content": {"type": "string"}
                                }
                            }
                        }
                    }
                }
            },
            {
                "name": "meow_status",
                "description": "检查桌面小猫是否在运行",
                "inputSchema": {
                    "type": "object",
                    "properties": {}
                }
            }
        ]
    }

def handle_tools_call(params: dict) -> dict:
    """处理工具调用"""
    tool_name = params.get("name")
    arguments = params.get("arguments", {})
    
    if tool_name == "meowsave":
        result = send_to_meow(
            content=arguments.get("content"),
            title=arguments.get("title"),
            messages=arguments.get("messages"),
            source="claude"
        )
        return {
            "content": [
                {
                    "type": "text",
                    "text": f"{'✅' if result.get('success') else '❌'} {result.get('message', '未知结果')}"
                }
            ]
        }
    
    elif tool_name == "meow_status":
        result = check_meow_status()
        return {
            "content": [
                {
                    "type": "text",
                    "text": f"{'✅ 小猫在运行' if result.get('success') else '❌ 小猫未运行'}"
                }
            ]
        }
    
    return {
        "content": [{"type": "text", "text": f"未知工具: {tool_name}"}],
        "isError": True
    }

def process_message(message: dict) -> dict:
    """处理 MCP 消息"""
    method = message.get("method")
    params = message.get("params", {})
    msg_id = message.get("id")
    
    handlers = {
        "initialize": handle_initialize,
        "tools/list": handle_tools_list,
        "tools/call": handle_tools_call,
    }
    
    if method in handlers:
        result = handlers[method](params)
        return {"jsonrpc": "2.0", "id": msg_id, "result": result}
    elif method == "notifications/initialized":
        # 通知类消息不需要响应
        return None
    else:
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "error": {"code": -32601, "message": f"Method not found: {method}"}
        }

def main():
    """MCP Server 主循环 - 读取 stdin，写入 stdout"""
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            
            message = json.loads(line)
            response = process_message(message)
            
            if response:
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()
                
        except json.JSONDecodeError:
            continue
        except KeyboardInterrupt:
            break
        except Exception as e:
            error_response = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32603, "message": str(e)}
            }
            sys.stdout.write(json.dumps(error_response) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
