# Scaling with a Load Balancer – Step by Step

## 1. About

In [06 – Docker Compose](06-docker-compose.md), the frontend talked to exactly one backend. In this walkthrough a **load balancer** sits between them as a third container, and you run several backend instances behind it: you watch the requests being distributed, scale up and down while everything keeps running, and let an instance crash.

Every code block contains **exactly one command**.

### 1.1 Prerequisites

- [06 – Docker Compose](06-docker-compose.md)
- A GitHub Codespace on this repository

> **On a Mac:** port 5000 is often taken by the AirPlay Receiver – change `"5000:5000"` to `"5001:5000"` in the Compose file and use port 5001.

## 2. The Compose file

Change into the `code` folder:

```bash
cd code
```

Look at the second Compose file:

```bash
cat compose-lb.yaml
```

```yaml
name: shopping

services:
  proxy:
    image: traefik:v3.6
    command:
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --api.insecure=true
    ports:
      - "8000:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
  backend:
    build: ./backend-fastapi
    deploy:
      replicas: 2
    restart: on-failure
    labels:
      - traefik.enable=true
      - traefik.http.routers.backend.rule=PathPrefix(`/`)
      - traefik.http.services.backend.loadbalancer.server.port=8000
  frontend:
    build: ./frontend-flask
    ports:
      - "5000:5000"
    environment:
      BACKEND_URL: http://proxy:80
    depends_on:
      - proxy
      - backend
```

What is new compared to `compose.yaml`:

- **`proxy`** is [Traefik](https://traefik.io), a reverse proxy and load balancer from the CNCF landscape. It watches Docker through the Docker socket and finds the backend containers by their `labels` – so it notices new instances on its own.
- **`backend`** runs as **2 replicas** and restarts by itself if it crashes (`restart: on-failure`).
- **`frontend`** no longer talks to `backend` but to `proxy` (`BACKEND_URL: http://proxy:80`). The frontend does not know how many backends there are.
- The proxy is published on port **8000**, so you can also call the backends through it from the command line. Port **8080** shows Traefik's dashboard.

```text
browser ──5000──> frontend ──> proxy ──┬──> backend-1
                                       └──> backend-2
curl ─────8000──────────────> proxy ───┘
```

## 3. Start it

```bash
docker compose -f compose-lb.yaml up -d
```

```bash
docker compose -f compose-lb.yaml ps
```

> **Output**
> ```text
> NAME                  SERVICE    STATUS         PORTS
> shopping-backend-1    backend    Up 6 seconds   8000/tcp
> shopping-backend-2    backend    Up 6 seconds   8000/tcp
> shopping-frontend-1   frontend   Up 6 seconds   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
> shopping-proxy-1      proxy      Up 6 seconds   0.0.0.0:8000->80/tcp, [::]:8000->80/tcp, 0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
> ```

Four containers: one proxy, two backends, one frontend. Open port 5000 in the **Ports** tab – the shopping list works as before. Open port 8080 for the Traefik dashboard.

## 4. Watch the load balancer

Call the backends through the proxy in a loop (stop with **Ctrl+C**):

```bash
while true; do curl -s localhost:8000/hello; echo; sleep 1; done
```

> **Output**
> ```text
> {{"message":"Good Morning!","hostname":"dc8c807d8d1f"}}
> {{"message":"Good Morning!","hostname":"229c8f66aa6a"}}
> {{"message":"Good Morning!","hostname":"dc8c807d8d1f"}}
> {{"message":"Good Morning!","hostname":"229c8f66aa6a"}}
> ```

The hostname alternates: the proxy sends each request to the next instance – *round robin*.

Now ask through the frontend:

```bash
while true; do curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"; sleep 1; done
```

> **Output**
> ```text
> Server: <strong>dc8c807d8d1f
> Server: <strong>dc8c807d8d1f
> Server: <strong>dc8c807d8d1f
> ```

Always the same backend? Each page of the frontend makes **two** requests to the backend: `/hello` and `/shopping-list`. Round robin counts requests, not pages – with two backends, `/hello` always lands on the same one. Keep that in mind for the next step.

## 5. Scale up and down

Scale to three backends while everything is running:

```bash
docker compose -f compose-lb.yaml up -d --scale backend=3
```

```bash
while true; do curl -s localhost:8000/hello; echo; sleep 1; done
```

Three different hostnames – Traefik found the new instance without any configuration change. Through the frontend, the hostname now changes, too:

```bash
while true; do curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"; sleep 1; done
```

Scale down to one:

```bash
docker compose -f compose-lb.yaml up -d --scale backend=1
```

```bash
docker compose -f compose-lb.yaml ps
```

One backend left – and the frontend keeps working.

## 6. Let an instance crash

Scale back to three:

```bash
docker compose -f compose-lb.yaml up -d --scale backend=3
```

Crash one of them with `/kill` from tutorial 02. The proxy sends the request to whichever instance is next:

```bash
curl localhost:8000/kill
```

> **Output**
> ```text
> Bad Gateway
> ```

The instance died before it could answer, so the proxy reports an error. Look at the containers:

```bash
docker compose -f compose-lb.yaml ps
```

> **Output**
> ```text
> NAME                  SERVICE    STATUS          PORTS
> shopping-backend-1    backend    Up 2 minutes    8000/tcp
> shopping-backend-2    backend    Up 2 minutes    8000/tcp
> shopping-backend-3    backend    Up 3 seconds    8000/tcp
> ...
> ```

One instance has been up for only a few seconds: `restart: on-failure` brought it back. Meanwhile, the other two kept answering:

```bash
while true; do curl -s localhost:8000/hello; echo; sleep 1; done
```

Add items in the browser while you scale and crash instances, and watch the shopping list. Something is wrong with it – that is the topic of [08 – State](08-state.md).

## 7. Clean up

```bash
docker compose -f compose-lb.yaml down
```

```bash
cd ..
```

## 8. Overview

| Command | What it does |
|---|---|
| `docker compose -f compose-lb.yaml up -d` | starts proxy, backends and frontend |
| `docker compose -f compose-lb.yaml up -d --scale backend=3` | changes the number of backend instances while running |
| `while true; do curl -s localhost:8000/hello; echo; sleep 1; done` | calls the backends through the proxy once per second |
| `curl localhost:8000/kill` | crashes one backend instance; `restart: on-failure` brings it back |

Next: [08 – State](08-state.md)
