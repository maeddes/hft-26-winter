
## Simple REST API

The FastAPI application exposes `/hello` (which includes the server hostname),
`/crash` (which raises a simulated server error), `/kill` (which ends the
process with exit code 1), and CRUD endpoints for a
shopping list. Each item has a `name` used as its ID and a non-negative integer
`amount`. The list is held in memory and is reset when the application restarts.

Run these commands from the repository root to start the backend in a Codespace:

```bash
cd code/backend-fastapi
python -m pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Open port 8000 in the Codespaces Ports tab, then visit `/docs` for interactive
API documentation. The collection endpoints are `GET` and `POST` `/shopping-list`;
individual items use `GET`, `PUT`, and `DELETE` `/shopping-list/{name}`.

To run the Flask web UI locally, open another terminal from the repository root:

```bash
cd code/frontend-flask
python -m pip install -r requirements.txt
BACKEND_URL=http://127.0.0.1:8000 python app.py
```

Open port 5000 in the Codespaces Ports tab. Set `BACKEND_URL` to the backend's
reachable URL if it is running elsewhere.

To run both services as containers, run these commands from the repository root
to build and start them on a shared Docker network. Each service folder has its
own `Dockerfile`, and the folder is the build context:

```bash
docker network create shopping-demo
docker build -t shopping-list-backend code/backend-fastapi
docker run -d --name shopping-backend --network shopping-demo shopping-list-backend
docker build -t shopping-list-frontend code/frontend-flask
docker run --rm --name shopping-frontend --network shopping-demo \
  -e BACKEND_URL=http://shopping-backend:8000 -p 5000:5000 shopping-list-frontend
```

Open port 5000 for the web UI. The UI supports adding, updating, and deleting
items, and its “Check backend” link displays the backend hostname.

## Toolbox

`toolbox/` is a small image (about 28 MB) with `bash`, `curl`, `ping`,
`nslookup`, `dig` and `nc` – for looking around in a Docker network. The
application images are slim and contain none of these tools on purpose.

```bash
docker build -t toolbox code/toolbox
docker run -it --rm --network <network> toolbox
```

## Docker Compose

From this folder, `compose.yaml` starts the same setup with one command –
backend and frontend on a shared network, only the frontend published:

```bash
docker compose up -d
```

`compose-lb.yaml` puts a Traefik load balancer between the frontend and two
backend instances (proxy on port 8000, dashboard on port 8080):

```bash
docker compose -f compose-lb.yaml up -d --scale backend=3
```

Both use the project name `shopping`. Stop with `docker compose down` (add
`-f compose-lb.yaml` for the second file).

## Build context demo

The files `Dockerfile-backend` and `Dockerfile-frontend` in this folder show that the Dockerfile and the build context are independent:
`-f` names the Dockerfile, the last argument is the context, and `COPY` only
sees files inside the context.

```bash
docker build -f code/Dockerfile-backend -t shopping-list-backend code/backend-fastapi
docker build -f code/Dockerfile-frontend -t shopping-list-frontend code
```

The backend variant uses the service folder as context; the frontend variant
uses `code/` and therefore needs `COPY frontend-flask/...`. Compare it with
`frontend-flask/Dockerfile`. For everyday use, prefer the `Dockerfile` inside
each service folder.
