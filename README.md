[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/opendeepwiki?utm_medium=integration&utm_source=button&utm_campaign=opendeepwiki)

# Deploy and Host OpenDeepWiki on Railway

OpenDeepWiki is an open-source (MIT) AI knowledge base for code. Give it a Git repository and it clones the code, then has a language model write a structured wiki for it: an overview, a table of contents, one page per topic, Mermaid diagrams and a mind map. You can browse, search and chat with the result, and serve it to AI coding tools over MCP.

## About Hosting OpenDeepWiki

This template runs OpenDeepWiki 2.0.6 as three services: the Next.js web UI (public), the ASP.NET Core backend (private) and PostgreSQL. The backend keeps cloned repositories on a volume and everything else in Postgres, so data survives redeploys. You bring one LLM API key: OpenAI by default, or any OpenAI-compatible endpoint (OpenRouter, DeepSeek, Ollama…) through the base URL and model variables. The admin password, JWT secret and MCP token are generated for you. Wiki generation calls your model many times per repository, so start with a small repository and watch your provider's usage.

## Common Use Cases

* Publish an always-current, AI-written wiki of your own or open-source repositories for your team
* Onboard new developers with architecture overviews, diagrams and a chat that answers from the code
* Give Claude Code, Cursor or other MCP clients a searchable documentation source for a repository

## Dependencies for OpenDeepWiki Hosting

* An API key for an OpenAI-compatible LLM provider (the only value you must enter)
* PostgreSQL (included in this template)

### Deployment Dependencies

* OpenDeepWiki source and docs: https://github.com/AIDotNet/OpenDeepWiki
* Release 2.0.6: https://github.com/AIDotNet/OpenDeepWiki/releases/tag/v2.0.6
* Template source (Dockerfiles and start scripts): https://github.com/aalfath/opendeepwiki-railway-template
* OpenAI API keys: https://platform.openai.com/api-keys

### Implementation Details

**Services**

* **OpenDeepWiki** (public): the web UI on port 3000. It proxies `/api` to the backend over Railway's private network.
* **Backend** (private): the API, background workers (cloning, wiki generation, translation, mind maps) and the MCP server. A small Caddy front on port 8080 blocks self-registration and requires the MCP token. Cloned repositories live on the volume at `/data`.
* **Postgres**: all users, settings, wiki pages and chat history.

**After deploy**

1. Open the OpenDeepWiki service's URL and sign in with email `admin@routin.ai` (upstream's fixed admin account) and the password in the Backend service's `ADMIN_PASSWORD` variable. The template replaces upstream's well-known default password on every boot, so don't change that account's email.
2. Submit a repository (a public Git URL, or a private one with a token). The wiki for a small repository is ready in a few minutes.
3. Under Admin you can add more AI providers and models, create users, and set the wiki languages (English only by default; every extra language is translated by your model and costs tokens).

