# A REST API in a Container – Step by Step

## 1. About

In this walkthrough you write a small REST API in Python, run it as a normal process, put it into a container, and then extend it step by step:

1. a `/hello` endpoint that returns the hostname
2. the same app in a container – and why `curl` fails at first
3. two versions running side by side
4. a complete shopping-list API (create, read, update, delete)

Every code block with a command contains **exactly one command**. File contents are shown in separate blocks – create the file, paste the content, save.

After almost every step you look again – `docker ps`, `docker images`, `curl` – and compare with what you saw before. That is how the commands stick.

### 1.1 Prerequisites

- [01 – Docker Basics](01-docker-basics.md)
- A GitHub Codespace (recommended – Python, Docker and `curl` are preinstalled), or Python 3 and Docker on your own machine

You don't need to know Python. The code is short, and the steps are the same for any language.

## 2. A first endpoint

Create a working directory and change into it:

```bash
mkdir shopping-api
```

```bash
cd shopping-api
```

Create the file `requirements.txt`:

```bash
code requirements.txt
```

Paste this content and save – these are the two libraries the app needs:

```text
fastapi>=0.115,<1.0
uvicorn>=0.30,<1.0
```

Create the file `main.py`:

```bash
code main.py
```

Paste this content and save:

```python
import socket

from fastapi import FastAPI

app = FastAPI(title="Shopping List API")


@app.get("/hello")
def hello() -> dict[str, str]:
    return {"message": "Hello!", "hostname": socket.gethostname()}
```

The endpoint returns a greeting and the name of the machine it runs on.

## 3. Run it as a normal process

Create a virtual environment, so the libraries are installed for this project only:

```bash
python3 -m venv .venv
```

Activate it:

```bash
source .venv/bin/activate
```

Install the libraries:

```bash
pip install -r requirements.txt
```

Start the app:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

> **Output**
> ```text
> INFO:     Started server process [12345]
> INFO:     Waiting for application startup.
> INFO:     Application startup complete.
> INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
> ```

The app is now waiting for requests and blocks this terminal. Open a **second terminal** and call it:

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> {"message":"Hello!","hostname":"codespaces-6542bf"}
> ```

Compare the hostname with the name of your machine:

```bash
hostname
```

Same name: the app runs directly on your machine. Is it a container?

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
> ```

No – a plain process. Go back to the first terminal and stop the app with **Ctrl+C**. In the second terminal, call it again:

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 8000 after 0 ms: Couldn't connect to server
> ```

No process, no answer. In the first terminal, leave the virtual environment:

```bash
deactivate
```

## 4. Put it into a container

Create the file `Dockerfile`:

```bash
code Dockerfile
```

Paste this content and save:

```dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- `FROM` – a base image that already contains Python
- `WORKDIR` – the directory inside the image where the next steps happen
- `COPY` – copies files from the build context into the image
- `RUN` – runs a command **at build time**, here: installing the libraries
- `EXPOSE` – documents the port the app listens on. It does **not** publish it.
- `CMD` – the command a container runs **when it starts**

Build the image:

```bash
docker build -t shopping-api:v1 .
```

The first build takes a moment: Docker downloads the Python base image and installs the libraries.

```bash
docker images
```

> **Output**
> ```text
> IMAGE             ID             DISK USAGE   CONTENT SIZE   EXTRA
> shopping-api:v1   d9c5f4e257bb        169MB             0B
> ...
> ```

How was it built? `docker history` lists the layers, newest on top:

```bash
docker history shopping-api:v1
```

