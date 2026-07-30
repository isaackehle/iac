```shell
STACK_PATH="/volume1/docker/stacks/portainer"

mkdir -p $STACK_PATH/{data,ts-state,ts-config}
```

## In Portainer

- Go to Stacks → Add stack
- Deploy from repository: `github.com/isaackehle/iac.git`
- Repository path: `portainer/docker-compose.yml`
- Create .env file with your Tailscale auth key (TS_AUTHKEY_PORTAINER=...)
- Deploy the stack via Portainer UI"