**MCP**: point a client at `https://YOUR-DOMAIN/api/mcp/OWNER/REPO` with the header `Authorization: Bearer MCP_TOKEN` (the value is in the Backend service's variables). For example, in Claude Code:

```
claude mcp add --transport http opendeepwiki https://YOUR-DOMAIN/api/mcp/OWNER/REPO --header "Authorization: Bearer MCP_TOKEN"
```

**Resources**: it runs on Railway's smallest plan (0.5 GB RAM per service): after a wiki run the backend used about 260 MB, the web UI about 90 MB and Postgres about 120 MB. Large repositories may need more RAM for cloning and generation; if the Backend restarts during a big import, raise its memory to 1 GB or more.

**Not included**: Graphify knowledge graphs run only when an admin starts them, and the Feishu, QQ, WeChat and Slack bots, GitHub App import and Google sign-in stay off until you configure them under Admin. Self-registration is blocked; set `ALLOW_REGISTRATION=true` on the Backend to open it.

**Updates**: the services build from the public template repository, which pins upstream's images by digest. When a new OpenDeepWiki release is tested, the repository is updated and Railway shows you an update notice; read `CHANGELOG.md` before applying it.

## Why Deploy OpenDeepWiki on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenDeepWiki on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->

## This repository

Railway template wrapper for [OpenDeepWiki](https://github.com/AIDotNet/OpenDeepWiki) 2.0.6 (MIT). Upstream publishes images only on its own Aliyun registry and re-pushes the `2.0.6` tag from `main`, so the Dockerfiles pin the digest:

| Folder | Railway service | Base image |
| --- | --- | --- |
| `api/` | Backend | `open-deepwiki/opendeepwiki:2.0.6@sha256:1a1eccbde82fbb249c1984d4311e8681797c371930870972f9d0c7b8441c15d4` (built 2026-10-23 from `7aa53b8`) plus Caddy `2.11.9@sha256:4851e54a…` |
| `web/` | OpenDeepWiki | `open-deepwiki/opendeepwiki-web:2.0.6@sha256:7c48551b8cd529a52aa917f1240338ffec63362829eb12a895a67188ca7fc8f2` |

Registry: `crpi-j9ha7sxwhatgtvj4.cn-shenzhen.personal.cr.aliyuncs.com`. If upstream ever deletes these digests, the build fails and this repository has to be bumped.

### Template variables

| Service | Variable | Default | Notes |
| --- | --- | --- | --- |
| Backend | `LLM_API_KEY` | (you enter it) | Your provider's API key. Required. |
| Backend | `LLM_BASE_URL` | `https://api.openai.com/v1` | Any OpenAI-compatible endpoint. |
| Backend | `LLM_MODEL` | `gpt-4o-mini` | Model for wiki and chat. |
| Backend | `LLM_PROVIDER_TYPE` | `OpenAI` | `OpenAI`, `OpenAIResponses`, `Anthropic` or `AzureOpenAI`. |
| Backend | `ADMIN_PASSWORD` | generated | Password of `admin@routin.ai`, re-applied on every boot. |
| Backend | `JWT_SECRET_KEY` | generated | Signs login tokens. |
| Backend | `MCP_TOKEN` | generated | Bearer token for `/api/mcp`. |
| Backend | `ConnectionStrings__Default` | Postgres reference | |
| OpenDeepWiki | `API_PROXY_URL` | Backend private URL | |
| OpenDeepWiki | `SITE_URL` | public domain | Used for sitemap and canonical links. |

The LLM variables only seed the first boot. After that, manage providers and models under Admin (the database wins).

Optional Backend variables: `ALLOW_REGISTRATION=true` (open self-registration), `WIKI_LANGUAGES` (default `en`; upstream's default is 12 languages), `WIKI_PARALLEL_COUNT` (default 2), plus any upstream setting from `compose.yaml`.

### What the wrapper changes

* Upstream seeds `admin@routin.ai` / `Admin@123` and recreates it if missing. `api/start.sh` starts the backend on loopback, replaces that password with `ADMIN_PASSWORD`, and only then opens the public port.
* Upstream's `appsettings.json` points the first AI provider at `api.routin.ai`; the wrapper sets `AI__Endpoint`, `AI__ApiKey` and `AI__RequestType` from the `LLM_*` variables so wiki jobs use your provider.
* MCP endpoints have no authentication upstream (unless Google OAuth is set up); Caddy requires `MCP_TOKEN`.
* Self-registration is blocked unless `ALLOW_REGISTRATION=true`.
* Both services exit non-zero when the app stops (upstream exits 0 after a startup error), so Railway's restart policy applies.
* Small-plan defaults: workstation GC with `DOTNET_GCConserveMemory`, 2 parallel document jobs, single-threaded git packing, Node heap 256 MB.

### Updates

A merge to `main` sends everyone who deployed the template an update notice in Railway. Each version is listed in [`CHANGELOG.md`](CHANGELOG.md) with breaking changes first.
