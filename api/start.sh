#!/bin/sh
# Railway wrapper for the OpenDeepWiki backend.
#  - dotnet listens on loopback only; a small Caddy on $PORT is the only way in.
#  - on every boot, before Caddy opens the port, upstream's seeded admin password
#    (admin@routin.ai / Admin@123) is replaced with ADMIN_PASSWORD.
#  - Caddy blocks self-registration (unless ALLOW_REGISTRATION=true) and requires
#    MCP_TOKEN as a bearer token on /api/mcp.
#  - the container exits non-zero whenever dotnet or Caddy stops, so Railway restarts it
#    (upstream logs startup errors and exits 0).
set -eu
log() { echo "[odw-start] $*"; }

PORT="${PORT:-8080}"
APP_PORT=5080
APP_UID=1654
ADMIN_EMAIL="admin@routin.ai"   # fixed by upstream: it re-seeds this account whenever it is missing

need() { # name min_len
  eval "v=\${$1:-}"
  if [ "${#v}" -lt "$2" ]; then log "$1 must be set ($2+ characters)."; exit 1; fi
}
need ADMIN_PASSWORD 8
need JWT_SECRET_KEY 32
need MCP_TOKEN 16
need ConnectionStrings__Default 10
case "$MCP_TOKEN" in *[!A-Za-z0-9_-]*) log "MCP_TOKEN may only contain letters, digits, '-' and '_'."; exit 1;; esac

# LLM settings: the template's short names -> upstream's names (upstream names win if set).
export CHAT_API_KEY="${CHAT_API_KEY:-${LLM_API_KEY:-}}"
export ENDPOINT="${ENDPOINT:-${LLM_BASE_URL:-https://api.openai.com/v1}}"
export CHAT_REQUEST_TYPE="${CHAT_REQUEST_TYPE:-${LLM_PROVIDER_TYPE:-OpenAI}}"
export WIKI_CATALOG_MODEL="${WIKI_CATALOG_MODEL:-${LLM_MODEL:-gpt-4o-mini}}"
export WIKI_CONTENT_MODEL="${WIKI_CONTENT_MODEL:-${LLM_MODEL:-gpt-4o-mini}}"
# Upstream's appsettings.json ships AI:Endpoint=https://api.routin.ai/v1, and the first-boot
# provider setup reads AI:* before ENDPOINT/CHAT_*, so set AI:* explicitly.
export AI__Endpoint="$ENDPOINT"
export AI__ApiKey="$CHAT_API_KEY"
export AI__RequestType="$CHAT_REQUEST_TYPE"
[ -n "$CHAT_API_KEY" ] || log "WARNING: LLM_API_KEY is empty; add an AI provider under Admin before importing a repository."

# Small-plan defaults (override any of them with a variable of the same name).
export WIKI_LANGUAGES="${WIKI_LANGUAGES:-en}"
export WIKI_PARALLEL_COUNT="${WIKI_PARALLEL_COUNT:-2}"
export WikiGenerator__ParallelCount="$WIKI_PARALLEL_COUNT"
export WIKI_MAX_CONCURRENT_GENERATIONS="${WIKI_MAX_CONCURRENT_GENERATIONS:-1}"

# Persistent data on the Railway volume at /data.
mkdir -p /data/repos /data/skills /data/home /app/logs
cp -rn /app/skills/. /data/skills/ 2>/dev/null || true
chown "$APP_UID:$APP_UID" /data /data/repos /data/skills /data/home
find /data/skills ! -user "$APP_UID" -exec chown "$APP_UID:$APP_UID" {} + 2>/dev/null || true
chown -R "$APP_UID:$APP_UID" /app/logs
export HOME=/data/home
# Keep git's memory small on 0.5 GB plans (git index-pack can be OOM-killed otherwise).
cat > "$HOME/.gitconfig" <<'GIT'
[pack]
	threads = 1
	windowMemory = 32m
	deltaCacheSize = 16m
[core]
	packedGitLimit = 64m
	packedGitWindowSize = 16m
	bigFileThreshold = 16m
GIT
chown "$APP_UID:$APP_UID" "$HOME/.gitconfig"

