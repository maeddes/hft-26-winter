# Container Networking – Connecting Frontend and Backend

## 1. About

The shopping list in [`code/`](../code/) has two parts: a REST **backend** (FastAPI) and a web **frontend** (Flask) that calls the backend. In this walkthrough you run both in containers – and find out why they cannot talk to each other at first, how a Docker network changes that, and why the backend does not need a published port at the end. A third container with network tools helps you look around.

At the end you have two connected containers and the shopping list in your browser. [06 – Docker Compose](06-docker-compose.md) builds exactly this setup again, with one file.

Every code block contains **exactly one command**. Some commands run *inside* a container – this is marked in the text.

### 1.1 Prerequisites

- [02 – A REST API in a Container](02-rest-api-in-a-container.md) and [03 – Looking Inside Containers](03-looking-inside-containers.md)
- A GitHub Codespace on this repository. Run all commands from the **repository root**, where the `code/` folder is.

> **On a Mac:** port 5000 is often taken by the AirPlay Receiver. If `-p 5000:5000` fails with "address already in use", use `-p 5001:5000` and `localhost:5001` instead.

## 2. Build the two images

Each service folder contains its own `Dockerfile`, so the folder is the build context:

```bash
docker build -t shopping-backend code/backend-fastapi
```

```bash
docker build -t shopping-frontend code/frontend-flask
```

```bash
docker images
```

## 3. Start them separately

Start the backend and publish its port:

```bash
docker run -d --name backend -p 8000:8000 shopping-backend
```

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"154ad27de4e1"}
> ```

Start the frontend. It needs to know where the backend is – the environment variable `BACKEND_URL` tells it:

```bash
docker run -d --name frontend -p 5000:5000 -e BACKEND_URL=http://backend:8000 shopping-frontend
```

Open port 5000 in the **Ports** tab of your codespace. The page loads – but shows an error. On the command line:

```bash
curl -s localhost:5000 | grep -o "Could not reach backend[^<]*"
```

> **Output**
> ```text
> Could not reach backend at http://backend:8000: HTTPConnectionPool(host=&#39;backend&#39;, port=8000): ... Failed to resolve &#39;backend&#39; ([Errno -2] Name or service not known)
> ```

Both containers are running, both are reachable from your machine – but the frontend cannot find a host called `backend`. Let's look from the inside.

## 4. Inside the backend

Open a shell in the backend container:

```bash
docker exec -it backend sh
```

**Inside the container**, try `curl`:

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> sh: 1: curl: not found
> ```

The image is based on `python:3.12-slim` – a *slim* image contains only what the app needs. Which tools are there?

```bash
for t in curl nc ping getent python; do command -v $t || echo "$t: not found"; done
```

> **Output**
> ```text
> curl: not found
> nc: not found
> ping: not found
> /usr/bin/getent
> /usr/local/bin/python
> ```

No `curl`, no netcat, no `ping`. But Python is there – use it as an HTTP client:

```bash
python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/hello').read().decode())"
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"154ad27de4e1"}
> ```

Inside the container, `localhost` is the container itself – the app answers on port 8000 without any port mapping. Leave the container:

```bash
exit
```

## 5. Inside the frontend

Open a shell in the frontend container:

```bash
docker exec -it frontend sh
```

**Inside the container**, check the hostname:

```bash
hostname
```

> **Output**
> ```text
> c248b04ebe93
> ```

The container ID, as you know from tutorial 02. Can this container resolve the name `backend`?

```bash
getent hosts backend
```

No output: the name is unknown. The frontend's own HTTP library says the same:

```bash
python -c "import requests; print(requests.get('http://backend:8000/hello', timeout=3).text)"
```

> **Output**
> ```text
> ...
> requests.exceptions.ConnectionError: ... Failed to resolve 'backend' ([Errno -2] Name or service not known)
> ```

Leave the container:

```bash
exit
```

### 5.1 A toolbox container

