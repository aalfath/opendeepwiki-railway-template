# OpenDeepWiki web UI (Next.js 16 standalone) for Railway.
# Upstream publishes images only on its own Aliyun registry, and its "2.0.6" tag is
# re-pushed from main, so the digest is the real pin (built 2026-10-22).
FROM crpi-j9ha7sxwhatgtvj4.cn-shenzhen.personal.cr.aliyuncs.com/open-deepwiki/opendeepwiki-web:2.0.6@sha256:7c48551b8cd529a52aa917f1240338ffec63362829eb12a895a67188ca7fc8f2

COPY --chmod=755 start.sh /usr/local/bin/odw-web-start
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/odw-web-start"]
