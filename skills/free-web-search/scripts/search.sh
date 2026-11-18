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
case $n in [1-9]|10) ;; *) echo "error: num_results must be an integer 1-10" >&2; exit 2;; esac
command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 1; }

# Probe python3 once: a stub python3 can exist but fail (fresh macOS).
have_py=0
if command -v python3 >/dev/null 2>&1 && python3 -c 'import json' >/dev/null 2>&1; then have_py=1; fi
have_jq=0
command -v jq >/dev/null 2>&1 && have_jq=1

# JSON-escape the query: python3, then jq, then plain shell. Fall through on empty output.
esc=""
if [ "$have_py" = 1 ]; then
  esc=$(printf '%s' "$query" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)
fi
if [ -z "$esc" ] && [ "$have_jq" = 1 ]; then
  esc=$(printf '%s' "$query" | jq -Rs . 2>/dev/null)
fi
if [ -z "$esc" ]; then
  body=$(printf '%s' "$query" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g' | tr '\n' ' ' | tr -d '\000-\037')
  [ -n "$body" ] && esc="\"$body\""
fi
if [ -z "$esc" ]; then
  echo "error: could not encode the query as JSON" >&2; exit 1
fi

req=$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"web_search","arguments":{"query":%s,"num_results":%s}}}' "$esc" "$n")

resp=$(curl -sS --max-time 60 -X POST "$URL" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2025-06-18' \
  --data "$req") || { echo "error: could not reach $URL" >&2; exit 1; }

# The server may answer with plain JSON or an SSE stream; take the last "data:" line.
json=$(printf '%s\n' "$resp" | sed -n 's/^data: *//p' | tail -n 1)
[ -n "$json" ] || json=$resp

bad() { echo "error: unexpected response from search server" >&2; exit 1; }

if [ "$have_py" = 1 ]; then
  printf '%s' "$json" | python3 -c '
import json, sys
def die(m):
    print("error: " + m, file=sys.stderr); sys.exit(1)
try:
    d = json.loads(sys.stdin.read())
except ValueError:
    die("unexpected response from search server")
if not isinstance(d, dict):
    die("unexpected response from search server")
def hint(t):
    return " (rate limited: wait a bit and retry)" if "rate limit" in t.lower() else ""
e = d.get("error")
if e:
    m = e.get("message", "request failed") if isinstance(e, dict) else str(e)
    die(str(m) + hint(str(m)))
r = d.get("result")
if not isinstance(r, dict):
    die("unexpected response from search server")
text = "\n".join(c.get("text", "") for c in r.get("content") or [] if isinstance(c, dict) and c.get("type") == "text")
if r.get("isError"):
    die((text or "search failed") + hint(text))
print(text)'
elif [ "$have_jq" = 1 ]; then
  printf '%s' "$json" | jq -e 'type == "object"' >/dev/null 2>&1 || bad
  failed=$(printf '%s' "$json" | jq -r 'if .error or (.result.isError == true) then "1" else "0" end')
  if [ "$failed" = 1 ]; then
    msg=$(printf '%s' "$json" | jq -r 'if .error then (.error | if type == "object" then (.message // "") else tostring end) else ([.result.content[]?.text] | join("\n")) end')
    [ -n "$msg" ] || msg="search failed"
    case $msg in *[Rr]ate\ [Ll]imit*) msg="$msg (rate limited: wait a bit and retry)";; esac
    echo "error: $msg" >&2; exit 1
  fi
  printf '%s' "$json" | jq -r '[.result.content[]? | select(.type == "text") | .text] | join("\n")'
else
  # No JSON parser: print the raw JSON (text is inside JSON strings).
  case $json in
    '{'*) ;;
    *) bad ;;
  esac
  case $json in *'"isError":true'*|*'"error":'*) echo "error: search failed: $json" >&2; exit 1;; esac
  printf '%s\n' "$json"
fi
