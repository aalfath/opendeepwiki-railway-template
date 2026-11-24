# Activate the AI providers the wiki tasks are bound to (upstream binds the default OpenAI URL
# to its built-in "openai" provider, which it seeds inactive, so jobs fail "provider not available").
import json, os, sys, urllib.request
base = sys.argv[1]
def call(method, path, body=None, tok=None):
    req = urllib.request.Request(base + path, method=method, data=None if body is None else json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "odw-start"})
    if tok: req.add_header("Authorization", "Bearer " + tok)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)
try:
    tok = call("POST", "/api/auth/login", {"email": os.environ["ADMIN_EMAIL"], "password": os.environ["ADMIN_PASSWORD"]})["data"]["accessToken"]
except Exception as e:
    print("[odw-start] provider check skipped: admin login with ADMIN_PASSWORD failed (%s)" % e); sys.exit(0)
keys = ("WIKI_CATALOG_PROVIDER_ID", "WIKI_CONTENT_PROVIDER_ID", "WIKI_TRANSLATION_PROVIDER_ID", "GRAPHIFY_PROVIDER_ID")
bound = {s["key"]: s.get("value") for s in call("GET", "/api/admin/settings?category=ai", tok=tok)["data"]}
ids = {bound[k] for k in keys if bound.get(k)}
fields = ("name", "displayName", "providerType", "baseUrl", "authType", "isBuiltIn", "supportsModelDiscovery", "modelsEndpoint",
          "defaultModelId", "systemProxyUrl", "oAuthConfigJson", "channelConfigJson", "accountsJson", "requestOverridesJson",
          "iconUrl", "description", "sortOrder")
for p in call("GET", "/api/admin/tools/ai-providers", tok=tok)["data"]:
    if p["id"] in ids and not p.get("isActive") and p.get("hasApiKey"):
        body = {f: p.get(f) for f in fields}
        body["baseUrl"] = body.get("baseUrl") or ""
        body["isActive"] = True
        call("PUT", "/api/admin/tools/ai-providers/" + p["id"], body, tok=tok)
        print("[odw-start] activated AI provider '%s' (%s) used by the wiki tasks" % (p["name"], p["baseUrl"]))
