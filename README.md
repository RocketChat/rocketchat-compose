
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
