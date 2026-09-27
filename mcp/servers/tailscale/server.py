#!/usr/bin/env python3
"""
Tailscale MCP Server - read-only Admin API access

Tools to look at the tailnet through the Tailscale Admin API: devices, users,
the policy file (ACL) and tailnet settings. Nothing here changes the tailnet.

Credentials, in order of preference:
  - TAILSCALE_OAUTH_CLIENT_ID + TAILSCALE_OAUTH_CLIENT_SECRET: an OAuth client,
    which can be limited to read scopes (devices:core:read, users:read,
    policy_file:read, ...). Access tokens are fetched and refreshed here.
  - TAILSCALE_API_KEY: a tskey-api-... key (full access to the tailnet).
TAILSCALE_TAILNET defaults to "-", the credential's own tailnet.

Without credentials the server still starts (so one missing secret doesn't
take down the shared mcp stack); every tool then answers "not configured".
"""

import os
import json
import time
import aiohttp
from mcp.types import Tool, TextContent
from mcp.server import Server
from mcp.server.stdio import stdio_server

API = "https://api.tailscale.com/api/v2"


class TailscaleMCP:
    """Tailscale Admin API client."""

    def __init__(self):
        self.client_id = os.environ.get('TAILSCALE_OAUTH_CLIENT_ID')
        self.client_secret = os.environ.get('TAILSCALE_OAUTH_CLIENT_SECRET')
        self.api_key = os.environ.get('TAILSCALE_API_KEY')
        self.tailnet = os.environ.get('TAILSCALE_TAILNET') or '-'  # '-' = the credential's own tailnet
        self.base_url = f"{API}/tailnet/{self.tailnet}"
        self._token = None
        self._token_expires = 0.0

    async def _auth_header(self, session: aiohttp.ClientSession) -> dict:
        if self.client_id and self.client_secret:
            if not self._token or time.time() > self._token_expires - 60:
                async with session.post(
                    f"{API}/oauth/token",
                    data={"client_id": self.client_id, "client_secret": self.client_secret},
                ) as response:
                    if response.status != 200:
                        raise Exception(f"OAuth token error: {response.status} {await response.text()}")
                    data = await response.json()
                    self._token = data["access_token"]
                    self._token_expires = time.time() + int(data.get("expires_in", 3600))
            return {"Authorization": f"Bearer {self._token}"}
        if self.api_key:
            return {"Authorization": f"Bearer {self.api_key}"}
        raise Exception(
            "not configured: set TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_OAUTH_CLIENT_SECRET "
            "(preferred, read scopes only) or TAILSCALE_API_KEY"
        )

    async def _get(self, path: str) -> dict:
        async with aiohttp.ClientSession() as session:
            headers = await self._auth_header(session)
            async with session.get(f"{self.base_url}{path}", headers=headers) as response:
                if response.status != 200:
                    raise Exception(f"API error: {response.status} {await response.text()}")
                return await response.json()

    async def get_devices(self) -> list[dict]:
        """Get all devices in the tailnet."""
        return (await self._get("/devices")).get('devices', [])

    async def get_device(self, device_id: str) -> dict:
        """Get details for a specific device (device endpoints aren't under /tailnet)."""
        async with aiohttp.ClientSession() as session:
            headers = await self._auth_header(session)
            async with session.get(f"{API}/device/{device_id}", headers=headers) as response:
                if response.status != 200:
                    raise Exception(f"API error: {response.status} {await response.text()}")
                return await response.json()

    async def get_users(self) -> list[dict]:
        """Get all users in the tailnet."""
        return (await self._get("/users")).get('users', [])

    async def get_acl(self) -> dict:
        """Get the tailnet policy file (ACL)."""
        return await self._get("/acl")

    async def get_network_settings(self) -> dict:
        """Get tailnet settings."""
        return await self._get("/settings")


# Create MCP server instance
app = Server("tailscale-admin")
tailscale_mcp = TailscaleMCP()

NO_ARGS = {"type": "object", "properties": {}, "required": []}


@app.list_tools()
async def list_tools():
    """List available Tailscale admin tools (all read-only)."""
    return [
        Tool(name="list_devices", description="List all devices in the Tailscale tailnet with their status and details", inputSchema=NO_ARGS),
        Tool(name="get_device", description="Get details for one device by its device ID (from list_devices)", inputSchema={"type": "object", "properties": {"device_id": {"type": "string", "description": "The device ID to look up"}}, "required": ["device_id"]}),
        Tool(name="list_users", description="List all users in the Tailscale tailnet", inputSchema=NO_ARGS),
        Tool(name="get_acl", description="Get the tailnet policy file (ACLs, tags, grants)", inputSchema=NO_ARGS),
        Tool(name="get_network_settings", description="Get tailnet settings", inputSchema=NO_ARGS),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    """Call a Tailscale admin tool."""
    try:
        if name == "list_devices":
            result = await tailscale_mcp.get_devices()
        elif name == "get_device":
            device_id = arguments.get("device_id")
            if not device_id:
                raise ValueError("device_id is required")
            result = await tailscale_mcp.get_device(device_id)
        elif name == "list_users":
            result = await tailscale_mcp.get_users()
        elif name == "get_acl":
            result = await tailscale_mcp.get_acl()
        elif name == "get_network_settings":
            result = await tailscale_mcp.get_network_settings()
        else:
            raise ValueError(f"Unknown tool: {name}")
        return [TextContent(type="text", text=json.dumps(result, indent=2, default=str))]
    except Exception as e:
        return [TextContent(type="text", text=f"Error: {e}")]


async def main():
    """Run the MCP server over stdio (mcp-proxy serves it over HTTP)."""
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
