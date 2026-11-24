# OpenDeepWiki backend (ASP.NET Core 10) for Railway.
# Upstream publishes images only on its own Aliyun registry, and its "2.0.6" tag is
# re-pushed from main, so the digest is the real pin (built 2026-10-23 from 7aa53b8).
FROM caddy:2.11.9@sha256:4851e54a46b206517c574821bb5cc67f170d2156041e9fbc4c9193b45e84a75b AS caddy

FROM crpi-j9ha7sxwhatgtvj4.cn-shenzhen.personal.cr.aliyuncs.com/open-deepwiki/opendeepwiki:2.0.6@sha256:1a1eccbde82fbb249c1984d4311e8681797c371930870972f9d0c7b8441c15d4

USER root
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --chmod=755 start.sh /usr/local/bin/odw-start
COPY activate-providers.py /usr/local/lib/odw/activate-providers.py
# Fail the build early if a tool the wrapper needs is missing from the base image.
RUN command -v setpriv && command -v curl && command -v python3 && caddy version

ENV ASPNETCORE_ENVIRONMENT=Production \
    Database__Type=postgresql \
    REPOSITORIES_DIRECTORY=/data/repos \
    Skills__BasePath=/data/skills \
    Logging__MinimumLevel=Information \
    Serilog__MinimumLevel__Override__OpenDeepWiki=Information \
    DOTNET_gcServer=0 \
    DOTNET_GCConserveMemory=7 \
    DOTNET_PROCESSOR_COUNT=2 \
    DOTNET_TieredPGO=0 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    GOMAXPROCS=2 \
    PORT=8080

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/odw-start"]
