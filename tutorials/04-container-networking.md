# Container Networking – Connecting Frontend and Backend

## 1. About

The shopping list in [`code/`](../code/) has two parts: a REST **backend** (FastAPI) and a web **frontend** (Flask) that calls the backend. In this walkthrough you first run the frontend as a plain process, then both in containers – and find out why they cannot talk to each other at first, how a Docker network changes that, and why the backend does not need a published port at the end. A third container with network tools helps you look around.

At the end you have two connected containers and the shopping list in your browser. [06 – Docker Compose](06-docker-compose.md) builds exactly this setup again, with one file.

Take your time: after almost every step you look again – `docker ps`, `docker network inspect`, `docker container inspect` – and compare with what you saw before. That is how you see what each command changed.

Every code block contains **exactly one command**. Some commands run *inside* a container – this is marked in the text. IDs and addresses in the outputs are examples; yours will differ.

### 1.1 Prerequisites

- [02 – A REST API in a Container](02-rest-api-in-a-container.md) and [03 – Looking Inside Containers](03-looking-inside-containers.md)
- A GitHub Codespace on this repository. Run all commands from the **repository root**, where the `code/` folder is.

> **On a Mac:** port 5000 is often taken by the AirPlay Receiver. If `-p 5000:5000` fails with "address already in use", use `-p 5001:5000` and `localhost:5001` instead – and `PORT=5001 python app.py` in section 3.

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

> **Output**
> ```text
> IMAGE                      ID             DISK USAGE   CONTENT SIZE   EXTRA
> shopping-backend:latest    05a800c80efc        169MB             0B
> shopping-frontend:latest   684567b5e047        163MB             0B
> ```

## 3. The frontend as a local process

Before any container talks to another one, start with something you know from tutorial 02: one container, one plain process.

Start the backend in a container and publish its port:

```bash
docker run -d --name backend -p 8000:8000 shopping-backend
```

```bash
docker ps
```

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"08d4b6c5f70c"}
> ```

The frontend runs as a normal Python process. Open a **second terminal** and change into its folder:

```bash
cd code/frontend-flask
```

```bash
python3 -m venv .venv
```

```bash
source .venv/bin/activate
```

```bash
pip install -r requirements.txt
```

```bash
python app.py
```

> **Output**
> ```text
>  * Serving Flask app 'app'
>  * Running on all addresses (0.0.0.0)
>  * Running on http://127.0.0.1:5000
> ...
> ```

The frontend now waits for requests on port 5000 and blocks this terminal. Where does it look for the backend? Without configuration, at `http://127.0.0.1:8000` – the default in `app.py`. Back in the **first terminal**, ask the frontend which backend answered:

```bash
curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"
```

> **Output**
> ```text
> Server: <strong>08d4b6c5f70c
> ```

The hostname of the backend container. The frontend process reached it through the published port 8000 – exactly like your `curl`. Open port 5000 in the **Ports** tab, too: the shopping list, empty.

Add an item – not through the frontend, but directly at the backend:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "kiwis", "amount": 30}'
```

Now ask the frontend for its page and pick out the items:

```bash
curl -s localhost:5000 | grep -o 'item-name">[^<]*'
```

> **Output**
> ```text
> item-name">kiwis
> ```

Reload the browser, too: the kiwis are there. The frontend has no data of its own – it reads and changes what is in the backend.

In the **second terminal**, stop the frontend with **Ctrl+C**. In the first terminal:

```bash
curl localhost:5000
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 5000 after 0 ms: Couldn't connect to server
> ```

No frontend. The data is still there:

```bash
curl localhost:8000/shopping-list
```

> **Output**
> ```text
> [{"name":"kiwis","amount":30}]
> ```

Now tell the frontend a wrong address. In the **second terminal**:

```bash
BACKEND_URL=http://127.0.0.1:8001 python app.py
```

In the first terminal:

```bash
curl -s localhost:5000 | grep -o "Could not reach backend at [^:]*:[^:]*:[0-9]*"
```

> **Output**
> ```text
> Could not reach backend at http://127.0.0.1:8001
> ```

The frontend runs, but nothing listens on port 8001. `BACKEND_URL` is how you tell the frontend where the backend is – remember it for the containers. In the **second terminal**, stop the frontend with **Ctrl+C**, leave the virtual environment and go back to the repository root:

```bash
deactivate
```

```bash
cd ../..
```

## 4. The frontend in a container

Now the frontend goes into a container, too. The backend keeps running. Start the frontend with the address that just worked – `127.0.0.1:8000`:

```bash
docker run -d --name frontend -p 5000:5000 -e BACKEND_URL=http://127.0.0.1:8000 shopping-frontend
```

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED          STATUS          PORTS                                         NAMES
> 530873341cad   shopping-frontend   "gunicorn --bind 0.0…"   5 seconds ago    Up 4 seconds    0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp   frontend
> 08d4b6c5f70c   shopping-backend    "uvicorn main:app --…"   3 minutes ago    Up 3 minutes    0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   backend
> ```

