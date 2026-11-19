# Scaling with a Load Balancer – Step by Step

## 1. About

In [06 – Docker Compose](06-docker-compose.md), the frontend talked to exactly one backend. In this walkthrough a **load balancer** sits between them as a third container, and you run several backend instances behind it: you watch the requests being distributed, add an instance while everything keeps running, and let instances crash – first without any protection, then with Docker restarting them.

After almost every step you look again – `docker compose ps`, `docker network inspect`, a loop of requests – and compare with what you saw before.

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
- **`backend`** runs as **2 replicas** – one service, two containers.
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

Every backend container carries the same labels, so Traefik finds all of them – and every new one, and notices when one is gone.

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

Open port 5000 in the **Ports** tab – the shopping list works as before. Open port 8080 for the Traefik dashboard.

## 4. Watch the load balancer

Call the backends through the proxy six times:

```bash
for i in 1 2 3 4 5 6; do curl -s localhost:8000/hello; echo; done
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"9fc0b6795021"}
> {"message":"Good Morning!","hostname":"52f1fce56e35"}
> {"message":"Good Morning!","hostname":"9fc0b6795021"}
> {"message":"Good Morning!","hostname":"52f1fce56e35"}
> {"message":"Good Morning!","hostname":"9fc0b6795021"}
> {"message":"Good Morning!","hostname":"52f1fce56e35"}
> ```

The hostname alternates: the proxy sends each request to the next instance – *round robin*. The hostnames are the container IDs of the two backends.

## 5. Scale up while watching

Open a **second terminal**, change into `code`, and let a loop call the backends once per second. Leave it running for the rest of this tutorial:

```bash
cd code
```

```bash
while true; do curl -s localhost:8000/hello; echo; sleep 1; done
```

Two hostnames, alternating. Now, in the **first terminal**, scale to three backends while everything is running:

```bash
docker compose -f compose-lb.yaml up -d --scale backend=3
```

> **Output**
> ```text
>  Container shopping-frontend-1 Running
>  Container shopping-proxy-1 Running
>  Container shopping-backend-1 Running
>  Container shopping-backend-2 Running
>  Container shopping-backend-3 Created
>  Container shopping-backend-3 Started
> ```

Watch the second terminal: after a moment, a **third hostname** shows up in the loop – Traefik found the new instance without any change to its configuration. Only one new container was created; the others kept running. Look:

```bash
docker compose -f compose-lb.yaml ps backend
```

> **Output**
> ```text
> NAME                 IMAGE              COMMAND                  SERVICE   CREATED          STATUS          PORTS
> shopping-backend-1   shopping-backend   "uvicorn main:app --…"   backend   2 minutes ago    Up 2 minutes    8000/tcp
> shopping-backend-2   shopping-backend   "uvicorn main:app --…"   backend   2 minutes ago    Up 2 minutes    8000/tcp
> shopping-backend-3   shopping-backend   "uvicorn main:app --…"   backend   10 seconds ago   Up 9 seconds    8000/tcp
> ```

```bash
docker network inspect shopping_default --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

`shopping-backend-3`, with an address of its own. Compare with section 3.

## 6. Let instances crash

Crash one backend with `/kill` from tutorial 02. The proxy sends the request to whichever instance is next:

```bash
curl localhost:8000/kill
```

> **Output**
> ```text
> Bad Gateway
> ```

The instance died before it could answer, so the proxy reports an error for this one request. Watch the second terminal: two hostnames again, and no errors. Traefik noticed that the container stopped and took it out of the rotation. Look:

```bash
docker compose -f compose-lb.yaml ps -a backend
```

> **Output**
> ```text
> NAME                 IMAGE              COMMAND                  SERVICE   CREATED          STATUS                     PORTS
> shopping-backend-1   shopping-backend   "uvicorn main:app --…"   backend   3 minutes ago    Up 3 minutes               8000/tcp
> shopping-backend-2   shopping-backend   "uvicorn main:app --…"   backend   3 minutes ago    Exited (1) 5 seconds ago
> shopping-backend-3   shopping-backend   "uvicorn main:app --…"   backend   1 minute ago     Up 1 minute                8000/tcp
> ```

`-a` shows the stopped one, too: `Exited (1)` – and it stays that way. Nobody brings it back. Crash the next one:

```bash
curl localhost:8000/kill
```

The second terminal shows only one hostname now. The application still works – with a third of its capacity. And the last one:

```bash
curl localhost:8000/kill
```

> **Output**
> ```text
> Bad Gateway
> ```

The second terminal now shows:

> **Output**
> ```text
> 404 page not found
> 404 page not found
> ```

No backend left – Traefik has nowhere to send the request. Reload the page in the browser: the frontend shows an error, too. Look:

```bash
docker compose -f compose-lb.yaml ps -a backend
```

All three `Exited (1)`. Three instances made the application survive two crashes – but every crash permanently costs one instance. Stop everything:

```bash
docker compose -f compose-lb.yaml down
```

## 7. Restart on failure

Docker can restart a container whose process fails – you saw `--restart on-failure` with `docker run` in tutorial 02, section 11.1. Open the Compose file:

```bash
code compose-lb.yaml
```

Add one line to the `backend` service, right below `replicas: 2` (same indentation as `deploy:`), and save:

```yaml
  backend:
    build: ./backend-fastapi
    deploy:
      replicas: 2
    restart: on-failure
    labels:
      ...
