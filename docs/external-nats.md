# Using an external NATS

This guide describes how to run Rocket.Chat from this repository against a NATS server you manage yourself (another host, a managed NATS service, and so on), instead of the bundled NATS and `nats-exporter` in `compose.nats.yml`.

> **Note:** With external components used, our monitoring stack will not be able to scrape metrics from those services. Read [./external-service-metrics.md](./external-service-metrics.md) for more information.

## Prerequisites

1. **Reachable broker**  
   The `rocketchat` container must be able to open a client connection to your NATS host and port (default client port is `4222`). Open firewalls and security groups accordingly.

2. **Transporter URL**  
   Rocket.Chat uses the `TRANSPORTER` environment variable. In `compose.yml` this is set from `NATS_URL`, defaulting to `monolith+nats://nats:4222` when `NATS_URL` is unset (the hostname `nats` refers to the bundled service). For an external broker, set `NATS_URL` to the same scheme with your host and port, for example `monolith+nats://nats.example.com:4222`.

---

## 1. Configure environment variables

Copy `.env.example` to `.env` if you have not already, then set **`NATS_URL`** to the full Rocket.Chat transporter value pointing at your external NATS:

```env
NATS_URL=monolith+nats://YOUR_NATS_HOST:4222
```

Use the hostname or IP that is reachable **from inside the Rocket.Chat container** (not only from your laptop). For NATS on the Docker host from a Linux container, you may need the host gateway IP or an `extra_hosts` entry.

If your external NATS uses TLS or a non-default port, use the URL form your Rocket.Chat / NATS deployment expects for that setup.

---

## 2. Change the Compose command

The [README](../README.md) includes `compose.nats.yml` for bundled NATS and Prometheus `nats-exporter`. For **external** NATS, **omit** `compose.nats.yml` so the `nats` and `nats-exporter` services are not started:

```bash
docker compose \
  -f compose.monitoring.yml \
  -f compose.traefik.yml \
  -f compose.database.yml \
  -f compose.yml \
  -f docker.yml \
  up -d
```

Adjust the file list to match your deployment (for example omit `compose.database.yml` when using [external MongoDB](external-mongo.md); keep the same `-f` list for `up`, `down`, and `logs`).

If you used Podman, replace `docker compose` with `podman compose` and include `podman.yml` or `podman-rootful.yml` as in the README.

---

## 3. Monitoring and optional services

- **Prometheus**: File-based discovery includes `nats-exporter`. If you no longer run `nats-exporter` from this stack, adjust `files/prometheus/file_sd_configs/nats.yml` (or your equivalent) if you rely on those scrape targets.
- **Variables in `.env.example`** such as `NATS_BIND_IP` and `NATS_PORT_NUMBER` apply to the **bundled** NATS service in `compose.nats.yml`; they do not configure an external broker.

---

## 4. Checklist

- [ ] `NATS_URL` is set to a transporter URL your Rocket.Chat instance can use to reach the external NATS.
- [ ] `compose.nats.yml` is omitted from `docker compose` / `podman compose` when using external NATS.
- [ ] Same `-f` list used consistently for `up`, `logs`, `down`, and other compose commands.

For Rocket.Chat deployment details, refer to the [official Rocket.Chat documentation](https://docs.rocket.chat/).
