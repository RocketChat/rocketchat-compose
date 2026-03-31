# Using an external MongoDB

This guide describes how to run Rocket.Chat from this repository against a MongoDB instance you manage yourself (on another host, MongoDB Atlas, a managed service, and so on), instead of the bundled MongoDB in `compose.database.yml`.

> **Note:** With external components used, our monitoring stack will not be able to scrape metrics from those services. Read [./external-service-metrics.md](./external-service-metrics.md) for more information.

## Prerequisites

1. **Replica set**  
   Rocket.Chat expects a MongoDB replica set. Your external cluster must be initialized as a replica set (even a single-node replica set is valid). The default connection string in this stack uses `replicaSet=rs0`; your replica set name must match what you put in `MONGO_URL`.

2. **Database and access**  
   Create a database user with permissions appropriate for Rocket.Chat, and note the authentication database (`authSource`) if it is not the default.

3. **Network reachability**  
   The `rocketchat` container must be able to reach every MongoDB host and port in your connection string (including replica set members). Open firewalls and security groups accordingly.

---

## 1. Configure environment variables

Copy `.env.example` to `.env` if you have not already, then set **`MONGO_URL`**: the full MongoDB connection URI for Rocket.Chat when you are not using the bundled MongoDB.

### Example `MONGO_URL` values

**Standard replica set (single URI with options):**

```env
MONGO_URL=mongodb://USERNAME:PASSWORD@mongo1.example.com:27017,mongo2.example.com:27017/rocketchat?replicaSet=rs0&authSource=admin
```

**MongoDB Atlas (`mongodb+srv`):**

```env
MONGO_URL=mongodb+srv://USERNAME:PASSWORD@cluster0.xxxxx.mongodb.net/rocketchat?retryWrites=true&w=majority
```

Atlas and other SRV-based URLs are treated specially by the Rocket.Chat entrypoint in `compose.yml`: the container **skips** the TCP wait loop and starts the app immediately, because SRV resolution is not handled by the same `nc` check used for `mongodb://` URLs.

**MongoDB on the Docker host (Linux):**

The hostname `mongodb` in the default stack refers to the bundled container. From inside another container, use the host’s IP, a DNS name, or Docker’s host gateway, for example:

```env
MONGO_URL=mongodb://user:pass@172.17.0.1:27017/rocketchat?replicaSet=rs0&authSource=admin
```

Or add `extra_hosts` in an override so `host.docker.internal` resolves (pattern depends on your Docker version).

Ensure `replicaSet` and `authSource` (and TLS options if you use TLS) match your deployment.

---

## 2. Change the Compose command

The [README](../README.md) full stack includes `compose.database.yml` for bundled MongoDB. For external MongoDB, **omit** `compose.database.yml` and **keep** `compose.nats.yml` so the bundled NATS and `nats-exporter` still run (unless you also use [external NATS](external-nats.md)):

```bash
docker compose \
  -f compose.monitoring.yml \
  -f compose.traefik.yml \
  -f compose.yml \
  -f compose.nats.yml \
  -f docker.yml \
  up -d
```

If you used Podman, replace `docker compose` with `podman compose` and include `podman.yml` or `podman-rootful.yml` as in the README.

---

## 3. Monitoring and optional services

- **Prometheus / Grafana**: File-based discovery includes `mongodb-exporter`. If you no longer run `mongodb-exporter` from this stack, adjust Prometheus scrape configuration if you rely on those metrics.
- **Variables in `.env.example`** such as `MONGODB_BIND_IP` and `MONGODB_PORT_NUMBER` apply to the **bundled** MongoDB service; they do not configure an external server.

---