> **Output**
> ```text
> IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
> d9c5f4e257bb   1 minute ago     CMD ["uvicorn" "main:app" "--host" "0.0.0.0"…   0B        buildkit.dockerfile.v0
> <missing>      1 minute ago     EXPOSE [8000/tcp]                               0B        buildkit.dockerfile.v0
> <missing>      1 minute ago     COPY main.py . # buildkit                       204B      buildkit.dockerfile.v0
> <missing>      1 minute ago     RUN /bin/sh -c pip install --no-cache-dir -r…   23.9MB    buildkit.dockerfile.v0
> <missing>      1 minute ago     COPY requirements.txt . # buildkit              39B       buildkit.dockerfile.v0
> <missing>      1 minute ago     WORKDIR /app                                    0B        buildkit.dockerfile.v0
> <missing>      2 weeks ago      CMD ["python3"]                                 0B        buildkit.dockerfile.v0
> <missing>      2 weeks ago      RUN /bin/sh -c set -eux;  for src in idle3 p…   36B       buildkit.dockerfile.v0
> ...
> <missing>      2 weeks ago      # debian.sh --arch 'amd64' out/ 'trixie' '@1…   101MB     debuerreotype 0.17
> ```

Read it bottom-up: first the layers of `python:3.12-slim` (from 2 weeks ago, built by someone else), then your Dockerfile, line by line. Look at the `SIZE` column: `COPY` and `RUN` add files; `WORKDIR`, `EXPOSE` and `CMD` show `0B` – they only change the image's metadata.

## 5. Why `curl` fails at first

Start a container in the background:

```bash
docker run -d --name api-v1 shopping-api:v1
```

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS         PORTS      NAMES
> db6f5a3c1e2b   shopping-api:v1   "uvicorn main:app --…"   5 seconds ago   Up 4 seconds   8000/tcp   api-v1
> ```

The container runs and the app listens on port 8000. Call it:

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 8000 after 0 ms: Couldn't connect to server
> ```

The app listens on port 8000 **inside the container**. The container is isolated – nothing from outside reaches it. The `PORTS` column shows `8000/tcp` without an arrow: the port is exposed, but not published.

Remove the container:

```bash
docker rm -f api-v1
```

```bash
docker ps -a --filter name=api-v1
```

Gone. Start it again, this time publishing container port 8000 as port 8000 on your machine:

```bash
docker run -d --name api-v1 -p 8000:8000 shopping-api:v1
```

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> {"message":"Hello!","hostname":"db6f5a3c1e2b"}
> ```

Look at the hostname – it changed. Compare it with the container ID:

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS         PORTS                                         NAMES
> db6f5a3c1e2b   shopping-api:v1   "uvicorn main:app --…"   5 seconds ago   Up 4 seconds   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   api-v1
> ```

Compare the `PORTS` column with the one before: now there is an arrow from port 8000 of your machine to port 8000 of the container. And the hostname is the container ID: each container gets its own hostname, as if it were a machine of its own.

## 6. The code is part of the image

Rename the source file, as if it were gone:

```bash
mv main.py main.py.bak
```

```bash
ls
```

> **Output**
> ```text
> Dockerfile  main.py.bak  requirements.txt
> ```

Restart the container:

