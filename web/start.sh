#!/bin/sh
# Railway wrapper for the OpenDeepWiki web UI: binds all interfaces, sizes the Node heap
# for small plans, and exits non-zero whenever the server stops so Railway restarts it.
set -u
if [ -z "${API_PROXY_URL:-}" ]; then echo "[odw-web] API_PROXY_URL is empty"; exit 1; fi
export HOSTNAME=0.0.0.0
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=256}"
cd /app
node server.js
rc=$?
echo "[odw-web] server exited with code $rc"
[ "$rc" -eq 0 ] && rc=1
exit "$rc"
