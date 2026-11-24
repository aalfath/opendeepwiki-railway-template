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

**Resources**: it runs on Railway's smallest plan (0.5 GB RAM per service): after a wiki run the backend used about 260 MB, the web UI about 90 MB and Postgres about 120 MB. Large repositories need more RAM for cloning: give the Backend 1 GB or more for repositories over a few hundred MB.

**Not included**: Graphify knowledge graphs run only when an admin starts them, and the Feishu, QQ, WeChat and Slack bots, GitHub App import and Google sign-in stay off until you configure them under Admin. Self-registration is blocked; set `ALLOW_REGISTRATION=true` on the Backend to open it.

**Updates**: the services build from the public template repository, which pins upstream's images by digest. When a new OpenDeepWiki release is tested, the repository is updated and Railway shows you an update notice; read `CHANGELOG.md` before applying it.

## Why Deploy OpenDeepWiki on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenDeepWiki on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