```bash
docker restart api-v1
```

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> {"message":"Hello!","hostname":"db6f5a3c1e2b"}
> ```

Still working. Look into the image – a command after the image name replaces `CMD` (tutorial 01):

```bash
docker run --rm shopping-api:v1 ls /app
```

> **Output**
> ```text
> main.py
> requirements.txt
> ```

`COPY` put the file into the image at build time. The image does not point to your directory. Rebuilding would fail now – try it:

```bash
docker build -t shopping-api:broken .
```

> **Output**
> ```text
> ERROR: failed to build: ... "/main.py": not found
> ```

Restore the file:

```bash
mv main.py.bak main.py
```

## 7. Two versions side by side

Open `main.py` and change the message from `"Hello!"` to `"Good morning!"`. Save.

Build a second version:

```bash
docker build -t shopping-api:v2 .
```

This build is fast: all steps up to `COPY main.py` come from the cache – only the last layers are rebuilt. Look:

```bash
docker images
```

> **Output**
> ```text
> IMAGE             ID             DISK USAGE   CONTENT SIZE   EXTRA
> shopping-api:v1   d9c5f4e257bb        169MB             0B   U
> shopping-api:v2   fbc5deec0503        169MB             0B
> ...
> ```

Two tags, two IDs: `v1` is still there and unchanged.

Start version 2 on port **8001** – but first, a typical mistake. Put the options *after* the image name:

```bash
docker run -d shopping-api:v2 --name api-v2 -p 8001:8000
```

> **Output**
> ```text
> fbac6d78dbd8...
> docker: Error response from daemon: failed to create task for container: ... exec: "--name": executable file not found in $PATH
> ```

Everything after the image name is the **command** – Docker tried to run a program called `--name`. Look:

```bash
docker ps -a --filter ancestor=shopping-api:v2
```

> **Output**
> ```text
> CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS    PORTS     NAMES
> fbac6d78dbd8   shopping-api:v2   "--name api-v2 -p 80…"   5 seconds ago   Created             funny_hamilton
> ```

The COMMAND column shows it: your options ended up as the command, and the container never started. Remove it:

```bash
docker rm $(docker ps -aq --filter ancestor=shopping-api:v2)
```

Now correctly – options before the image name. Inside the container the app still listens on 8000:

```bash
docker run -d --name api-v2 -p 8001:8000 shopping-api:v2
```

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS         PORTS                                         NAMES
> fd4698739905   shopping-api:v2   "uvicorn main:app --…"   5 seconds ago   Up 4 seconds   0.0.0.0:8001->8000/tcp, [::]:8001->8000/tcp   api-v2
> 22ac6b04d630   shopping-api:v1   "uvicorn main:app --…"   3 minutes ago   Up 2 minutes   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   api-v1
> ```

Call both versions:

```bash
curl localhost:8000/hello
```

> **Output**
> ```text
> {"message":"Hello!","hostname":"db6f5a3c1e2b"}
> ```

```bash
curl localhost:8001/hello
```

> **Output**
> ```text
> {"message":"Good morning!","hostname":"8c1d2e3f4a5b"}
> ```

Two containers, two versions, both listening on port 8000 inside – no conflict, because they are published on different ports. This is the basis for a blue/green update: start the new version next to the old one, test it, then switch.

## 8. Complete the API

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


shopping_list: dict[str, ShoppingItem] = {}


@app.get("/hello")
def hello() -> dict[str, str]:
    return {"message": "Good morning!", "hostname": socket.gethostname()}


@app.get("/crash")
def crash() -> None:
    raise RuntimeError("Simulated application error")


@app.get("/kill")
def kill() -> None:
    os._exit(1)


@app.get("/shopping-list")
def list_items() -> list[ShoppingItem]:
    return list(shopping_list.values())


@app.post("/shopping-list", status_code=201)
def create_item(item: ShoppingItem) -> ShoppingItem:
    if item.name in shopping_list:
        raise HTTPException(status_code=409, detail="Item already exists")
    shopping_list[item.name] = item
    return item


@app.get("/shopping-list/{name}")
def get_item(name: str) -> ShoppingItem:
    if name not in shopping_list:
        raise HTTPException(status_code=404, detail="Item not found")
    return shopping_list[name]


@app.put("/shopping-list/{name}")
def update_item(name: str, item: ShoppingItem) -> ShoppingItem:
    if name not in shopping_list:
        raise HTTPException(status_code=404, detail="Item not found")
    if item.name != name:
        raise HTTPException(status_code=422, detail="Item name must match the path")
    shopping_list[name] = item
    return item


@app.delete("/shopping-list/{name}", status_code=204)
def delete_item(name: str) -> Response:
    if name not in shopping_list:
        raise HTTPException(status_code=404, detail="Item not found")
    del shopping_list[name]
    return Response(status_code=204)