Both are up. Reload the page in the browser – it shows an error. On the command line:

```bash
curl -s localhost:5000 | grep -o "Could not reach backend at [^:]*:[^:]*:[0-9]*"
```

> **Output**
> ```text
> Could not reach backend at http://127.0.0.1:8000
> ```

The same address that worked a minute ago. But inside a container, `127.0.0.1` is the container itself – the frontend asks *itself* for a backend on port 8000, and there is none. Remove it:

```bash
docker rm -f frontend
```

Try the name of the backend container instead:

```bash
docker run -d --name frontend -p 5000:5000 -e BACKEND_URL=http://backend:8000 shopping-frontend
```

```bash
curl -s localhost:5000 | grep -o "Failed to resolve[^)]*)"
```

> **Output**
> ```text
> Failed to resolve &#39;backend&#39; ([Errno -2] Name or service not known)
> ```

A different error: the frontend cannot find a host called `backend`. Both containers are running, both are reachable from your machine – but not from each other. Let's look from the inside.

## 5. Inside the backend

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
> {"message":"Good Morning!","hostname":"08d4b6c5f70c"}
> ```

Inside the container, `localhost` is the container itself – here that is what you want: the app answers on port 8000 without any port mapping. Leave the container:

```bash
exit
```

## 6. Inside the frontend

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
> d3b9904f2923
> ```

The container ID, as you know from tutorial 02. Which names does this container know?

```bash
cat /etc/hosts
```

> **Output**
> ```text
> 127.0.0.1	localhost
> ...
> 172.17.0.3	d3b9904f2923
> ```

`localhost` and itself – nothing else. Can it resolve the name `backend`?

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

## 7. Which network are they in?

Docker has a few networks from the start:

```bash
docker network ls
```

> **Output**
> ```text
> NETWORK ID     NAME      DRIVER    SCOPE
> 6b1b0ea7ed68   bridge    bridge    local
> a7b763ab5af1   host      host      local
> 6ac666307b88   none      null      local
> ```

Every container without `--network` lands in `bridge`, the default network. Who is in there?

```bash
docker network inspect bridge --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> backend 172.17.0.2/16
> frontend 172.17.0.3/16
> ```

Both – in the same network, with addresses. Now from the point of view of one container – which networks is it in?

```bash
docker container inspect frontend --format '{{range $name, $net := .NetworkSettings.Networks}}{{$name}} {{$net.IPAddress}}{{println}}{{end}}'
```

> **Output**
> ```text
> bridge 172.17.0.3
> ```

Only `bridge`. Compare the address with the last line of `/etc/hosts` in section 6. (Without `--format`, both `inspect` commands print everything Docker knows about the network or the container – try it.)

So they are in the same network, and still the name does not resolve. Time for proper tools.

### 7.1 A toolbox container

Both images are *slim* – no `ping`, no `nslookup`, no `curl`, no netcat. That is a good thing: an application image should contain the application, not a debugging kit. Instead of installing tools into the frontend or the backend, build a **third image** whose only job is to bring those tools along. It is in the repository:

```bash
cat code/toolbox/Dockerfile
```

```dockerfile
FROM alpine:3.22
RUN apk add --no-cache bash curl bind-tools iputils-ping netcat-openbsd
CMD ["bash"]
```

- `alpine:3.22` – a minimal Linux base, about 9 MB
- `apk add` – Alpine's package manager, like `apt-get install` on Debian or Ubuntu; `--no-cache` keeps the package index out of the image
- `bash` – a full shell; `curl` – HTTP calls; `bind-tools` – `nslookup` and `dig`; `iputils-ping` – `ping`; `netcat-openbsd` – `nc`
- `CMD ["bash"]` – a container from this image starts a shell

No application, no `COPY` – just a base image and a few packages. Build it:

