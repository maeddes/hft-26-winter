# Docker Compose – Step by Step

## 1. About

So far you have started every container with a long `docker run` command. With several containers, a network and ports, that becomes tedious and error-prone. Docker Compose describes the whole setup in one file.

In this walkthrough you first build a small setup by hand, throw it away, and then let Compose build exactly the same thing. Compose does nothing magic: it runs the same steps you would run yourself.

Every code block contains **exactly one command**.

### 1.1 Prerequisites

- [02 – A REST API in a Container](02-rest-api-in-a-container.md) – the `shopping-api` folder
- [04 – Container Networking](04-container-networking.md) – networks and container names
- [05 – Cleaning Up](05-cleaning-up.md) – we start from an empty environment

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

Change into the folder from tutorial 02:

```bash
cd shopping-api
```

Build the image:

```bash
docker build -t shopping-api:v3 .
```

Create a network:

```bash
docker network create shop-net
```

Start the API in that network and publish its port:

```bash
docker run -d --name api --network shop-net -p 8000:8000 shopping-api:v3
```

Start a toolbox container in the same network. `sleep infinity` keeps it running, so you can use it as a client:

```bash
docker run -d --name toolbox --network shop-net alpine:3.22 sleep infinity
```

Test from your machine:

```bash
curl localhost:8000/hello
```

Test from the toolbox, by container name:

```bash
docker exec toolbox wget -qO- http://api:8000/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"3c2b1a9f8e7d"}
> ```

```bash
docker ps
```

Five commands for two containers. Now throw it all away again:

```bash
docker rm -f api toolbox
```

```bash
docker network rm shop-net
```

## 4. The same setup with Compose

Create the file `compose.yaml` in the `shopping-api` folder:

```bash
code compose.yaml
```

Paste this content and save:

```yaml
services:
  api:
    build: .
    ports:
      - "8000:8000"
  toolbox:
    image: alpine:3.22
    command: ["sleep", "infinity"]
```

Each entry under `services` becomes a container. Compare with the commands from section 3:

| `compose.yaml` | `docker` command |
|---|---|
| `build: .` | `docker build .` |
| `ports: - "8000:8000"` | `docker run -p 8000:8000` |
| `image: alpine:3.22` | `docker run alpine:3.22` |
| `command: ["sleep", "infinity"]` | `… alpine:3.22 sleep infinity` |
| *(nothing)* | `docker network create` – Compose creates a network automatically |

Start everything:

```bash
docker compose up -d
```

> **Output**
> ```text
>  Image shopping-api-api Built
>  Network shopping-api_default Created
>  Container shopping-api-toolbox-1 Started
>  Container shopping-api-api-1 Started
> ```

Compose built the image, created a network and started both containers – in one step. The names come from the folder name (`shopping-api`), the service name and a number.

```bash
docker compose ps
```

> **Output**
> ```text
> NAME                     IMAGE              SERVICE   STATUS         PORTS
> shopping-api-api-1       shopping-api-api   api       Up 5 seconds   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp
> shopping-api-toolbox-1   alpine:3.22        toolbox   Up 5 seconds
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
> NETWORK ID     NAME                   DRIVER    SCOPE
> ...
> 5e6f7a8b9c0d   shopping-api_default   bridge    local
> ```

Test from your machine:

```bash
curl localhost:8000/hello
```

Test from the toolbox. In a Compose network, the **service name** is the hostname:

```bash
docker compose exec toolbox wget -qO- http://api:8000/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"234f3fb7c863"}
> ```

Look at the logs of one service:

```bash
docker compose logs api
```

## 5. Throw it away

```bash
docker compose down
```

> **Output**
> ```text
>  Container shopping-api-toolbox-1 Removed
>  Container shopping-api-api-1 Removed
>  Network shopping-api_default Removed
> ```

Containers and network are gone – the same as `docker rm -f` and `docker network rm` in section 3. The image stays:

```bash
docker images
```

## 6. Change the code

Open `main.py` and change the message from `"Good morning!"` to `"Hello from Compose!"`. Save.

Start again and tell Compose to rebuild the image:

```bash
docker compose up -d --build
```

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> {"message":"Hello from Compose!","hostname":"8d7c6b5a4f3e"}
> ```

```bash
docker compose down
```

Change the message back to `"Good morning!"` if you like – the next tutorial does not depend on it.

## 7. Overview

| Command | What it does |
|---|---|
| `docker compose up -d` | builds missing images, creates the network, starts all services in the background |
| `docker compose up -d --build` | the same, but rebuilds the images first |
| `docker compose ps` | lists the containers of this Compose project |
| `docker compose logs <service>` | shows the logs of a service |
| `docker compose exec <service> <command>` | runs a command in a running service container |
| `docker compose down` | stops and removes containers and network |
| `docker compose -f <file> …` | uses a file other than `compose.yaml` |

Next: [07 – Scaling and State](07-scaling-and-state.md)
