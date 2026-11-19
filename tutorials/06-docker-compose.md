# Docker Compose – Step by Step

## 1. About

At the end of [04 – Container Networking](04-container-networking.md) you had a working setup: a frontend and a backend in a network of their own, only the frontend published. It took a handful of `docker` commands – and you have to remember all of them every time.

Docker Compose describes the whole setup in one file. In this walkthrough you build the setup by hand once more, throw it away, and then let Compose build exactly the same thing. Compose does nothing magic: it runs the same steps you would run yourself. At the end you see the three ways a Compose file can get its images – build them, use existing ones, or both – and when each one applies.

After almost every step you look again – `docker ps`, `docker network ls`, `docker images` – and compare with what you saw before. That is how you see what Compose did for you.

Every code block contains **exactly one command**. IDs and addresses in the outputs are examples; yours will differ.

### 1.1 Prerequisites

- [04 – Container Networking](04-container-networking.md) – networks and container names
- A GitHub Codespace on this repository. Run the commands from the **repository root** unless the text says otherwise.

> **On a Mac:** port 5000 is often taken by the AirPlay Receiver – use port 5001 on your machine instead (`-p 5001:5000`, and `"5001:5000"` in the Compose files).

## 2. Start from an empty setup

If the setup from tutorial 04 is still running, remove it. Error messages about containers, networks or images that do not exist are fine:

```bash
docker rm -f frontend backend toolbox
```

```bash
docker network rm shop-net
```

```bash
docker rmi shopping-backend shopping-frontend
```

Look:

```bash
docker ps -a
```

```bash
docker images
```

No `frontend`, no `backend`, no `shopping-…` images.

## 3. The setup by hand

This is the end result of tutorial 04, in one go. Build both images:

```bash
docker build -t shopping-backend code/backend-fastapi
```

```bash
docker build -t shopping-frontend code/frontend-flask
```

```bash
docker images
```

> **Output**
> ```text
> IMAGE                      ID             DISK USAGE   CONTENT SIZE   EXTRA
> shopping-backend:latest    05a800c80efc        169MB             0B
> shopping-frontend:latest   684567b5e047        163MB             0B
> ```

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

Look at what you built:

```bash
docker ps
```

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> backend 172.27.0.2/16
> frontend 172.27.0.3/16
> ```

Five commands for two containers – plus two builds. Now throw it all away again:

```bash
docker rm -f frontend backend
```

```bash
docker network rm shop-net
```

```bash
docker ps -a
```

Gone. The images stay – keep them, Compose will need them in a moment.

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

Each entry under `services` describes how to run a container. Compare with the commands from section 3:

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

Compose created a network and started both containers – in one step. It did not even build: with only `build:` in the file, Compose names the images `<project>-<service>` – exactly `shopping-backend` and `shopping-frontend` from section 3. They exist, so there is nothing to build. (Section 6 looks at this more closely.)

Look:

```bash
docker compose ps
```

> **Output**
> ```text
> NAME                  IMAGE               COMMAND                  SERVICE    CREATED         STATUS         PORTS
> shopping-backend-1    shopping-backend    "uvicorn main:app --…"   backend    5 seconds ago   Up 4 seconds   8000/tcp
> shopping-frontend-1   shopping-frontend   "gunicorn --bind 0.0…"   frontend   5 seconds ago   Up 4 seconds   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
> ```

They are ordinary containers – `docker ps` shows them, too:

```bash
docker ps
```

Compare the names: `shopping-backend-1` – project, service, number. The number is there because a service can run as several containers; [07 – Scaling](07-scaling.md) uses that.

And there is the network:

```bash
docker network ls
```

> **Output**
> ```text
> NETWORK ID     NAME               DRIVER    SCOPE
> ...
> 963b80e75b74   shopping_default   bridge    local
> ```

Who is in it? The same command as in section 3:

```bash
docker network inspect shopping_default --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> shopping-backend-1 172.27.0.2/16
> shopping-frontend-1 172.27.0.3/16
> ```

The same picture as `shop-net` – only Compose made it. Open port 5000 in the **Ports** tab – the shopping list. On the command line:

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
curl -X POST localhost:5000/items -d "name=apples&amount=3" -o /dev/null -w "%{http_code}\n"
```

```bash
docker compose logs backend
```

> **Output**
> ```text
> ...
> backend-1  | INFO:     172.27.0.3:54352 - "GET /shopping-list HTTP/1.1" 200 OK
> backend-1  | INFO:     172.27.0.3:54364 - "POST /shopping-list HTTP/1.1" 201 Created
> ```

The requests came from `172.27.0.3` – the frontend container.