```

This is a CRUD API – **c**reate, **r**ead, **u**pdate, **d**elete – for a shopping list. Each item has a `name` (also its ID) and an `amount`. The list is kept in memory. Two more endpoints simulate failures: `/crash` and `/kill` – more on them in section 11.

Build version 3:

```bash
docker build -t shopping-api:v3 .
```

```bash
docker images
```

Three versions now. Replace version 1 on port 8000 with version 3:

```bash
docker rm -f api-v1
```

```bash
docker ps
```

Only `api-v2` is left – port 8000 is free again.

```bash
docker run -d --name api-v3 -p 8000:8000 shopping-api:v3
```

```bash
docker ps
```

`api-v3` on 8000, `api-v2` on 8001.

## 9. Use the API

The list is empty:

```bash
curl localhost:8000/shopping-list
```

> **Output**
> ```text
> []
> ```

Add three apples:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "apples", "amount": 3}'
```

> **Output**
> ```text
> {"name":"apples","amount":3}
> ```

Add five bananas:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "bananas", "amount": 5}'
```

List everything:

```bash
curl localhost:8000/shopping-list
```

> **Output**
> ```text
> [{"name":"apples","amount":3},{"name":"bananas","amount":5}]
> ```

Change the apples to six:

```bash
curl -X PUT localhost:8000/shopping-list/apples -H "Content-Type: application/json" -d '{"name": "apples", "amount": 6}'
```

Delete the bananas and show the HTTP status code:

```bash
curl -X DELETE localhost:8000/shopping-list/bananas -w "%{http_code}\n"
```

> **Output**
> ```text
> 204
> ```

Ask for the bananas again:

```bash
curl localhost:8000/shopping-list/bananas
```

> **Output**
> ```text
> {"detail":"Item not found"}
> ```

Try to add the apples a second time:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "apples", "amount": 1}'
```

> **Output**
> ```text
> {"detail":"Item already exists"}
> ```

Every request left a line in the logs of the container:

```bash
docker logs api-v3
```

> **Output**
> ```text
> INFO:     Started server process [1]
> ...
> INFO:     172.17.0.1:49581 - "GET /shopping-list HTTP/1.1" 200 OK
> INFO:     172.17.0.1:62633 - "POST /shopping-list HTTP/1.1" 201 Created
> INFO:     172.17.0.1:55706 - "POST /shopping-list HTTP/1.1" 201 Created
> INFO:     172.17.0.1:61582 - "GET /shopping-list HTTP/1.1" 200 OK
> INFO:     172.17.0.1:58657 - "PUT /shopping-list/apples HTTP/1.1" 200 OK
> INFO:     172.17.0.1:33413 - "DELETE /shopping-list/bananas HTTP/1.1" 204 No Content
> INFO:     172.17.0.1:21220 - "GET /shopping-list/bananas HTTP/1.1" 404 Not Found
> INFO:     172.17.0.1:16619 - "POST /shopping-list HTTP/1.1" 409 Conflict
> ```

Compare the status codes with what `curl` showed: 201 for created, 204 for deleted, 404 for missing, 409 for a conflict.

FastAPI also generates interactive documentation. In a codespace, open the **Ports** tab, open port 8000 in the browser and add `/docs` to the URL.

## 10. The data lives in the container

Look at the container first:

```bash
docker ps --filter name=api-v3
```

Restart it:

```bash
docker restart api-v3
```

Look again:

```bash
docker ps --filter name=api-v3
```

> **Output**
> ```text
> CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS          PORTS                                         NAMES
> 5ebb66802a22   shopping-api:v3   "uvicorn main:app --…"   2 minutes ago   Up 2 seconds    0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   api-v3
> ```

Same ID, same CREATED – the same container. Only STATUS starts again from zero: the process was restarted.

```bash
curl localhost:8000/shopping-list
```

> **Output**
> ```text
> []
> ```

The list is empty again: it was only held in the memory of the process. Version 2 on port 8001 never had a list at all:

```bash
curl localhost:8001/shopping-list
```

> **Output**
> ```text
> {"detail":"Not Found"}
> ```

Every instance has its own state. If you scale an application to several containers or replace a container, that state is lost. Keeping data beyond the life of a container needs a volume or a database – that is the next step.

## 11. Errors

Call the crash endpoint and show the HTTP status:

```bash
curl -i localhost:8000/crash
```

> **Output**
> ```text
> HTTP/1.1 500 Internal Server Error
> ...
> Internal Server Error
> ```

