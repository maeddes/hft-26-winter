# State – Step by Step

> **Draft – not yet adapted.** This tutorial still uses the `shopping-api` folder from tutorial 02 and repeats the load balancer setup. It will be moved to the services in `code/` (frontend, proxy, backend) like tutorials 04, 06 and 07.

## 1. About

In this walkthrough the shopping-list API grows from one container to a small distributed system – one Compose file per stage:

1. **Load balancing:** a proxy distributes requests across several instances of the API
2. **The state problem:** each instance keeps its own list in memory
3. **Storage by configuration:** the same image keeps its data in memory or in a database – depending on one environment variable
4. **A database:** all instances share the data; instances can crash and scale – the database becomes the single point of failure
5. **A volume:** the data survives even when everything is thrown away

Every code block contains **exactly one command**. File contents are shown in separate blocks.

### 1.1 Prerequisites

- [06 – Docker Compose](06-docker-compose.md) – you work in the `shopping-api` folder with the in-memory API from tutorial 02
- A GitHub Codespace is recommended

## 2. A load balancer in front of two instances

Change into the folder:

```bash
cd shopping-api
```

Create the file `compose-lb.yaml`:

```bash
code compose-lb.yaml
```

Paste this content and save:

```yaml
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
  api:
    build: .
    deploy:
      replicas: 2
    labels:
      - traefik.enable=true
      - traefik.http.routers.api.rule=PathPrefix(`/`)
      - traefik.http.services.api.loadbalancer.server.port=8000
```

- `proxy` is [Traefik](https://traefik.io), a reverse proxy and load balancer from the CNCF landscape. It watches Docker through the Docker socket and finds the API containers by their labels – so it notices new instances on its own.
- Port **8000** on your machine now leads to the proxy, not to an API container. Port **8080** shows Traefik's dashboard.
- `api` has **no** `ports` any more: only the proxy can reach it, through the Compose network.
- `replicas: 2` starts two instances of the API.

Start it:

```bash
docker compose -f compose-lb.yaml up -d
```

```bash
docker compose -f compose-lb.yaml ps
```

> **Output**
> ```text
> NAME                   SERVICE   STATUS         PORTS
> shopping-api-api-1     api       Up 5 seconds   8000/tcp
> shopping-api-api-2     api       Up 5 seconds   8000/tcp
> shopping-api-proxy-1   proxy     Up 5 seconds   0.0.0.0:8000->80/tcp, [::]:8000->80/tcp, 0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
> ```

Call the API a few times in a loop (stop with **Ctrl+C**):

```bash
while true; do curl -s localhost:8000/hello; echo; sleep 1; done
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"dca1ced769d6"}
> {"message":"Good morning!","hostname":"4ce8edebf91c"}
> {"message":"Good morning!","hostname":"dca1ced769d6"}
> {"message":"Good morning!","hostname":"4ce8edebf91c"}
> ```

The hostname alternates: the proxy sends each request to the next instance (round robin). In a codespace, open port 8080 in the **Ports** tab to see the dashboard.

Scale up to three instances while everything is running:

```bash
docker compose -f compose-lb.yaml up -d --scale api=3
```

```bash
while true; do curl -s localhost:8000/hello; echo; sleep 1; done
```

Three different hostnames now – Traefik picked up the new instance without any configuration change.

## 3. The state problem

Add three apples – the proxy sends the request to *one* of the instances:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "apples", "amount": 3}'
```

Now read the list a few times (stop with **Ctrl+C**):

```bash
while true; do curl -s localhost:8000/shopping-list; echo; sleep 1; done
```

> **Output**
> ```text
> []
> [{"name":"apples","amount":3}]
> []
> []
> [{"name":"apples","amount":3}]
> ```

The apples exist only in the memory of the instance that received the `POST`. Every instance has its own list – the users see a different shopping list on every request.

It gets worse when an instance fails. Crash one of them with `/kill` from tutorial 02 – the proxy sends the request to whichever instance is next:

```bash
curl localhost:8000/kill
```

> **Output**
> ```text
> Bad Gateway
> ```

The instance died before it could answer, so the proxy reports an error. One container has exited:

```bash
docker compose -f compose-lb.yaml ps -a
```

> **Output**
> ```text
> NAME                   SERVICE   STATUS                     PORTS
> shopping-api-api-1     api       Exited (1) 5 seconds ago
> shopping-api-api-2     api       Up 3 minutes               8000/tcp
> shopping-api-api-3     api       Up 2 minutes               8000/tcp
> shopping-api-proxy-1   proxy     Up 3 minutes               ...
> ```

The other instances keep serving requests. Start the crashed one again:

```bash
docker compose -f compose-lb.yaml up -d
```

```bash
while true; do curl -s localhost:8000/shopping-list; echo; sleep 1; done
```

If the crashed instance was the one with the apples, they are gone for good – the new process started with an empty list. Otherwise crash the next one and try again.

Remove everything:

```bash
docker compose -f compose-lb.yaml down
```

## 4. Storage by configuration

Instances that should be replaceable must not keep their state in memory. The next version of the API keeps its data in memory **or** in a PostgreSQL database – and the configuration decides: if the environment variable `DATABASE_URL` is set, it uses the database. The code and the image stay the same. (Spring Boot does the same with *profiles*; the idea is the 12-factor principle "store config in the environment".)

Open `main.py` and replace its whole content with:

```python
import os
import socket