Run `up` once more, while everything is running:

```bash
docker compose up -d
```

> **Output**
> ```text
>  Container shopping-frontend-1 Running
>  Container shopping-backend-1 Running
> ```

Nothing happens. Compose compares the file with what is running, and only changes what differs. `docker run` would have created new containers – or failed because the names are taken.

### 4.1 The toolbox joins the Compose network

The Compose network is an ordinary Docker network. The toolbox from tutorial 04 can join it. Build it (you are in the `code` folder):

```bash
docker build -t toolbox toolbox
```

```bash
docker run -it --rm --network shopping_default toolbox
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
> [{"name":"apples","amount":3}]
> ```

In a **second terminal**, look at the network:

```bash
docker network inspect shopping_default --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> shopping-backend-1 172.27.0.2/16
> toolbox 172.27.0.4/16
> shopping-frontend-1 172.27.0.3/16
> ```

Three members – one of them not started by Compose. Back in the first terminal, leave the toolbox:

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

Look:

```bash
docker ps -a
```

```bash
docker network ls
```

Containers and network are gone – the same as `docker rm -f` and `docker network rm` in section 3. The images stay:

```bash
docker images
```

Start again:

```bash
docker compose up -d
```

Network and containers are back – and again nothing was built: the images are still there. After a code change, you want a new build. `--build` builds first, then starts:

```bash
docker compose up -d --build
```

> **Output**
> ```text
>  Image shopping-backend Building
>  Image shopping-frontend Building
>  Image shopping-backend Built
>  Image shopping-frontend Built
>  Container shopping-backend-1 Recreated
>  Container shopping-frontend-1 Recreated
> ```

*Recreated*: the image changed, so Compose replaced the containers. Throw it away again:

```bash
docker compose down
```

## 6. Build or image?

So far, `compose.yaml` has only `build:` – Compose needs the source code and a Dockerfile for every service. That is handy while you develop, but the file only works where the source code is. A Compose file can also just name an image, or do both. Look at your images first:

```bash
docker images
```

> **Output**
> ```text
> IMAGE                      ID             DISK USAGE   CONTENT SIZE   EXTRA
> shopping-backend:latest    1e498227ef1d        169MB             0B
> shopping-frontend:latest   4b70d889d8e9        163MB             0B
> toolbox:latest             afc05f9117bf       27.8MB             0B
> ```

### 6.1 Only `image:`

```bash
cat compose-image.yaml
```

```yaml
name: shopping

services:
  backend:
    image: shopping-backend:v1
  frontend:
    image: shopping-frontend:v1
    ports:
      - "5000:5000"
    environment:
      BACKEND_URL: http://backend:8000
    depends_on:
      - backend
```

No `build:` – no source code, no Dockerfile. Each service names an image with a tag. `-f` picks a file other than `compose.yaml`:

```bash
docker compose -f compose-image.yaml up -d
```

> **Output**
> ```text
>  Image shopping-backend:v1 Pulling
>  Image shopping-frontend:v1 Pulling
>  Image shopping-backend:v1 Error pull access denied for shopping-backend, repository does not exist or may require 'docker login'
> ...
> ```

There is no `shopping-backend:v1` on your machine, so Compose tries to **pull** it – like `docker run` does. On Docker Hub there is no such image either. With only `image:`, Compose never builds: the image must exist, locally or in a registry.

Give your existing images the tag `v1` (tutorial 01, section 7):

```bash
docker tag shopping-backend shopping-backend:v1
```

```bash
docker tag shopping-frontend shopping-frontend:v1
```

Look:

```bash
docker images
```

> **Output**
> ```text
> IMAGE                      ID             DISK USAGE   CONTENT SIZE   EXTRA
> shopping-backend:latest    1e498227ef1d        169MB             0B
> shopping-backend:v1        1e498227ef1d        169MB             0B
> shopping-frontend:latest   4b70d889d8e9        163MB             0B
> shopping-frontend:v1       4b70d889d8e9        163MB             0B
> ...
> ```

Same IDs, new names. Try again:

```bash
docker compose -f compose-image.yaml up -d
```

```bash
docker compose -f compose-image.yaml ps
```

> **Output**
> ```text
> NAME                  IMAGE                  COMMAND                  SERVICE    CREATED         STATUS         PORTS
> shopping-backend-1    shopping-backend:v1    "uvicorn main:app --…"   backend    5 seconds ago   Up 4 seconds   8000/tcp
> shopping-frontend-1   shopping-frontend:v1   "gunicorn --bind 0.0…"   frontend   5 seconds ago   Up 4 seconds   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
> ```

Compare the IMAGE column with section 4: an explicit tag now. Can Compose build here?