```bash
docker build -t toolbox code/toolbox
```

```bash
docker images
```

> **Output**
> ```text
> IMAGE                      ID             DISK USAGE   CONTENT SIZE   EXTRA
> shopping-backend:latest    05a800c80efc        169MB             0B   U
> shopping-frontend:latest   684567b5e047        163MB             0B   U
> toolbox:latest             afc05f9117bf       27.8MB             0B
> ```

About 28 MB – the application images are six times bigger, mostly because of Python. (A ready-made debugging image like `nicolaka/netshoot` brings even more tools, but weighs over 600 MB.) Start a toolbox container:

```bash
docker run -it --rm --name toolbox toolbox
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

The same result as from the frontend. Now use the address of the backend from `docker network inspect bridge` above:

```bash
ping -c 2 172.17.0.2
```

> **Output**
> ```text
> PING 172.17.0.2 (172.17.0.2) 56(84) bytes of data.
> 64 bytes from 172.17.0.2: icmp_seq=1 ttl=64 time=0.085 ms
> 64 bytes from 172.17.0.2: icmp_seq=2 ttl=64 time=0.160 ms
> ...
> ```

```bash
curl 172.17.0.2:8000/hello
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"08d4b6c5f70c"}
> ```

By address it works. The containers *can* reach each other – the default network just has no name resolution. Addresses change whenever a container is recreated, so they are no way to configure an application. Leave the toolbox – thanks to `--rm` it is removed:

```bash
exit
```

## 8. A network for both

Create a network of your own:

```bash
docker network create shop-net
```

Look:

```bash
docker network ls
```

> **Output**
> ```text
> NETWORK ID     NAME       DRIVER    SCOPE
> 6b1b0ea7ed68   bridge     bridge    local
> a7b763ab5af1   host       host      local
> 6ac666307b88   none       null      local
> 65cdbaa5e64a   shop-net   bridge    local
> ```

A new network, with the same driver as the default one. Who is in there?

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

Nobody yet. Connect the backend – while it is running, no restart needed:

```bash
docker network connect shop-net backend
```

Look again:

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> backend 172.27.0.2/16
> ```

One member, with an address from a different range than in `bridge`. Connect the frontend:

```bash
docker network connect shop-net frontend
```

Look again:

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> backend 172.27.0.2/16
> frontend 172.27.0.3/16
> ```

And from the point of view of the frontend – the same command as in section 7:

```bash
docker container inspect frontend --format '{{range $name, $net := .NetworkSettings.Networks}}{{$name}} {{$net.IPAddress}}{{println}}{{end}}'
```

> **Output**
> ```text
> bridge 172.17.0.3
> shop-net 172.27.0.3
> ```

Compare with section 7: the frontend is now in two networks, with one address in each. Reload the page in your browser – the error is gone. On the command line, ask the frontend which backend answered:

```bash
curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"
```

> **Output**
> ```text
> Server: <strong>08d4b6c5f70c
> ```

The hostname of the backend container: the frontend reached it through `shop-net`. Ask the frontend the question from section 6 again:

```bash
docker exec frontend getent hosts backend
```

> **Output**
> ```text
> 172.27.0.2      backend
> ```

Now it knows the name – with the address from `shop-net`.

## 9. From one container to the other

Start the toolbox again – this time directly in `shop-net`:

```bash
docker run -it --rm --name toolbox --network shop-net toolbox
```

**Inside the toolbox**, look up the backend – the same command as in section 7.1:

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

Call the backend's REST API – by name this time:

```bash
curl backend:8000/hello
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"08d4b6c5f70c"}
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
> date: Thu, 19 Nov 2026 17:07:05 GMT
> server: uvicorn
> content-length: 53
> content-type: application/json
> Connection: close
>
> {"message":"Good Morning!","hostname":"08d4b6c5f70c"}
> ```

That is all an HTTP request is: a few lines of text over a TCP connection.

Leave the toolbox open, and in a **second terminal** look at the network:

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> backend 172.27.0.2/16
> toolbox 172.27.0.4/16
> frontend 172.27.0.3/16
> ```

The toolbox is the third member. Back in the first terminal, leave the toolbox:

```bash
exit
```

Look again in the second terminal:

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

Two members – `--rm` removed the toolbox, and with it its place in the network.

### 9.1 Between frontend and backend

The toolbox is only for looking around – frontend and backend talk to each other directly. Check it with the tools they have: from the frontend to the backend …

