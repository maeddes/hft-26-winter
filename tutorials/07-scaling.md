# Scaling with a Load Balancer – Step by Step

## 1. About

In [06 – Docker Compose](06-docker-compose.md), the frontend talked to exactly one backend. In this walkthrough a **load balancer** sits between them as a third container, and you run several backend instances behind it: you see how the load balancer finds the instances, watch the requests being distributed, scale up and down while everything keeps running, and let an instance crash.

After almost every step you look again – `docker compose ps`, `docker network inspect`, and what the load balancer itself knows – and compare with what you saw before.

Every code block contains **exactly one command**. IDs and addresses in the outputs are examples; yours will differ.

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

- **`proxy`** is [Traefik](https://traefik.io), a reverse proxy and load balancer. Note `image:` without `build:` – a published image, as in tutorial 06, section 6.1.
- **`backend`** runs as **2 replicas** – one service, two containers – and restarts by itself if it crashes (`restart: on-failure`).
- **`frontend`** no longer talks to `backend` but to `proxy` (`BACKEND_URL: http://proxy:80`). The frontend does not know how many backends there are.
- The proxy is published on port **8000**, so you can also call the backends through it from the command line. Port **8080** shows Traefik's dashboard.

```text
browser ──5000──> frontend ──> proxy ──┬──> backend-1
                                       └──> backend-2
curl ─────8000──────────────> proxy ───┘
```

### 2.1 How does Traefik know about the backends?

Nothing in the `proxy` section names the backend. Instead:

- `--providers.docker=true` – Traefik asks Docker which containers are running. It does so through the **Docker socket**, `/var/run/docker.sock`, mounted read-only into the container – the same interface the `docker` command uses.
- `--providers.docker.exposedbydefault=false` – Traefik ignores every container unless it says otherwise.
- The **labels** of the backend say otherwise: `traefik.enable=true` – include me; ``routers.backend.rule=PathPrefix(`/`)`` – send every path to me; `services.backend.loadbalancer.server.port=8000` – my app listens on 8000.
- `--entrypoints.web.address=:80` – Traefik accepts requests on port 80 inside its container (8000 on your machine).
- `--api.insecure=true` – the dashboard and its API on port 8080, without login. Fine for a demo, not for production.

Every backend container carries the same labels, so Traefik finds all of them – and every new one.

## 3. Start it

```bash
docker compose -f compose-lb.yaml up -d
```

```bash
docker compose -f compose-lb.yaml ps
```

> **Output**
> ```text
> NAME                  IMAGE               COMMAND                  SERVICE    CREATED         STATUS         PORTS
> shopping-backend-1    shopping-backend    "uvicorn main:app --…"   backend    5 seconds ago   Up 4 seconds   8000/tcp
> shopping-backend-2    shopping-backend    "uvicorn main:app --…"   backend    5 seconds ago   Up 4 seconds   8000/tcp
> shopping-frontend-1   shopping-frontend   "gunicorn --bind 0.0…"   frontend   5 seconds ago   Up 4 seconds   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
> shopping-proxy-1      traefik:v3.6        "/entrypoint.sh --pr…"   proxy      5 seconds ago   Up 4 seconds   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp, 0.0.0.0:8000->80/tcp, [::]:8000->80/tcp
> ```

Four containers: one proxy, two backends, one frontend. Who is in the network?

```bash
docker network inspect shopping_default --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> shopping-frontend-1 172.27.0.5/16
> shopping-proxy-1 172.27.0.3/16
> shopping-backend-2 172.27.0.4/16
> shopping-backend-1 172.27.0.2/16
> ```

Note the two backend addresses. Open port 5000 in the **Ports** tab – the shopping list works as before. Open port 8080 for the Traefik dashboard.

## 4. What the load balancer knows

Ask Traefik's API which servers belong to the service `backend`:

```bash
curl -s localhost:8080/api/http/services/backend@docker | grep -o '"url":"[^"]*"'
```

> **Output**
> ```text
> "url":"http://172.27.0.4:8000"
> "url":"http://172.27.0.2:8000"
> ```

Compare with `docker network inspect`: the addresses of the two backend containers, with the port from the label. Traefik found them on its own. (Without `| grep …` you see the full answer, including the health of each server.)

## 5. Watch the load balancer

Call the backends through the proxy six times:

```bash
for i in 1 2 3 4 5 6; do curl -s localhost:8000/hello; echo; done
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"c42c94c0d65f"}
> {"message":"Good Morning!","hostname":"7932d8ce4ff0"}
> {"message":"Good Morning!","hostname":"c42c94c0d65f"}
> {"message":"Good Morning!","hostname":"7932d8ce4ff0"}
> {"message":"Good Morning!","hostname":"c42c94c0d65f"}
> {"message":"Good Morning!","hostname":"7932d8ce4ff0"}
> ```

The hostname alternates: the proxy sends each request to the next instance – *round robin*.

Now ask through the frontend:

```bash
for i in 1 2 3 4 5 6; do curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"; done
```

> **Output**
> ```text
> Server: <strong>c42c94c0d65f
> Server: <strong>c42c94c0d65f
> Server: <strong>c42c94c0d65f
> Server: <strong>c42c94c0d65f
> Server: <strong>c42c94c0d65f
> Server: <strong>c42c94c0d65f
> ```

Always the same backend? This is not a "sticky session" – the proxy has no idea which page you are on. Each page of the frontend makes **two** requests to the backend: `/hello` and `/shopping-list`. Round robin counts requests, not pages – with two backends, `/hello` always lands on the same one. Keep that in mind for the next steps.

### 5.1 Why not just the name `backend`?

Two containers, one service. What does the name `backend` resolve to? The toolbox from tutorial 04 (you are in the `code` folder):

```bash
docker build -t toolbox toolbox
```

```bash
docker run --rm --network shopping_default toolbox nslookup backend
```

> **Output**
> ```text
> Server:		127.0.0.11
> Address:	127.0.0.11#53
>
> Non-authoritative answer:
> Name:	backend
> Address: 172.27.0.4
> Name:	backend
> Address: 172.27.0.2
> ```

**Both** addresses: Compose gives every container of a service the service name. So why the proxy? Call the backend by name six times:

```bash
docker run --rm --network shopping_default toolbox sh -c 'for i in 1 2 3 4 5 6; do curl -s backend:8000/hello; echo; done'
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"7932d8ce4ff0"}
> {"message":"Good Morning!","hostname":"c42c94c0d65f"}
> {"message":"Good Morning!","hostname":"c42c94c0d65f"}
> {"message":"Good Morning!","hostname":"7932d8ce4ff0"}
> ...
> ```

Mixed, but not alternating: the client picks one of the addresses, and which one is up to the client. A client that keeps its connection open stays with one instance for good. Name resolution is not load balancing – the proxy decides per request, and it knows which instances are healthy.

## 6. Scale up and down

Scale to three backends while everything is running:

```bash
docker compose -f compose-lb.yaml up -d --scale backend=3
```

> **Output**
> ```text
>  Container shopping-backend-1 Running
>  Container shopping-backend-2 Running
>  Container shopping-frontend-1 Running
>  Container shopping-proxy-1 Running
>  Container shopping-backend-3 Created
>  Container shopping-backend-3 Started
> ```

Only one new container – the rest keeps running. Look:

```bash
docker compose -f compose-lb.yaml ps
```

```bash
docker network inspect shopping_default --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

`shopping-backend-3` with a new address. And the load balancer?

```bash
curl -s localhost:8080/api/http/services/backend@docker | grep -o '"url":"[^"]*"'
```

> **Output**
> ```text
> "url":"http://172.27.0.6:8000"
> "url":"http://172.27.0.4:8000"
> "url":"http://172.27.0.2:8000"
> ```

Three servers – without any change to Traefik's configuration. Call the backends:

```bash
for i in 1 2 3 4 5 6; do curl -s localhost:8000/hello; echo; done
```

Three different hostnames. Through the frontend, the hostname now changes, too – two requests per page, three instances:

```bash
for i in 1 2 3 4 5 6; do curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"; done
```

Scale down to one:

```bash
docker compose -f compose-lb.yaml up -d --scale backend=1
```

```bash
docker compose -f compose-lb.yaml ps
```

One backend left. The load balancer noticed, too:

```bash
curl -s localhost:8080/api/http/services/backend@docker | grep -o '"url":"[^"]*"'
```

```bash
for i in 1 2 3 4 5 6; do curl -s localhost:8000/hello; echo; done
```

Always the same hostname – and the frontend keeps working.

## 7. Let an instance crash

Scale back to three:

```bash
docker compose -f compose-lb.yaml up -d --scale backend=3
```

```bash
docker compose -f compose-lb.yaml ps backend
```

> **Output**
> ```text
> NAME                 IMAGE              COMMAND                  SERVICE   CREATED          STATUS          PORTS
> shopping-backend-1   shopping-backend   "uvicorn main:app --…"   backend   2 minutes ago    Up 2 minutes    8000/tcp
> shopping-backend-2   shopping-backend   "uvicorn main:app --…"   backend   5 seconds ago    Up 5 seconds    8000/tcp
> shopping-backend-3   shopping-backend   "uvicorn main:app --…"   backend   5 seconds ago    Up 5 seconds    8000/tcp
> ```

Crash one of them with `/kill` from tutorial 02. The proxy sends the request to whichever instance is next:

```bash
curl localhost:8000/kill
```

> **Output**
> ```text
> Bad Gateway
> ```

The instance died before it could answer, so the proxy reports an error. Look again:

```bash
docker compose -f compose-lb.yaml ps backend
```

> **Output**
> ```text
> NAME                 IMAGE              COMMAND                  SERVICE   CREATED          STATUS          PORTS
> shopping-backend-1   shopping-backend   "uvicorn main:app --…"   backend   2 minutes ago    Up 2 seconds    8000/tcp
> shopping-backend-2   shopping-backend   "uvicorn main:app --…"   backend   10 seconds ago   Up 9 seconds    8000/tcp
> shopping-backend-3   shopping-backend   "uvicorn main:app --…"   backend   10 seconds ago   Up 9 seconds    8000/tcp
> ```

Compare CREATED and STATUS: one instance was created minutes ago, but has been up for only a few seconds – `restart: on-failure` brought the same container back. Count the restarts per container (`ps -q` prints only the IDs):

```bash
docker inspect --format '{{.Name}} {{.RestartCount}}' $(docker compose -f compose-lb.yaml ps -q backend)
```

> **Output**
> ```text
> /shopping-backend-1 1
> /shopping-backend-2 0
> /shopping-backend-3 0
> ```

Meanwhile, the other two kept answering:

```bash
for i in 1 2 3 4 5 6; do curl -s localhost:8000/hello; echo; done
```

## 8. Where is the shopping list?

Add an item through the proxy:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "apples", "amount": 3}'
```

And read the list six times:

```bash
for i in 1 2 3 4 5 6; do curl -s localhost:8000/shopping-list; echo; done
```

> **Output**
> ```text
> []
> [{"name":"apples","amount":3}]
> []
> []
> ...
> ```

Sometimes the apples are there, mostly not. Each backend instance keeps its own list in memory – the POST went to one of them, the GETs go to all of them. Try the same in the browser while you scale. Scaling only works for instances that share no state – that is the topic of [08 – State](08-state.md).

## 9. Clean up

```bash
docker compose -f compose-lb.yaml down
```

```bash
docker compose -f compose-lb.yaml ps
```

Empty – all five containers and the network are gone.

```bash
cd ..
```

## 10. Overview

| Command | What it does |
|---|---|
| `docker compose -f compose-lb.yaml up -d` | starts proxy, backends and frontend |
| `docker compose -f compose-lb.yaml up -d --scale backend=3` | changes the number of backend instances while running |
| `docker compose -f compose-lb.yaml ps backend` | lists the containers of one service |
| `curl -s localhost:8080/api/http/services/backend@docker` | asks Traefik which backend instances it knows |
| `for i in 1 2 3 4 5 6; do curl -s localhost:8000/hello; echo; done` | calls the backends through the proxy six times |
| `curl localhost:8000/kill` | crashes one backend instance; `restart: on-failure` brings it back |
| `docker inspect --format '{{.Name}} {{.RestartCount}}' <ids>` | how often each container was restarted |

Next: [08 – State](08-state.md)
