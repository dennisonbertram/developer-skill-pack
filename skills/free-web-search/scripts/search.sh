#!/bin/sh
# Free web search through the free-pi MCP endpoint. Needs only curl.
# Usage: search.sh "query" [num_results 1-10]
set -u
URL="https://api.freepi.ai/mcp/web"

query=${1:-}
n=${2:-5}
if [ -z "$query" ]; then
  echo "usage: search.sh \"query\" [num_results 1-10]" >&2
  exit 2
fi
case $n in ''|*[!0-9]*) echo "error: num_results must be an integer 1-10" >&2; exit 2;; esac
if [ "$n" -lt 1 ] || [ "$n" -gt 10 ]; then
  echo "error: num_results must be an integer 1-10" >&2; exit 2
fi
if [ "${#query}" -gt 500 ]; then
  echo "error: query must be at most 500 characters" >&2; exit 2
fi
command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 1; }

# JSON-escape the query: python3, then jq, then plain shell.
if command -v python3 >/dev/null 2>&1; then
  esc=$(printf '%s' "$query" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
elif command -v jq >/dev/null 2>&1; then
  esc=$(printf '%s' "$query" | jq -Rs .)
else
  body=$(printf '%s' "$query" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g' | tr '\n' ' ' | tr -d '\000-\037')
  esc="\"$body\""
fi

req=$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"web_search","arguments":{"query":%s,"num_results":%s}}}' "$esc" "$n")

resp=$(curl -sS --max-time 60 -X POST "$URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2025-06-18' \
  --data "$req") || { echo "error: could not reach $URL" >&2; exit 1; }

# The server may answer with plain JSON or an SSE stream ("data: {...}" lines).
json=$(printf '%s\n' "$resp" | sed -n 's/^data: *//p')
[ -n "$json" ] || json=$resp

if command -v python3 >/dev/null 2>&1; then
  printf '%s' "$json" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read())
except ValueError:
    print("error: unexpected response from search server", file=sys.stderr); sys.exit(1)
if "error" in d:
    print("error: " + str(d["error"].get("message", d["error"])), file=sys.stderr); sys.exit(1)
r = d.get("result", {})
text = "\n".join(c.get("text", "") for c in r.get("content", []) if c.get("type") == "text")
if r.get("isError"):
    print("error: " + (text or "search failed") + " (if rate limited, wait a bit and retry)", file=sys.stderr); sys.exit(1)
print(text)'
elif command -v jq >/dev/null 2>&1; then
  err=$(printf '%s' "$json" | jq -r '(.error.message // empty), (select(.result.isError == true) | [.result.content[]?.text] | join("\n"))' 2>/dev/null) || { echo "error: unexpected response from search server" >&2; exit 1; }
  [ -z "$err" ] || { echo "error: $err (if rate limited, wait a bit and retry)" >&2; exit 1; }
  printf '%s' "$json" | jq -r '[.result.content[]? | select(.type == "text") | .text] | join("\n")'
else
  # No JSON parser: print the raw response (text is inside JSON strings).
  case $json in *'"isError":true'*|*'"error":'*) echo "error: search failed: $json" >&2; exit 1;; esac
  printf '%s\n' "$json"
fi