from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel, Field

app = FastAPI(title="Shopping List API")


class ShoppingItem(BaseModel):
    name: str = Field(min_length=1)
    amount: int = Field(ge=0)


class MemoryStore:
    def __init__(self) -> None:
        self.items: dict[str, ShoppingItem] = {}

    def all(self) -> list[ShoppingItem]:
        return list(self.items.values())

    def get(self, name: str) -> ShoppingItem | None:
        return self.items.get(name)

    def add(self, item: ShoppingItem) -> bool:
        if item.name in self.items:
            return False
        self.items[item.name] = item
        return True

    def update(self, item: ShoppingItem) -> bool:
        if item.name not in self.items:
            return False
        self.items[item.name] = item
        return True

    def delete(self, name: str) -> bool:
        return self.items.pop(name, None) is not None


class PostgresStore:
    def __init__(self, url: str) -> None:
        import psycopg

        self.connect = lambda: psycopg.connect(url, autocommit=True)
        with self.connect() as conn:
            conn.execute(
                "CREATE TABLE IF NOT EXISTS shopping_list (name TEXT PRIMARY KEY, amount INTEGER NOT NULL)"
            )

    def all(self) -> list[ShoppingItem]:
        with self.connect() as conn:
            rows = conn.execute("SELECT name, amount FROM shopping_list ORDER BY name").fetchall()
        return [ShoppingItem(name=name, amount=amount) for name, amount in rows]

    def get(self, name: str) -> ShoppingItem | None:
        with self.connect() as conn:
            row = conn.execute("SELECT name, amount FROM shopping_list WHERE name = %s", (name,)).fetchone()
        return ShoppingItem(name=row[0], amount=row[1]) if row else None

    def add(self, item: ShoppingItem) -> bool:
        with self.connect() as conn:
            row = conn.execute(
                "INSERT INTO shopping_list (name, amount) VALUES (%s, %s) ON CONFLICT DO NOTHING RETURNING name",
                (item.name, item.amount),
            ).fetchone()
        return row is not None

    def update(self, item: ShoppingItem) -> bool:
        with self.connect() as conn:
            row = conn.execute(
                "UPDATE shopping_list SET amount = %s WHERE name = %s RETURNING name",
                (item.amount, item.name),
            ).fetchone()
        return row is not None

    def delete(self, name: str) -> bool:
        with self.connect() as conn:
            row = conn.execute("DELETE FROM shopping_list WHERE name = %s RETURNING name", (name,)).fetchone()
        return row is not None


# The configuration decides where the data lives – the code stays the same.
DATABASE_URL = os.environ.get("DATABASE_URL")
store = PostgresStore(DATABASE_URL) if DATABASE_URL else MemoryStore()
STORAGE = "postgres" if DATABASE_URL else "memory"


@app.get("/hello")
def hello() -> dict[str, str]:
    return {"message": "Good morning!", "hostname": socket.gethostname(), "storage": STORAGE}


