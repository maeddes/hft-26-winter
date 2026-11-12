# Docker Compose – Step by Step

## 1. About

At the end of [04 – Container Networking](04-container-networking.md) you had a working setup: a frontend and a backend in a network of their own, only the frontend published. It took a handful of `docker` commands – and you have to remember all of them every time.

Docker Compose describes the whole setup in one file. In this walkthrough you build the setup by hand once more, throw it away, and then let Compose build exactly the same thing. Compose does nothing magic: it runs the same steps you would run yourself.

Every code block contains **exactly one command**.

### 1.1 Prerequisites

- [04 – Container Networking](04-container-networking.md) – networks and container names
- [05 – Cleaning Up](05-cleaning-up.md) – we start from an empty environment
- A GitHub Codespace on this repository. Run the commands from the **repository root** unless the text says otherwise.

> **On a Mac:** port 5000 is often taken by the AirPlay Receiver – use port 5001 on your machine instead (`-p 5001:5000`, and `"5001:5000"` in the Compose file).

## 2. Start from an empty environment

Remove everything unused (see tutorial 05 – on your own machine, read the warning there first):

```bash
docker system prune -a --volumes
```

```bash
docker ps -a
```

```bash
docker images
```

Both lists are empty.

## 3. The setup by hand

This is the end result of tutorial 04, in one go. Build both images:

```bash
docker build -t shopping-backend code/backend-fastapi
```

```bash
docker build -t shopping-frontend code/frontend-flask
```

Create the network:

```bash
docker network create shop-net
```

Start the backend in the network – no published port:

```bash
docker run -d --name backend --network shop-net shopping-backend
```

Start the frontend in the network, tell it where the backend is, and publish its port:

```bash
docker run -d --name frontend --network shop-net -e BACKEND_URL=http://backend:8000 -p 5000:5000 shopping-frontend
```

Test it – the frontend asks the backend for its hostname:

```bash
curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"
```

> **Output**
> ```text
> Server: <strong>3c2b1a9f8e7d
> ```

```bash
docker ps
```

Five commands for two containers. Now throw it all away again:

```bash
docker rm -f frontend backend
```

```bash
docker network rm shop-net
```

## 4. The same setup with Compose

The Compose file is already in the repository. Change into the `code` folder:

```bash
cd code
```

Look at the file:

```bash
cat compose.yaml
```

```yaml
name: shopping

services:
  backend:
    build: ./backend-fastapi
  frontend:
    build: ./frontend-flask
    ports:
      - "5000:5000"
    environment:
      BACKEND_URL: http://backend:8000
    depends_on:
      - backend
```

Each entry under `services` becomes a container. Compare with the commands from section 3:

| `compose.yaml` | `docker` command |
|---|---|
| `name: shopping` | the prefix for all container and network names |
| `build: ./backend-fastapi` | `docker build code/backend-fastapi` |
| `ports: - "5000:5000"` | `docker run -p 5000:5000` |
| `environment: BACKEND_URL: ...` | `docker run -e BACKEND_URL=...` |
| `depends_on: - backend` | start the backend before the frontend |
| *(nothing)* | `docker network create` – Compose creates a network automatically |

The backend has no `ports` – exactly like in section 3.

Start everything:

```bash
docker compose up -d
```

> **Output**
> ```text
>  Network shopping_default Created
>  Container shopping-backend-1 Started
>  Container shopping-frontend-1 Started
> ```

Compose created a network and started both containers – in one step. It did not even build: Compose names images `<project>-<service>`, which is exactly `shopping-backend` and `shopping-frontend` from section 3. If those images are missing, Compose builds them first.

```bash
docker compose ps
```

> **Output**
> ```text
> NAME                  IMAGE               SERVICE    STATUS         PORTS
> shopping-backend-1    shopping-backend    backend    Up 4 seconds   8000/tcp
> shopping-frontend-1   shopping-frontend   frontend   Up 4 seconds   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
> ```

They are ordinary containers – `docker ps` shows them, too:

```bash
docker ps
```

And there is the network:

```bash
docker network ls
```

> **Output**
> ```text
> NETWORK ID     NAME               DRIVER    SCOPE
> ...
> 5e6f7a8b9c0d   shopping_default   bridge    local
> ```

Open port 5000 in the **Ports** tab – the shopping list. On the command line:

```bash
curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"
```

The backend is not reachable from outside:

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 8000 after 0 ms: Couldn't connect to server
> ```

Inside the Compose network, the **service name** is the hostname:

```bash
docker compose exec frontend getent hosts backend
```

> **Output**
> ```text
> 172.27.0.2      backend
> ```

Add an item through the frontend:

```bash
curl -X POST localhost:5000/items -d "name=apples&amount=3" -o /dev/null -w "%{{http_code}}\n"
```

```bash
docker compose logs backend
```

> **Output**
> ```text
> ...
> INFO:     172.27.0.3:51234 - "POST /shopping-list HTTP/1.1" 201 Created
> INFO:     172.27.0.3:51240 - "GET /shopping-list HTTP/1.1" 200 OK
> ```

The requests came from `172.27.0.3` – the frontend container.

### 4.1 The toolbox joins the Compose network

The Compose network is an ordinary Docker network. The toolbox from tutorial 04 can join it:

```bash
docker run -it --rm --network shopping_default nicolaka/netshoot:v0.14
```

**Inside the toolbox**:

```bash
nslookup backend
```

```bash
curl backend:8000/shopping-list
```

> **Output**
> ```text
> [{{"name":"apples","amount":3}}]
> ```

```bash
exit
```

## 5. Throw it away

```bash
docker compose down
```

> **Output**
> ```text
>  Container shopping-frontend-1 Removed
>  Container shopping-backend-1 Removed
>  Network shopping_default Removed
> ```

Containers and network are gone – the same as `docker rm -f` and `docker network rm` in section 3. The images stay:

```bash
docker images
```

After a code change, `docker compose up -d --build` rebuilds the images before starting.

Go back to the repository root:

```bash
cd ..
```

## 6. Overview

| Command | What it does |
|---|---|
| `docker compose up -d` | builds missing images, creates the network, starts all services in the background |
| `docker compose up -d --build` | the same, but rebuilds the images first |
| `docker compose ps` | lists the containers of this Compose project |
| `docker compose logs <service>` | shows the logs of a service |
| `docker compose exec <service> <command>` | runs a command in a running service container |
| `docker compose down` | stops and removes containers and network |
| `docker compose -f <file> …` | uses a file other than `compose.yaml` |

Next: [07 – Scaling](07-scaling.md)