APP_PID=""; CADDY_PID=""
stop_all() {
  [ -n "$CADDY_PID" ] && kill -TERM "$CADDY_PID" 2>/dev/null || true
  [ -n "$APP_PID" ] && kill -TERM "$APP_PID" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap 'stop_all; exit 143' TERM INT

log "starting OpenDeepWiki backend on 127.0.0.1:${APP_PORT}"
ASPNETCORE_URLS="http://127.0.0.1:${APP_PORT}" ASPNETCORE_HTTP_PORTS="" \
  setpriv --reuid="$APP_UID" --regid="$APP_UID" --clear-groups dotnet /app/OpenDeepWiki.dll &
APP_PID=$!

i=0
until curl -fsS -m 3 "http://127.0.0.1:${APP_PORT}/health" >/dev/null 2>&1; do
  if ! kill -0 "$APP_PID" 2>/dev/null; then log "backend stopped during startup"; exit 1; fi
  i=$((i + 1))
  if [ "$i" -ge 600 ]; then log "backend not healthy after 600 s"; stop_all; exit 1; fi
  sleep 1
done
log "backend healthy after ${i}s"

# Replace upstream's default admin password if it still works.
base="http://127.0.0.1:${APP_PORT}"
body=$(python3 -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"password":"Admin@123"}))' "$ADMIN_EMAIL")
resp=$(curl -sS -m 30 -H 'Content-Type: application/json' -d "$body" "$base/api/auth/login" 2>/dev/null || true)
tok=$(printf '%s' "$resp" | python3 -c 'import json,sys; d=json.load(sys.stdin)["data"]; print(d["accessToken"]+" "+d["user"]["id"])' 2>/dev/null || true)
if [ -n "$tok" ]; then
  uid="${tok#* }"; tok="${tok%% *}"
  newpw=$(python3 -c 'import json,os; print(json.dumps({"newPassword":os.environ["ADMIN_PASSWORD"]}))')
  code=$(curl -sS -m 30 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $tok" \
    -H 'Content-Type: application/json' -d "$newpw" "$base/api/admin/users/$uid/reset-password" || echo 000)
  if [ "$code" != "200" ]; then log "could not replace the default admin password (HTTP $code)"; stop_all; exit 1; fi
  log "default admin password replaced with ADMIN_PASSWORD"
else
  log "admin account is not on upstream's default password"
fi

# Turn on the AI provider the wiki tasks are bound to (non-fatal; see activate-providers.py).
ADMIN_EMAIL="$ADMIN_EMAIL" python3 /usr/local/lib/odw/activate-providers.py "$base" || log "provider check failed (non-fatal)"

# Front proxy.
REGISTER_RULE='handle /api/auth/register {
		respond "Self-registration is disabled. Ask an admin to create your account." 403
	}'
[ "${ALLOW_REGISTRATION:-false}" = "true" ] && REGISTER_RULE='# self-registration allowed (ALLOW_REGISTRATION=true)'
cat > /tmp/Caddyfile <<CADDY
{
	admin off
	auto_https off
	persist_config off
	servers {
		trusted_proxies static private_ranges
	}
}
:${PORT} {
	handle /health {
		reverse_proxy 127.0.0.1:${APP_PORT}
	}
	handle /api/health {
		rewrite * /health
		reverse_proxy 127.0.0.1:${APP_PORT}
	}
	${REGISTER_RULE}
	@mcp path /api/mcp /api/mcp/*
	handle @mcp {
		@noauth not header Authorization "Bearer ${MCP_TOKEN}"
		respond @noauth "MCP needs Authorization: Bearer MCP_TOKEN" 401
		reverse_proxy 127.0.0.1:${APP_PORT} {
			flush_interval -1
		}
	}
	handle {
		reverse_proxy 127.0.0.1:${APP_PORT} {
			flush_interval -1
		}
	}
}
CADDY
log "starting front proxy on port ${PORT}"
caddy run --config /tmp/Caddyfile --adapter caddyfile &
CADDY_PID=$!

# Exit (non-zero) as soon as either process stops.
while kill -0 "$APP_PID" 2>/dev/null && kill -0 "$CADDY_PID" 2>/dev/null; do sleep 2; done
if ! kill -0 "$APP_PID" 2>/dev/null; then log "backend stopped"; else log "front proxy stopped"; fi
stop_all
exit 1