```

Start again with three backends:

```bash
docker compose -f compose-lb.yaml up -d --scale backend=3
```

In the second terminal, the loop shows three hostnames again. Now play the same scenario. Crash one:

```bash
curl localhost:8000/kill
```

Watch the loop: for a moment two hostnames – then the third one is back, **with the same hostname** as before. Look:

```bash
docker compose -f compose-lb.yaml ps backend
```

> **Output**
> ```text
> NAME                 IMAGE              COMMAND                  SERVICE   CREATED          STATUS         PORTS
> shopping-backend-1   shopping-backend   "uvicorn main:app --…"   backend   30 seconds ago   Up 29 seconds  8000/tcp
> shopping-backend-2   shopping-backend   "uvicorn main:app --…"   backend   30 seconds ago   Up 29 seconds  8000/tcp
> shopping-backend-3   shopping-backend   "uvicorn main:app --…"   backend   30 seconds ago   Up 2 seconds   8000/tcp
> ```

Compare CREATED and STATUS: all three were created at the same time, but one has been up for only a few seconds. Docker restarted the **same container** – same ID, same hostname, a new process. Count the restarts per container (`ps -q` prints only the IDs):

```bash
docker inspect --format '{{.Name}} {{.RestartCount}}' $(docker compose -f compose-lb.yaml ps -q backend)
```

> **Output**
> ```text
> /shopping-backend-1 0
> /shopping-backend-2 0
> /shopping-backend-3 1
> ```

Now the scenario that ended with `404` in section 6 – three crashes in a row:

```bash
curl localhost:8000/kill
```

```bash
curl localhost:8000/kill
```

```bash
curl localhost:8000/kill
```

Watch the loop: maybe a short gap, then all three hostnames are back. Look again:

```bash
docker compose -f compose-lb.yaml ps backend
```

```bash
docker inspect --format '{{.Name}} {{.RestartCount}}' $(docker compose -f compose-lb.yaml ps -q backend)
```

> **Output**
> ```text
> /shopping-backend-1 2
> /shopping-backend-2 1
> /shopping-backend-3 1
> ```

Every crash was repaired – no instance was lost. Several instances behind a load balancer plus automatic restarts: the application now survives failures of single parts. That is a first piece of **resilience** – and exactly what Kubernetes does on a larger scale.

## 8. Where is the shopping list?

The instances survive. What about the data? Add an item through the proxy:

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
> []
> []
> []
> [{"name":"apples","amount":3}]
> []
> ```

Sometimes the apples are there, mostly not. Each backend instance keeps its own list in memory – the POST went to one of them, the GETs go to all of them. Try the same in the browser.

Now crash one instance:

```bash
curl localhost:8000/kill
```

```bash
for i in 1 2 3 4 5 6; do curl -s localhost:8000/shopping-list; echo; done
```

If the crash hit the instance with the apples, they are gone everywhere – even though the instance came back: a restart brings back the process, not its memory. (If you still see them, kill again.)

Scaling and restarting only work for instances that share no state. As soon as the instances have to share the shopping list, they have to agree on it – and the question is what happens when they cannot reach each other. That is the **CAP theorem**, and keeping the data outside the instances is the topic of [08 – State](08-state.md).

Stop the loop in the second terminal with **Ctrl+C**.

## 9. Clean up

```bash
docker compose -f compose-lb.yaml down
```

```bash
docker compose -f compose-lb.yaml ps
```

Empty – all five containers and the network are gone. Undo your change to the Compose file, so the tutorial starts the same way next time:

```bash
git restore compose-lb.yaml
```

```bash
cd ..
```

## 10. Overview

| Command | What it does |
|---|---|
| `docker compose -f compose-lb.yaml up -d` | starts proxy, backends and frontend |
| `docker compose -f compose-lb.yaml up -d --scale backend=3` | changes the number of backend instances while running |
| `docker compose -f compose-lb.yaml ps -a backend` | lists the containers of one service, stopped ones too |
| `while true; do curl -s localhost:8000/hello; echo; sleep 1; done` | calls the backends through the proxy once per second |
| `curl localhost:8000/kill` | crashes one backend instance |
| `restart: on-failure` | Docker restarts a crashed container – same container, new process |
| `docker inspect --format '{{.Name}} {{.RestartCount}}' <ids>` | how often each container was restarted |

Next: [08 – State](08-state.md)