Both images are *slim* – no `ping`, no `nslookup`, no netcat. That is a good thing: an application image should contain the application, not a debugging kit. Instead of installing tools into the frontend, start a **third container** whose only job is to bring those tools along: [`nicolaka/netshoot`](https://github.com/nicolaka/netshoot), a popular image for network troubleshooting.

```bash
docker run -it --rm --name toolbox nicolaka/netshoot:v0.14
```

The prompt changes – you are inside the toolbox. It is on the default network, like the other two. **Inside the toolbox**, look up the backend:

```bash
nslookup backend
```

> **Output**
> ```text
> ** server can't find backend: NXDOMAIN
> ```

```bash
ping -c 2 backend
```

> **Output**
> ```text
> ping: backend: Name does not resolve
> ```

The same result as from the frontend: on Docker's **default network**, containers cannot find each other by name. Leave the toolbox – thanks to `--rm` it is removed:

```bash
exit
```

## 6. A network for both

Create a network:

```bash
docker network create shop-net
```

Connect both running containers to it – no restart needed:

```bash
docker network connect shop-net backend
```

```bash
docker network connect shop-net frontend
```

Who is in the network, with which address?

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> backend 172.27.0.2/16
> frontend 172.27.0.3/16
> ```

And from the point of view of one container – which networks is it in?

```bash
docker container inspect frontend --format '{{range $name, $net := .NetworkSettings.Networks}}{{$name}} {{$net.IPAddress}}{{println}}{{end}}'
```

> **Output**
> ```text
> bridge 172.17.0.3
> shop-net 172.27.0.3
> ```

The frontend is now in two networks: the default `bridge` and `shop-net`. (Without `--format`, both `inspect` commands print everything Docker knows about the network or the container – try it.)

Reload the page in your browser – the error is gone. On the command line, ask the frontend which backend answered:

```bash
curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"
```

> **Output**
> ```text
> Server: <strong>154ad27de4e1
> ```

The hostname of the backend container: the frontend reached it through `shop-net`.

## 7. From one container to the other

Start the toolbox again – this time directly in `shop-net`:

```bash
docker run -it --rm --name toolbox --network shop-net nicolaka/netshoot:v0.14
```

**Inside the toolbox**, look up the backend:

```bash
nslookup backend
```

> **Output**
> ```text
> Server:		127.0.0.11
> Address:	127.0.0.11#53
>
> Non-authoritative answer:
> Name:	backend
> Address: 172.27.0.2
> ```

In a network of your own, Docker runs a DNS server at `127.0.0.11`: container names become hostnames. The frontend is there, too:

```bash
nslookup frontend
```

```bash
ping -c 2 backend
```

> **Output**
> ```text
> PING backend (172.27.0.2) 56(84) bytes of data.
> 64 bytes from backend.shop-net (172.27.0.2): icmp_seq=1 ttl=64 time=0.434 ms
> 64 bytes from backend.shop-net (172.27.0.2): icmp_seq=2 ttl=64 time=0.130 ms
> ...
> ```

Call the backend's REST API:

```bash
curl backend:8000/hello
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"154ad27de4e1"}
> ```

Check only whether a port is open, with netcat – the backend on 8000, the frontend on 5000:

```bash
nc -zv backend 8000
```

> **Output**
> ```text
> Connection to backend (172.27.0.2) 8000 port [tcp/*] succeeded!
> ```

```bash
nc -zv frontend 5000
```

Or send an HTTP request by hand – netcat opens the connection, you write the request yourself:

```bash
printf "GET /hello HTTP/1.0\r\n\r\n" | nc -w 3 backend 8000
```

> **Output**
> ```text
> HTTP/1.1 200 OK
> date: Thu, 12 Nov 2026 21:01:07 GMT
> server: uvicorn
> content-length: 53
> content-type: application/json
> Connection: close
>
> {"message":"Good Morning!","hostname":"154ad27de4e1"}
> ```

That is all an HTTP request is: a few lines of text over a TCP connection.

Leave the toolbox open, and in a **second terminal** look at the network – the toolbox shows up as a third member:

```bash
docker network inspect shop-net --format "{{{{range .Containers}}}}{{{{.Name}}}} {{{{.IPv4Address}}}}{{{{println}}}}{{{{end}}}}"
```

> **Output**
> ```text
> backend 172.27.0.2/16
> frontend 172.27.0.3/16
> toolbox 172.27.0.4/16
> ```

Back in the first terminal, leave the toolbox:

```bash
exit
```

### 7.1 Between frontend and backend

The toolbox is only for looking around – frontend and backend talk to each other directly. Check it with the tools they have: from the frontend to the backend …

```bash
docker exec frontend python -c "import requests; print(requests.get('http://backend:8000/hello', timeout=3).text)"
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"154ad27de4e1"}
> ```

… and the other way round. Open a shell in the backend:

```bash
docker exec -it backend sh
```

**Inside the container**:

```bash
getent hosts frontend
```

> **Output**
> ```text
> 172.27.0.3      frontend
> ```

```bash
python -c "import urllib.request; print(urllib.request.urlopen('http://frontend:5000').status)"
```

> **Output**
> ```text
> 200
> ```

The backend reaches the frontend by name, too.

```bash
exit
```

## 8. The backend does not need a published port

The backend is still published on port 8000 – but only the frontend needs to reach it, and it does so through `shop-net`. Remove the backend container:

```bash
docker rm -f backend
```

Start a new one **without** `-p`, and put it into `shop-net` right away:

```bash
docker run -d --name backend --network shop-net shopping-backend
```

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 8000 after 0 ms: Couldn't connect to server
> ```

From outside, the backend is no longer reachable. Compare the ports of the two containers:

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

> **Output**
> ```text
> NAMES      PORTS
> backend    8000/tcp
> frontend   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
> ```

But the frontend still reaches it. Add an item through the frontend – this is the same form the web page uses:

```bash
curl -X POST localhost:5000/items -d "name=apples&amount=3" -o /dev/null -w "%{http_code}\n"
```

> **Output**
> ```text
> 302
> ```

`302` is a redirect back to the start page – the item was saved. Open the page in your browser, or check on the command line:

```bash
curl -s localhost:5000 | grep -o "apples"
```

> **Output**
> ```text
> apples
> ```

The request went from your machine to the frontend, and from the frontend through `shop-net` to the backend – which nobody outside can reach. This is the usual setup: only the part users talk to is published.

Notice that the shopping list was empty before you added the apples: the new backend container started with an empty memory. More on that in [08 – State](08-state.md).

## 9. Overview

| From | To | Address | Works? |
|---|---|---|---|
| your machine | backend, published `-p 8000:8000` | `localhost:8000` | yes |
| your machine | backend, not published | `localhost:8000` | no |
| inside a container | the container itself | `localhost:8000` | yes |
| container, default network | other container | by name | no |
| container, same own network | other container | by name | yes – Docker's DNS |
| container, same own network | other container | container port `backend:8000` | yes – no `-p` needed |

| Command | What it does |
|---|---|
| `docker network create <name>` | creates a network |
| `docker network connect <network> <container>` | connects a running container |
| `docker run --network <name> ...` | starts a container in a network |
| `docker network inspect <name>` | shows the network and its containers |
| `docker container inspect <container>` | shows everything about a container, including its networks |
| `getent hosts <name>` | resolves a hostname (inside a container) |
| `docker run -it --rm --network <name> nicolaka/netshoot:v0.14` | a throwaway toolbox with `ping`, `nslookup`, `curl`, `nc` in that network |

## 10. Clean up

Keep the setup running if you want to continue with [06 – Docker Compose](06-docker-compose.md) right away – it starts by removing it. Otherwise:

```bash
docker rm -f frontend backend
```

```bash
docker network rm shop-net
```

Next: [05 – Cleaning Up](05-cleaning-up.md) · [06 – Docker Compose](06-docker-compose.md)
