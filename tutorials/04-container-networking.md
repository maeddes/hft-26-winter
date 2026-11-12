# Container Networking – Who Can Reach Whom?

## 1. About

`localhost`, container names, IP addresses, published ports – which address works from where? In this walkthrough you call the same REST service from different places: from your machine, from inside the container, from a second container on the default network, and from containers on a network of your own.

Every code block contains **exactly one command**. Some commands run *inside* a container – this is marked in the text.

### 1.1 Prerequisites

- [02 – A REST API in a Container](02-rest-api-in-a-container.md) – you need the `shopping-api` folder from there
- [03 – Looking Inside Containers](03-looking-inside-containers.md) – `docker exec` and `docker run -it`
- A GitHub Codespace is recommended. Some results differ on macOS and Windows – this is marked where it matters.

## 2. Prepare the image

Change into the folder from tutorial 02:

```bash
cd shopping-api
```

Build the image (it was removed at the end of tutorial 02):

```bash
docker build -t shopping-api:v3 .
```

```bash
cd ..
```

## 3. From your machine

Start the API in the background – **without** publishing a port:

```bash
docker run -d --name api-a shopping-api:v3
```

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 8000 after 0 ms: Couldn't connect to server
> ```

As expected: the port is not published. But the container has an IP address of its own:

```bash
docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" api-a
```

> **Output**
> ```text
> 172.17.0.2
> ```

Call the API directly at that address (use the IP from *your* output):

```bash
curl 172.17.0.2:8000/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"4b9e2c1a7d3f"}
> ```

In a codespace (Linux) this works: your machine is the Docker host and can reach the container network directly. **On macOS and Windows it fails**, because the containers run inside Docker Desktop's Linux VM. Publishing a port with `-p` is the way that works everywhere.

## 4. From inside the container

Inside the container, the app runs on `localhost`. Try `curl` there:

```bash
docker exec api-a curl localhost:8000/hello
```

> **Output**
> ```text
> OCI runtime exec failed: exec failed: unable to start container process: exec: "curl": executable file not found in $PATH
> ```

The image is based on `python:3.12-slim` – a *slim* image ships only what the app needs. No `curl`, no `netcat`, no `ping`. Check:

```bash
docker exec api-a sh -c "command -v curl nc ping || echo 'none of them installed'"
```

> **Output**
> ```text
> none of them installed
> ```

But Python is there – so use Python as an HTTP client:

```bash
docker exec api-a python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/hello').read().decode())"
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"4b9e2c1a7d3f"}
> ```

Inside the container, `localhost` is the container itself – and there the app is reachable on port 8000 without any port mapping.

## 5. From a second container on the default network

For the next steps you need a client with network tools. Alpine ships `wget`, `nc` (netcat), `ping` and `nslookup`. Try to reach the API by its container name:

```bash
docker run --rm alpine:3.22 wget -qO- http://api-a:8000/hello
```

> **Output**
> ```text
> wget: bad address 'api-a'
> ```

The name is unknown. Try the IP address instead (use yours):

```bash
docker run --rm alpine:3.22 wget -qO- http://172.17.0.2:8000/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"4b9e2c1a7d3f"}
> ```

Works. Both containers are on Docker's **default network** (`bridge`). There, containers can reach each other by IP address – but not by name.

Check only whether the port is open, with netcat:

```bash
docker run --rm alpine:3.22 nc -zv 172.17.0.2 8000
```

> **Output**
> ```text
> 172.17.0.2 (172.17.0.2:8000) open
> ```

And what about `localhost`?

```bash
docker run --rm alpine:3.22 wget -qO- http://localhost:8000/hello
```

> **Output**
> ```text
> wget: can't connect to remote host: Connection refused
> ```

`localhost` in the Alpine container is the Alpine container itself – nothing listens on port 8000 there.

## 6. A network of your own

Create a network:

```bash
docker network create shop-net
```

```bash
docker network ls
```

> **Output**
> ```text
> NETWORK ID     NAME       DRIVER    SCOPE
> 1a2b3c4d5e6f   bridge     bridge    local
> 2b3c4d5e6f7a   host       host      local
> 3c4d5e6f7a8b   none       null      local
> 4d5e6f7a8b9c   shop-net   bridge    local
> ```

Start a second API container in that network:

```bash
docker run -d --name api-b --network shop-net shopping-api:v3
```

Call it by name from a client in the same network:

```bash
docker run --rm --network shop-net alpine:3.22 wget -qO- http://api-b:8000/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"9f8e7d6c5b4a"}
> ```

In a network of your own, Docker runs a DNS server: container names become hostnames. Look it up:

```bash
docker run --rm --network shop-net alpine:3.22 nslookup api-b
```

> **Output**
> ```text
> Server:         127.0.0.11
> Address:        127.0.0.11:53
>
> Non-authoritative answer:
> Name:   api-b
> Address: 172.18.0.2
> ```

`127.0.0.11` is Docker's built-in DNS server. `api-b` is in a different address range than `api-a` – it is a different network.

```bash
docker run --rm --network shop-net alpine:3.22 ping -c 2 api-b
```

> **Output**
> ```text
> PING api-b (172.18.0.2): 56 data bytes
> 64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.112 ms
> 64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.098 ms
> ```

## 7. Networks isolate

From `shop-net`, try to reach `api-a` on the default network:

```bash
docker run --rm --network shop-net alpine:3.22 wget -qO- -T 3 http://api-a:8000/hello
```

> **Output**
> ```text
> wget: bad address 'api-a'
> ```

Unknown here. And the other way round – from the default network to `api-b`'s IP address (use the IP from your `nslookup` output):

```bash
docker run --rm alpine:3.22 nc -zv -w 3 172.18.0.2 8000
```

> **Output**
> ```text
> nc: 172.18.0.2 (172.18.0.2:8000): Operation timed out
> ```

Containers in different networks cannot talk to each other. Connect `api-a` to `shop-net` as well:

```bash
docker network connect shop-net api-a
```

```bash
docker run --rm --network shop-net alpine:3.22 wget -qO- http://api-a:8000/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"4b9e2c1a7d3f"}
> ```

Now it works by name. `api-a` is in two networks at the same time. See who is in `shop-net`:

```bash
docker network inspect shop-net --format "{{range .Containers}}{{.Name}} {{.IPv4Address}} {{end}}"
```

> **Output**
> ```text
> api-b 172.18.0.2/16 api-a 172.18.0.3/16
> ```

## 8. Published port or container port?

Start a third API container in `shop-net` and publish it on port **8080**:

```bash
docker run -d --name api-c --network shop-net -p 8080:8000 shopping-api:v3
```

From your machine, use the **published** port:

```bash
curl localhost:8080/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"7c6b5a4d3e2f"}
> ```

From another container in the network, use the **container** port:

```bash
docker run --rm --network shop-net alpine:3.22 wget -qO- http://api-c:8000/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"7c6b5a4d3e2f"}
> ```

The published port does not exist inside the network:

```bash
docker run --rm --network shop-net alpine:3.22 wget -qO- -T 3 http://api-c:8080/hello
```

> **Output**
> ```text
> wget: can't connect to remote host (172.18.0.4): Connection refused
> ```

`-p 8080:8000` opens a door on your machine. Containers in the same network don't need that door – they talk to port 8000 directly.

## 9. A debugging session with netcat

Start an interactive client in `shop-net`:

```bash
docker run -it --rm --network shop-net alpine:3.22 sh
```

**Inside the container**, find out which address belongs to `api-b`:

```bash
nslookup api-b
```

Check whether port 8000 is open:

```bash
nc -zv api-b 8000
```

> **Output**
> ```text
> api-b (172.18.0.2:8000) open
> ```

Send an HTTP request by hand – netcat only opens the connection, you write the request yourself:

```bash
printf "GET /hello HTTP/1.0\r\n\r\n" | nc api-b 8000
```

> **Output**
> ```text
> HTTP/1.1 200 OK
> date: ...
> server: uvicorn
> content-length: 53
> content-type: application/json
>
> {"message":"Good morning!","hostname":"9f8e7d6c5b4a"}
> ```

That is all an HTTP request is: a few lines of text over a TCP connection. Leave the container:

```bash
exit
```

## 10. Overview

| From | To | Address | Works? |
|---|---|---|---|
| your machine | container, port not published | `localhost:8000` | no |
| your machine | container, port published `-p 8080:8000` | `localhost:8080` | yes |
| your machine | container IP | `172.17.0.2:8000` | Linux yes, macOS/Windows no |
| inside the container | the container itself | `localhost:8000` | yes |
| container, default network | other container | by name | no |
| container, default network | other container | by IP | yes |
| container, own network | other container | by name | yes |
| container, own network | other container, published port | `api-c:8080` | no – use `api-c:8000` |
| container | container in another network | name or IP | no – until both share a network |

## 11. Clean up

```bash
docker rm -f api-a api-b api-c
```

```bash
docker network rm shop-net
```

Next: [05 – Cleaning Up](05-cleaning-up.md) · [06 – Docker Compose](06-docker-compose.md)
