
# Rocket.Chat Compose Files

## TLDR;

1. Clone: `git clone --depth 1 https://github.com/RocketChat/rocketchat-compose.git`
2. cd to the cloned dir: `cd rocketchat-compose`
3. Copy the example environment file: `cp .env.example .env`
4. Edit .env file and update values
5. Start the stack: `docker compose -f compose.database.yml -f compose.monitoring.yml -f compose.traefik.yml -f compose.yml up -d`

You can access Rocket.Chat at: http://localhost

You can login to Grafana at: http://grafana.localhost with the default credentials:
* User: admin
* Password: rc-admin

## Getting Started

First, clone this repository:

```bash
git clone --depth 1 https://github.com/RocketChat/rocketchat-compose.git
```

---


### Docker/Podman Compose


For deploying the recommended stack with Rocket.Chat, Traefik, MongoDB, NATS, and Prometheus for monitoring:

1. **Configure environment variables:**
   - Copy the example environment file:
     ```bash
     cp .env.example .env
     ```
   - Edit `.env` to fit your deployment. Recommended changes - we recommend to keep other values from the example for reference.
     ```env
     # Rocket.Chat Cloud registration token (optional)
     REG_TOKEN=
     # Set to 'https' to enable HTTPS with Traefik (recommended for internet exposure)
     TRAEFIK_PROTOCOL=http
     # Set to true after you've set your domain and lets encrypt email
     LETSENCRYPT_ENABLED=
     # Email for Let's Encrypt certificate
     LETSENCRYPT_EMAIL=
     # Domain for Rocket.Chat
     DOMAIN=localhost
     # Domain for Grafana, blank to use as a path
     GRAFANA_DOMAIN=
     GRAFANA_PATH=/grafana
     # Should match your domain; use https if enabled
     ROOT_URL=http://localhost
     ```

2. **Using Grafana as a Path instead of Subdomain:**
  - Change the variables
    ```env
    # set this to empty
    GRAFANA_DOMAIN=
    # set this to you desired path without trailing slash
    GRAFANA_PATH=/grafana
    ```
  - If you wan't to use subdomain
    ```env
    # set this to your subdomain
    GRAFANA_DOMAIN=grafana.your-domain.com
    # set this as empty
    GRAFANA_PATH=
    ```

3. **Start the stack:**
   - With Docker Compose:
     ```bash
     docker compose \
       -f compose.monitoring.yml \
       -f compose.traefik.yml \
       -f compose.database.yml \
       -f compose.yml \
       up -d
     ```
   - Or with Podman Compose:
     ```bash
     podman compose \
       -f compose.monitoring.yml \
       -f compose.traefik.yml \
       -f compose.database.yml \
       -f compose.yml \
       up -d
     ```

   This will launch all containers. Rocket.Chat will be available at [http://localhost](http://localhost), and Grafana at [http://grafana.localhost](http://grafana.localhost).
   > **Note:** If deploying to a custom domain, update `ROOT_URL` and related variables accordingly.

4. **Stop the stack:**
  - With Docker Compose:
    ```bash
    docker compose \
        -f compose.monitoring.yml \
        -f compose.traefik.yml \
        -f compose.database.yml \
        -f compose.yml \
        down
    ```
  - Or with Podman Compose:
     ```bash
     podman compose \
       -f compose.monitoring.yml \
       -f compose.traefik.yml \
       -f compose.database.yml \
       -f compose.yml \
       down
     ```

---

### Customizing the stack

To exclude components (e.g., MongoDB or Prometheus), simply remove their compose files from the command. For example, to deploy Rocket.Chat with Traefik only:

```bash
podman compose \
  -f compose.traefik.yml \
  -f compose.yml \
  up -d
```


---

### Multiple servers
When running multiple Rocket.Chat servers, you can configure Traefik to discover those servers and include them in load balancing by adding a variable in the `.env` file:

```env
ROCKETCHAT_BACKEND_SERVERS=rocketchat-1:3000,rocketchat-2:3000,rocketchat-3:3000
```
### VoIP setup
There is a quick way for rolling out a VoIP solution using Drachtio and FreeSwitch as a SIP proxy. To achieve this some network configurations are required. `compose.network.yml` defines a network private network called `rc_voip_private` for VoIP servers. Currently it uses subnet 172.28.0.0/16 and assigns static IP 172.28.0.10 and 172.28.0.11. If you would want to change this network configuration, add desired value for subnet and static ip addresses in that subnet to `freeswitch` and `drachtio` service. `compose.network.yml` also configures rocketchat service to have access to default and `rc_voip_private` network. It communicates with non VoIP services on default network and VoIP services on `rc_voip_private` network. Once the desired configuration changes are made, run
```bash
    docker compose \
        -f compose.monitoring.yml \
        -f compose.traefik.yml \
        -f compose.database.yml \
        -f compose.yml \
        -f compose.voip.yml \
        -f compose.network.yml \
        up -d
```
to start the stack. Once the stack is running, do the necessary VoIP configurations using the static ips for FreeSwitch and Drachtio.
