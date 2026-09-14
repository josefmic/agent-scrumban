#!/bin/zsh
exec claude --model haiku --strict-mcp-config --mcp-config '{"mcpServers":{}}' 'Reply with the single word: ok'