```bash
docker compose -f compose-image.yaml build
```

> **Output**
> ```text
> level=warning msg="No services to build"
> ```

No – there is nothing to build from. This is the portable variant: copy only this file to another machine, and it runs there – as long as the images are in a registry that machine can pull from. With a Docker ID, you would name them `<your-docker-id>/shopping-backend:v1` and push them first (tutorial 01, section 10). The `traefik:v3.6` proxy in [07 – Scaling](07-scaling.md) is exactly this case: an image someone else built and published.

```bash
docker compose -f compose-image.yaml down
```

### 6.2 `build:` and `image:` together

```bash
cat compose-build-image.yaml
```

```yaml
name: shopping

services:
  backend:
    build: ./backend-fastapi
    image: shopping-backend:v2
  frontend:
    build: ./frontend-flask
    image: shopping-frontend:v2
    ports:
      - "5000:5000"
    environment:
      BACKEND_URL: http://backend:8000
    depends_on:
      - backend
```

Both. `image:` is now the name for what `build:` produces. There is no `v2` yet:

```bash
docker compose -f compose-build-image.yaml up -d
```

> **Output**
> ```text
>  Image shopping-backend:v2 Pulling
>  Image shopping-backend:v2 pull access denied for shopping-backend, repository does not exist ...
>  Image shopping-backend:v2 Building
>  Image shopping-backend:v2 Built
> ...
>  Container shopping-backend-1 Started
>  Container shopping-frontend-1 Started
> ```

Read the order: first Compose tries to **pull** `v2`. Only when that fails, it **builds** – and tags the result as `v2`. Look:

```bash
docker images
```

> **Output**
> ```text
> IMAGE                      ID             DISK USAGE   CONTENT SIZE   EXTRA
> shopping-backend:latest    1e498227ef1d        169MB             0B   U
> shopping-backend:v1        1e498227ef1d        169MB             0B   U
> shopping-backend:v2        1e498227ef1d        169MB             0B   U
> ...
> ```

`v2` exists now. Run `up` again:

```bash
docker compose -f compose-build-image.yaml up -d
```

> **Output**
> ```text
>  Container shopping-backend-1 Running
>  Container shopping-frontend-1 Running
> ```

No pull, no build – the image is there. Only `--build` forces a new build (section 5). This combination is common in practice: developers and CI build with it, `docker compose push` uploads the images under exactly those names, and other machines pull them.

```bash
docker compose -f compose-build-image.yaml down
```

### 6.3 Which mechanism applies when

| In the Compose file | Image on your machine? | `docker compose up` |
|---|---|---|
| only `build:` | yes (`<project>-<service>`) | uses it – no build |
| only `build:` | no | builds it |
| only `image:` | yes | uses it |
| only `image:` | no | pulls it – error if no registry has it |
| `build:` and `image:` | yes | uses it |
| `build:` and `image:` | no | tries to pull; if that fails, builds and tags it with the `image:` name |
| `build:` (with or without `image:`) | any | `up --build` always builds first |

Rule of thumb: `build:` where the source code is (developing, CI), `image:` where it runs (a server, someone else's machine). Both together connect the two. If you need a different behavior, `pull_policy:` per service overrides it (`always`, `never`, `missing`, `build`).

Go back to the repository root:

```bash
cd ..
```

## 7. Clean up

Remove the images of this tutorial – all three tags of each, and the toolbox:

```bash
docker rmi shopping-backend shopping-backend:v1 shopping-backend:v2
```

```bash
docker rmi shopping-frontend shopping-frontend:v1 shopping-frontend:v2
```

```bash
docker rmi toolbox
```

```bash
docker images
```

Keep them instead if you continue with [07 – Scaling](07-scaling.md) right away.

## 8. Overview

| Command | What it does |
|---|---|
| `docker compose up -d` | builds or pulls missing images, creates the network, starts all services in the background |
| `docker compose up -d --build` | the same, but builds the images first |
| `docker compose ps` | lists the containers of this Compose project |
| `docker compose logs <service>` | shows the logs of a service |
| `docker compose exec <service> <command>` | runs a command in a running service container |
| `docker compose build` | only builds the images of services with `build:` |
| `docker compose down` | stops and removes containers and network – the images stay |
| `docker compose -f <file> …` | uses a file other than `compose.yaml` |

| Key | Meaning |
|---|---|
| `build: <folder>` | build the image from this folder (build context with a Dockerfile) |
| `image: <name>:<tag>` | use this image – or, together with `build:`, the name for the built image |
| `pull_policy:` | overrides when Compose pulls or builds |

Next: [07 – Scaling](07-scaling.md)
