#!/usr/bin/env python3
"""
Tailscale MCP Server - Admin Console API Access

This MCP server provides tools to interact with the Tailscale admin API
for managing devices, users, ACLs, and network configuration.
"""

import os
import json
import aiohttp
from mcp.types import Tool
from mcp.server import Server
from mcp.server.stdio import stdio_server
from pydantic import BaseModel


class TailscaleMCP:
    """Tailscale MCP server implementation."""
    
    def __init__(self):
        self.api_key = os.environ.get('TAILSCALE_API_KEY')
        self.tailnet = os.environ.get('TAILSCALE_TAILNET', 'tail303fda')
        self.base_url = f"https://api.tailscale.com/api/v2/tailnet/{self.tailnet}"
        
        if not self.api_key:
            raise ValueError("TAILSCALE_API_KEY environment variable is required")
    
    async def get_devices(self) -> list[dict]:
        """Get all devices in the tailnet."""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.base_url}/device",
                headers={"Authorization": f"Bearer {self.api_key}"}
            ) as response:
                if response.status != 200:
                    raise Exception(f"API error: {response.status} {await response.text()}")
                data = await response.json()
                return data.get('devices', [])
    
    async def get_device(self, device_id: str) -> dict:
        """Get details for a specific device."""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.base_url}/device/{device_id}",
                headers={"Authorization": f"Bearer {self.api_key}"}
            ) as response:
                if response.status != 200:
                    raise Exception(f"API error: {response.status} {await response.text()}")
                return await response.json()
    
    async def reboot_device(self, device_id: str) -> dict:
        """Reboot a specific device."""
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/device/{device_id}/reboot",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json"
                }
            ) as response:
                if response.status not in [200, 202]:
                    raise Exception(f"API error: {response.status} {await response.text()}")
                return await response.json()
    
    async def get_users(self) -> list[dict]:
        """Get all users in the tailnet."""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.base_url}/user",
                headers={"Authorization": f"Bearer {self.api_key}"}
            ) as response:
                if response.status != 200:
                    raise Exception(f"API error: {response.status} {await response.text()}")
                data = await response.json()
                return data.get('users', [])
    
    async def get_acl(self) -> dict:
        """Get the current ACL configuration."""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.base_url}/acl",
                headers={"Authorization": f"Bearer {self.api_key}"}
            ) as response:
                if response.status != 200:
                    raise Exception(f"API error: {response.status} {await response.text()}")
                return await response.json()
    
    async def get_network_settings(self) -> dict:
        """Get network settings and configuration."""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.base_url}/settings",
                headers={"Authorization": f"Bearer {self.api_key}"}
            ) as response:
                if response.status != 200:
                    raise Exception(f"API error: {response.status} {await response.text()}")
                return await response.json()


# Create MCP server instance
app = Server("tailscale-admin")
tailscale_mcp = TailscaleMCP()


@app.list_tools()
async def list_tools():
    """List available Tailscale admin tools."""
    return [
        Tool(name="list_devices", description="Get all devices in the Tailscale tailnet with their status and details", inputSchema={"type": "object", "properties": {}, "required": []}),
        Tool(name="get_device", description="Get details for a specific device by ID", inputSchema={"type": "object", "properties": {"device_id": {"type": "string", "description": "The device ID to look up"}}, "required": ["device_id"]}),
        Tool(name="reboot_device", description="Reboot a specific device in the Tailscale network", inputSchema={"type": "object", "properties": {"device_id": {"type": "string", "description": "The device ID to reboot"}}, "required": ["device_id"]}),
        Tool(name="list_users", description="Get all users in the Tailscale tailnet", inputSchema={"type": "object", "properties": {}, "required": []}),
        Tool(name="get_acl", description="Get the current ACL (Access Control List) configuration", inputSchema={"type": "object", "properties": {}, "required": []}),
        Tool(name="get_network_settings", description="Get network settings and configuration for the tailnet", inputSchema={"type": "object", "properties": {}, "required": []})
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list:
    """Call a Tailscale admin tool."""
    try:
        if name == "list_devices":
            devices = await tailscale_mcp.get_devices()
            return [{
                "type": "text",
                "text": json.dumps(devices, indent=2, default=str)
            }]
        
        elif name == "get_device":
            device_id = arguments.get("device_id")
            if not device_id:
                raise ValueError("device_id is required")
            device = await tailscale_mcp.get_device(device_id)
            return [{
                "type": "text",
                "text": json.dumps(device, indent=2, default=str)
            }]
        
        elif name == "reboot_device":
            device_id = arguments.get("device_id")
            if not device_id:
                raise ValueError("device_id is required")
            result = await tailscale_mcp.reboot_device(device_id)
            return [{
                "type": "text",
                "text": json.dumps(result, indent=2, default=str)
            }]
        
        elif name == "list_users":
            users = await tailscale_mcp.get_users()
            return [{
                "type": "text",
                "text": json.dumps(users, indent=2, default=str)
            }]
        
        elif name == "get_acl":
            acl = await tailscale_mcp.get_acl()
            return [{
                "type": "text",
                "text": json.dumps(acl, indent=2, default=str)
            }]
        
        elif name == "get_network_settings":
            settings = await tailscale_mcp.get_network_settings()
            return [{
                "type": "text",
                "text": json.dumps(settings, indent=2, default=str)
            }]
        
        else:
            raise ValueError(f"Unknown tool: {name}")
    
    except Exception as e:
        return [{
            "type": "text",
            "text": f"Error: {str(e)}"
        }]


async def main():
    """Run the MCP server."""
    async with stdio_server() as (read_stream, write_stream):
        await app.run(
            read_stream,
            write_stream,
            app.create_initialization_options()
        )


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