```bash
docker exec frontend python -c "import requests; print(requests.get('http://backend:8000/hello', timeout=3).text)"
```

> **Output**
> ```text
> {"message":"Good Morning!","hostname":"08d4b6c5f70c"}
> ```

Compare with section 6: the same command failed there. … and the other way round. Open a shell in the backend:

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

## 10. The backend does not need a published port

The backend is still published on port 8000 – but only the frontend needs to reach it, and it does so through `shop-net`. Remove the backend container:

```bash
docker rm -f backend
```

Look at the network:

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> frontend 172.27.0.3/16
> ```

And at the frontend:

```bash
curl -s localhost:5000 | grep -o "Failed to resolve[^)]*)"
```

> **Output**
> ```text
> Failed to resolve &#39;backend&#39; ([Errno -2] Name or service not known)
> ```

The error from section 4 is back: no container, no name. Start a new backend **without** `-p`, and put it into `shop-net` right away:

```bash
docker run -d --name backend --network shop-net shopping-backend
```

Look at the network again:

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}"
```

> **Output**
> ```text
> frontend 172.27.0.3/16
> backend 172.27.0.2/16
> ```

Back in the network. From outside, the backend is no longer reachable:

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 8000 after 0 ms: Couldn't connect to server
> ```

Compare the ports of the two containers:

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

> **Output**
> ```text
> NAMES      PORTS
> backend    8000/tcp
> frontend   0.0.0.0:5000->5000/tcp, [::]:5000->5000/tcp
> ```

But the frontend still reaches it:

```bash
curl -s localhost:5000/hello | grep -o "Server: <strong>[^<]*"
```

> **Output**
> ```text
> Server: <strong>d7480e0bc6f1
> ```

A different hostname than before – a new container with a new ID:

```bash
docker ps --filter name=backend
```

The frontend did not notice: it asks for the name `backend`, not for an ID or an address. Add an item through the frontend – this is the same form the web page uses:

```bash
curl -X POST localhost:5000/items -d "name=apples&amount=3" -o /dev/null -w "%{http_code}\n"
```

> **Output**
> ```text
> 302
> ```

`302` is a redirect back to the start page – the item was saved. Open the page in your browser, or check on the command line:

```bash
curl -s localhost:5000 | grep -o 'item-name">[^<]*'
```

> **Output**
> ```text
> item-name">apples
> ```

Only the apples – the kiwis from section 3 lived in the memory of the old backend container. More on that in [08 – State](08-state.md).

The request went from your machine to the frontend, and from the frontend through `shop-net` to the backend – which nobody outside can reach. This is the usual setup: only the part users talk to is published.

## 11. Overview

| From | To | Address | Works? |
|---|---|---|---|
| your machine | backend, published `-p 8000:8000` | `localhost:8000` | yes |
| your machine | backend, not published | `localhost:8000` | no |
| process on your machine | backend, published | `127.0.0.1:8000` | yes |
| inside a container | the container itself | `localhost` / `127.0.0.1` | yes – but never another container |
| container, default network | other container | by name | no |
| container, default network | other container | by IP address | yes – but addresses change |
| container, same own network | other container | by name | yes – Docker's DNS |
| container, same own network | other container | container port `backend:8000` | yes – no `-p` needed |

| Command | What it does |
|---|---|
| `docker network ls` | lists the networks |
| `docker network create <name>` | creates a network |
| `docker network connect <network> <container>` | connects a running container |
| `docker run --network <name> ...` | starts a container in a network |
| `docker network inspect <name>` | shows the network and its containers |
| `docker container inspect <container>` | shows everything about a container, including its networks |
| `getent hosts <name>` | resolves a hostname (inside a container) |
| `docker run -it --rm --network <name> toolbox` | a throwaway toolbox with `ping`, `nslookup`, `curl`, `nc` in that network |

## 12. Clean up

Keep the setup running if you want to continue with [06 – Docker Compose](06-docker-compose.md) right away – it starts by removing it. Otherwise:

```bash
docker rm -f frontend backend
```

```bash
docker network rm shop-net
```

```bash
docker network ls
```

`shop-net` is gone; `bridge`, `host` and `none` stay. Remove the virtual environment of section 3:

```bash
rm -r code/frontend-flask/.venv
```

Next: [05 – Cleaning Up](05-cleaning-up.md) · [06 – Docker Compose](06-docker-compose.md)
