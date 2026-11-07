# A REST API in a Container – Step by Step

## 1. About

In this walkthrough you write a small REST API in Python, run it as a normal process, put it into a container, and then extend it step by step:

1. a `/hello` endpoint that returns the hostname
2. the same app in a container – and why `curl` fails at first
3. two versions running side by side
4. a complete shopping-list API (create, read, update, delete)

Every code block with a command contains **exactly one command**. File contents are shown in separate blocks – create the file, paste the content, save.

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

```text
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

The app is now waiting for requests and blocks this terminal. Open a **second terminal** and call it:

```bash
curl localhost:8000/hello
```

```text
{"message":"Hello!","hostname":"codespaces-6542bf"}
```

Compare the hostname with the name of your machine:

```bash
hostname
```

Same name: the app runs directly on your machine. Go back to the first terminal and stop the app with **Ctrl+C**. Then leave the virtual environment:

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

```text
IMAGE             ID             DISK USAGE   CONTENT SIZE   EXTRA
shopping-api:v1   a1b2c3d4e5f6        201MB         48.5MB
...
```

## 5. Why `curl` fails at first

Start a container in the background:

```bash
docker run -d --name api-v1 shopping-api:v1
```

```bash
docker ps
```

```text
CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS         PORTS      NAMES
db6f5a3c1e2b   shopping-api:v1   "uvicorn main:app --…"   5 seconds ago   Up 4 seconds   8000/tcp   api-v1
```

The container runs and the app listens on port 8000. Call it:

```bash
curl localhost:8000/hello
```

```text
curl: (7) Failed to connect to localhost port 8000 after 0 ms: Couldn't connect to server
```

The app listens on port 8000 **inside the container**. The container is isolated – nothing from outside reaches it. The `PORTS` column shows `8000/tcp` without an arrow: the port is exposed, but not published.

Remove the container:

```bash
docker rm -f api-v1
```

Start it again, this time publishing container port 8000 as port 8000 on your machine:

```bash
docker run -d --name api-v1 -p 8000:8000 shopping-api:v1
```

```bash
curl localhost:8000/hello
```

```text
{"message":"Hello!","hostname":"db6f5a3c1e2b"}
```

Look at the hostname – it changed. Compare it with the container ID:

```bash
docker ps
```

```text
CONTAINER ID   IMAGE             COMMAND                  CREATED         STATUS         PORTS                                         NAMES
db6f5a3c1e2b   shopping-api:v1   "uvicorn main:app --…"   5 seconds ago   Up 4 seconds   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   api-v1
```

The hostname is the container ID: each container gets its own hostname, as if it were a machine of its own.

## 6. The code is part of the image

Rename the source file, as if it were gone:

```bash
mv main.py main.py.bak
```

Restart the container:

```bash
docker restart api-v1
```

```bash
curl localhost:8000/hello
```

```text
{"message":"Hello!","hostname":"db6f5a3c1e2b"}
```

Still working: `COPY` put the file into the image at build time. The image does not point to your directory. Rebuilding would fail now – try it:

```bash
docker build -t shopping-api:broken .
```

```text
ERROR: failed to build: ... "/main.py": not found
```

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

This build is fast: all steps up to `COPY main.py` come from the cache – only the last layers are rebuilt.

Start version 2 on port **8001**. Inside the container it still listens on 8000:

```bash
docker run -d --name api-v2 -p 8001:8000 shopping-api:v2
```

Call both versions:

```bash
curl localhost:8000/hello
```

```text
{"message":"Hello!","hostname":"db6f5a3c1e2b"}
```

```bash
curl localhost:8001/hello
```

```text
{"message":"Good morning!","hostname":"8c1d2e3f4a5b"}
```

Two containers, two versions, both listening on port 8000 inside – no conflict, because they are published on different ports. This is the basis for a blue/green update: start the new version next to the old one, test it, then switch.

## 8. Complete the API

Open `main.py` and replace its whole content with:

```python
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

This is a CRUD API – **c**reate, **r**ead, **u**pdate, **d**elete – for a shopping list. Each item has a `name` (also its ID) and an `amount`. The list is kept in memory.

Build version 3:

```bash
docker build -t shopping-api:v3 .
```

Replace version 1 on port 8000 with version 3:

```bash
docker rm -f api-v1
```

```bash
docker run -d --name api-v3 -p 8000:8000 shopping-api:v3
```

## 9. Use the API

The list is empty:

```bash
curl localhost:8000/shopping-list
```

```text
[]
```

Add three apples:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "apples", "amount": 3}'
```

```text
{"name":"apples","amount":3}
```

Add five bananas:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "bananas", "amount": 5}'
```

List everything:

```bash
curl localhost:8000/shopping-list
```

```text
[{"name":"apples","amount":3},{"name":"bananas","amount":5}]
```

Change the apples to six:

```bash
curl -X PUT localhost:8000/shopping-list/apples -H "Content-Type: application/json" -d '{"name": "apples", "amount": 6}'
```

Delete the bananas and show the HTTP status code:

```bash
curl -X DELETE localhost:8000/shopping-list/bananas -w "%{http_code}\n"
```

```text
204
```

Ask for the bananas again:

```bash
curl localhost:8000/shopping-list/bananas
```

```text
{"detail":"Item not found"}
```

Try to add the apples a second time:

```bash
curl -X POST localhost:8000/shopping-list -H "Content-Type: application/json" -d '{"name": "apples", "amount": 1}'
```

```text
{"detail":"Item already exists"}
```

FastAPI also generates interactive documentation. In a codespace, open the **Ports** tab, open port 8000 in the browser and add `/docs` to the URL.

## 10. The data lives in the container

Restart the container:

```bash
docker restart api-v3
```

```bash
curl localhost:8000/shopping-list
```

```text
[]
```

The list is empty again: it was only held in the memory of the process. Version 2 on port 8001 never had a list at all:

```bash
curl localhost:8001/shopping-list
```

```text
{"detail":"Not Found"}
```

Every instance has its own state. If you scale an application to several containers or replace a container, that state is lost. Keeping data beyond the life of a container needs a volume or a database – that is the next step.

## 11. Errors

Call the crash endpoint and show the HTTP status:

```bash
curl -i localhost:8000/crash
```

```text
HTTP/1.1 500 Internal Server Error
...
Internal Server Error
```

Is the container still running?

```bash
docker ps
```

Yes – FastAPI turns the error into an HTTP 500 response, and the process keeps running. The error is in the logs:

```bash
docker logs api-v3
```

```text
...
RuntimeError: Simulated application error
```

## 12. Clean up

```bash
docker rm -f api-v2 api-v3
```

```bash
docker rmi shopping-api:v1 shopping-api:v2 shopping-api:v3
```

```bash
cd ..
```

## 13. Overview

| Step | Command | What you saw |
|---|---|---|
| Run as a process | `uvicorn main:app ...` | hostname = your machine |
| Build | `docker build -t shopping-api:v1 .` | Python, libraries and code in one image |
| Run without `-p` | `docker run -d shopping-api:v1` | the app runs, but cannot be reached |
| Run with `-p` | `docker run -d -p 8000:8000 shopping-api:v1` | reachable; hostname = container ID |
| Two versions | `-p 8000:8000` and `-p 8001:8000` | same internal port, no conflict |
| Restart | `docker restart api-v3` | in-memory data is gone |

Next: connecting several containers – a web frontend for this API on a shared Docker network.