@app.get("/crash")
def crash() -> None:
    raise RuntimeError("Simulated application error")


@app.get("/kill")
def kill() -> None:
    os._exit(1)


@app.get("/shopping-list")
def list_items() -> list[ShoppingItem]:
    return store.all()


@app.post("/shopping-list", status_code=201)
def create_item(item: ShoppingItem) -> ShoppingItem:
    if not store.add(item):
        raise HTTPException(status_code=409, detail="Item already exists")
    return item


@app.get("/shopping-list/{name}")
def get_item(name: str) -> ShoppingItem:
    item = store.get(name)
    if item is None:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@app.put("/shopping-list/{name}")
def update_item(name: str, item: ShoppingItem) -> ShoppingItem:
    if item.name != name:
        raise HTTPException(status_code=422, detail="Item name must match the path")
    if not store.update(item):
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@app.delete("/shopping-list/{name}", status_code=204)
def delete_item(name: str) -> Response:
    if not store.delete(name):
        raise HTTPException(status_code=404, detail="Item not found")
    return Response(status_code=204)
```

What changed compared to tutorial 02:

- `MemoryStore` and `PostgresStore` offer the same operations; the endpoints only talk to `store`.
- `/hello` also reports which storage is active.
- `/crash` and `/kill` are unchanged.

Open `requirements.txt`, paste this content as a third line – the PostgreSQL driver – and save:

```text
psycopg[binary]>=3.2,<4.0
```

Rebuild and start the setup from section 2 – with the new image, but **without** `DATABASE_URL`:

```bash
docker compose -f compose-lb.yaml up -d --build
```

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"3e274fd4bfbc","storage":"memory"}
> ```

Same behaviour as before – the new code still keeps everything in memory.

```bash
docker compose -f compose-lb.yaml down
```

## 5. Add a database

Create the file `compose-db.yaml`:

```bash
code compose-db.yaml
```

Paste this content and save:

```yaml
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
  api:
    build: .
    environment:
      DATABASE_URL: postgresql://shop:shop@db:5432/shop
    deploy:
      replicas: 2
    restart: on-failure
    depends_on:
      db:
        condition: service_healthy
    labels:
      - traefik.enable=true
      - traefik.http.routers.api.rule=PathPrefix(`/`)
      - traefik.http.services.api.loadbalancer.server.port=8000
  db:
    image: postgres:18
    environment:
      POSTGRES_USER: shop
      POSTGRES_PASSWORD: shop
      POSTGRES_DB: shop
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U shop -d shop"]
      interval: 2s
      retries: 15
```

New compared to `compose-lb.yaml`:

- `db` runs PostgreSQL 18. The service name `db` is also its hostname – see `DATABASE_URL`.
- `environment` sets `DATABASE_URL` for the API: the only difference that switches it to the database.
- `healthcheck` asks PostgreSQL whether it accepts connections; `depends_on … service_healthy` makes the API wait for that.
- `restart: on-failure` restarts an API container that crashed.

Start it:

```bash
docker compose -f compose-db.yaml up -d --build
```

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"2ba89c435486","storage":"postgres"}
> ```

Same image, different configuration. Add the apples:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "apples", "amount": 3}'
```

```bash
while true; do curl -s localhost:8000/shopping-list; echo; sleep 1; done
```

> **Output**
> ```text
> [{"name":"apples","amount":3}]
> [{"name":"apples","amount":3}]
> [{"name":"apples","amount":3}]
> ```

Every instance answers with the same list – they all read from the database.

### 5.1 Crash an instance

Let one instance crash. The request never gets an answer, so the proxy reports an error:

```bash
curl localhost:8000/kill
```

> **Output**
> ```text
> Bad Gateway
> ```

```bash
docker compose -f compose-db.yaml ps
```

> **Output**
> ```text
> NAME                   SERVICE   STATUS                   PORTS
> shopping-api-api-1     api       Up 3 seconds             8000/tcp
> shopping-api-api-2     api       Up 2 minutes             8000/tcp
> shopping-api-db-1      db        Up 2 minutes (healthy)   5432/tcp
> shopping-api-proxy-1   proxy     Up 2 minutes             ...
> ```

