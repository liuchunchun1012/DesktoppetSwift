---
name: meowsave
description: Save conversations and notes to Obsidian via the desktop cat (DesktoppetSwift). Use this skill when the user wants to (1) save the current conversation, (2) send content to Obsidian, (3) preserve important discussions or notes, or (4) explicitly mentions "meowsave", "send to cat", "save to obsidian", or similar phrases. Works with both direct script execution and MCP server integration.
---

# MeowSave - Save to Obsidian via Desktop Cat

Save Claude Code conversations and notes to your Obsidian Vault through the DesktoppetSwift desktop pet.

## Prerequisites

- **DesktoppetSwift** must be running (listens on http://127.0.0.1:1012)
- Desktop cat must have **Obsidian Vault path** configured

## Quick Usage

Check if the cat is available:

```bash
python3 scripts/send_to_meow.py --check
```

Save simple content:

```bash
python3 scripts/send_to_meow.py "Important note" --title "Meeting Notes"
```

Save full conversation:

```bash
python3 scripts/send_to_meow.py \
  --title "Feature Discussion" \
  --messages '[{"role":"user","content":"How do I..."},{"role":"assistant","content":"You can..."}]'
```

## Script Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `content` | Optional | Text content to save |
| `--title`, `-t` | Optional | Title for the saved note |
| `--messages`, `-m` | Optional | Full conversation as JSON array |
| `--context`, `-c` | Optional | Additional context information |
| `--source`, `-s` | Optional | Source identifier (default: "claude") |
| `--check` | Flag | Check if desktop cat is running |

## Output Location

Files are saved to your Obsidian Vault:

```
<Obsidian Vault>/ChatLogs/claude/YYYY-MM-DD_claude_HHMMSS.md
```

## Advanced: MCP Server Integration

For Claude Desktop integration, use the included MCP server.

### Setup

1. Install dependencies:
   ```bash
   pip install mcp
   ```

2. Configure Claude Desktop by editing:
   ```
   ~/Library/Application Support/Claude/claude_desktop_config.json
   ```

   Add this configuration:
   ```json
   {
     "mcpServers": {
       "meowsave": {
         "command": "python3",
         "args": ["/absolute/path/to/skills/meowsave/scripts/mcp_meowsave_server.py"]
       }
     }
   }
   ```

3. Restart Claude Desktop

### MCP Tools Available

Once configured, Claude Desktop can use:

- `meowsave` - Save content or conversations to Obsidian
- `meow_status` - Check if desktop cat is running

## When to Use This Skill

Use meowsave when:

- User wants to save the current conversation for later reference
- User mentions archiving or preserving important discussions
- User explicitly asks to "send to cat", "save to obsidian", or "meowsave"
- User wants to export conversation to their knowledge base
- Context should be preserved in Obsidian for future retrieval

## Troubleshooting

If connection fails:

1. Verify DesktoppetSwift is running
2. Check that the HTTP server is enabled (port 1012)
3. Ensure Obsidian Vault path is configured in the desktop cat settings
4. Run `python3 scripts/send_to_meow.py --check` to diagnose