Is the container still running?

```bash
docker ps
```

Yes – FastAPI turns the error into an HTTP 500 response, and the process keeps running. The error is in the logs:

```bash
docker logs api-v3
```

> **Output**
> ```text
> ...
> RuntimeError: Simulated application error
> ```

An error the application survives is one thing. Now crash the process itself – `/kill` calls `os._exit(1)`, the Python counterpart of Java's `Runtime.halt(1)`: the process ends immediately with exit code 1.

```bash
curl localhost:8000/kill
```

> **Output**
> ```text
> curl: (52) Empty reply from server
> ```

No answer at all – the process is gone. And with it the container:

```bash
docker ps
```

`api-v3` is not listed any more.

```bash
docker ps -a --filter name=api-v3
```

> **Output**
> ```text
> CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS                     PORTS     NAMES
> 5d4c3b2a1f0e   shopping-api:v3   "uvicorn main:app --…"   5 minutes ago   Exited (1) 3 seconds ago             api-v3
> ```

`Exited (1)`: the main process of a container ended, so the container stopped. The exit code tells Docker that it was a failure.

### 11.1 Let Docker restart it

Docker can restart a container whose process fails. Remove the crashed container:

```bash
docker rm api-v3
```

Start it again with a restart policy:

```bash
docker run -d --name api-v3 --restart on-failure -p 8000:8000 shopping-api:v3
```

Put something on the list:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "kiwis", "amount": 30}'
```

Crash it again:

```bash
curl localhost:8000/kill
```

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE             COMMAND                  CREATED          STATUS         PORTS                                         NAMES
> 7a6b5c4d3e2f   shopping-api:v3   "uvicorn main:app --…"   30 seconds ago   Up 2 seconds   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   api-v3
> ```

Created 30 seconds ago, up for 2 seconds: Docker restarted the same container right after the crash. Count the restarts:

```bash
docker inspect -f "{{.RestartCount}}" api-v3
```

> **Output**
> ```text
> 1
> ```

The service is back – but its memory is new:

```bash
curl localhost:8000/shopping-list
```

> **Output**
> ```text
> []
> ```

The kiwis are gone. Keeping data across crashes needs storage outside the container – see [08 – State](08-state.md).

`on-failure` only reacts to exit codes other than 0. A process that ends with `exit(0)` counts as finished, not as failed – that is why `/kill` uses `os._exit(1)`.

## 12. Clean up

```bash
docker rm -f api-v2 api-v3
```

```bash
docker ps -a
```

No `api-…` containers left – so nothing uses the images any more:

```bash
docker rmi shopping-api:v1 shopping-api:v2 shopping-api:v3
```

```bash
docker images
```

```bash
cd ..
```

Keep the `shopping-api` folder – [08 – State](08-state.md) builds on it.

## 13. Overview

| Step | Command | What you saw |
|---|---|---|
| Run as a process | `uvicorn main:app ...` | hostname = your machine |
| Build | `docker build -t shopping-api:v1 .` | Python, libraries and code in one image |
| Run without `-p` | `docker run -d shopping-api:v1` | the app runs, but cannot be reached |
| Run with `-p` | `docker run -d -p 8000:8000 shopping-api:v1` | reachable; hostname = container ID |
| Layers | `docker history shopping-api:v1` | base image at the bottom, your Dockerfile on top |
| Options after the image | `docker run shopping-api:v2 --name ...` | taken as the command – the container does not start |
| Two versions | `-p 8000:8000` and `-p 8001:8000` | same internal port, no conflict |
| Restart | `docker restart api-v3` | in-memory data is gone |
| Error | `curl localhost:8000/crash` | HTTP 500, the process keeps running |
| Crash | `curl localhost:8000/kill` | process and container end with exit code 1 |
| Restart policy | `docker run --restart on-failure ...` | Docker restarts the crashed container; memory is empty |

Next: [03 – Looking Inside Containers](03-looking-inside-containers.md) · [04 – Container Networking](04-container-networking.md)