`restart: on-failure` brought the crashed instance back – it has been up for only a few seconds. And the data?

```bash
curl localhost:8000/shopping-list
```

Still there.

### 5.2 Scale up and down

```bash
docker compose -f compose-db.yaml up -d --scale api=4
```

```bash
while true; do curl -s localhost:8000/hello; echo; sleep 1; done
```

Four hostnames. Scale down to one:

```bash
docker compose -f compose-db.yaml up -d --scale api=1
```

```bash
curl localhost:8000/shopping-list
```

The apples don't care how many instances there are.

### 5.3 The single point of failure

Stop the database:

```bash
docker compose -f compose-db.yaml stop db
```

```bash
curl localhost:8000/shopping-list
```

> **Output**
> ```text
> Internal Server Error
> ```

However many API instances you run – without the database, none of them works. Start it again:

```bash
docker compose -f compose-db.yaml start db
```

```bash
curl localhost:8000/shopping-list
```

Back, with the apples.

### 5.4 Throw it all away

```bash
docker compose -f compose-db.yaml down
```

```bash
docker compose -f compose-db.yaml up -d
```

```bash
curl localhost:8000/shopping-list
```

> **Output**
> ```text
> []
> ```

The apples are gone. `down` removed the database container – and with it the place where PostgreSQL stored its files. (Strictly speaking, the PostgreSQL image stores them in an *anonymous volume*, which survives – but the new container gets a new, empty one. `docker volume ls` shows the orphaned volumes.)

Remove everything, including anonymous volumes (`-v`):

```bash
docker compose -f compose-db.yaml down -v
```

## 6. A volume for the data

Create the file `compose-volume.yaml`:

```bash
code compose-volume.yaml
```

Paste this content and save:

```yaml
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
  api:
    build: .
    environment:
      DATABASE_URL: postgresql://shop:shop@db:5432/shop
    deploy:
      replicas: 2
    restart: on-failure
    depends_on:
      db:
        condition: service_healthy
    labels:
      - traefik.enable=true
      - traefik.http.routers.api.rule=PathPrefix(`/`)
      - traefik.http.services.api.loadbalancer.server.port=8000
  db:
    image: postgres:18
    environment:
      POSTGRES_USER: shop
      POSTGRES_PASSWORD: shop
      POSTGRES_DB: shop
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U shop -d shop"]
      interval: 2s
      retries: 15
    volumes:
      - shop-data:/var/lib/postgresql

volumes:
  shop-data:
```

The only change: a **named volume** `shop-data`, mounted where PostgreSQL 18 keeps its data (`/var/lib/postgresql` – older versions and many guides use `/var/lib/postgresql/data`).

```bash
docker compose -f compose-volume.yaml up -d
```

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "apples", "amount": 3}'
```

Throw everything away:

```bash
docker compose -f compose-volume.yaml down
```

The containers and the network are gone – the volume is not:

```bash
docker volume ls
```

> **Output**
> ```text
> DRIVER    VOLUME NAME
> local     shopping-api_shop-data
> ```

Start everything again:

```bash
docker compose -f compose-volume.yaml up -d
```

```bash
curl localhost:8000/shopping-list
```

> **Output**
> ```text
> [{"name":"apples","amount":3}]
> ```

The apples survived. Containers are disposable – the data lives outside of them.

Only `-v` removes the volume, too:

```bash
docker compose -f compose-volume.yaml down -v
```

```bash
docker volume ls
```

## 7. Overview

| Stage | File | What you saw |
|---|---|---|
| Load balancing | `compose-lb.yaml` | requests alternate between instances; scaling works on the fly |
| State in memory | `compose-lb.yaml` | every instance has its own list; a crash loses data |
| Storage by configuration | `compose-lb.yaml` + new image | same image, `storage: memory` without `DATABASE_URL` |
| Database | `compose-db.yaml` | shared data; crashes and scaling don't matter; the database is the single point of failure |
| Volume | `compose-volume.yaml` | data survives `down` and `up`; only `down -v` removes it |

```bash
cd ..
```
