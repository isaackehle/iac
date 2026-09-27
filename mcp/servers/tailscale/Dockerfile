# Tailscale admin MCP server (read-only), served over HTTP by mcp-proxy.
# mcp-proxy 0.12 works with mcp 1.28+ (tested 2026-09-27), so no mcp<1.20 pin.
FROM python:3.12-alpine
WORKDIR /app
COPY requirements.txt server.py ./
RUN pip install --no-cache-dir -r requirements.txt
USER nobody
# --pass-environment: mcp-proxy doesn't pass env vars to the server otherwise.
ENTRYPOINT ["mcp-proxy", "--pass-environment", "--host", "127.0.0.1", "--port", "8488", "--", "python", "/app/server.py"]
