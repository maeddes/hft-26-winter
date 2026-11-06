
## Simple REST API

The FastAPI application exposes `/hello` (which includes the server hostname),
`/crash` (which raises a simulated server error), and CRUD endpoints for a
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
to build and start them on a shared Docker network:

```bash
docker network create shopping-demo
docker build -f code/Dockerfile-backend -t shopping-list-backend code/backend-fastapi
docker run -d --name shopping-backend --network shopping-demo shopping-list-backend
docker build -f code/Dockerfile-frontend -t shopping-list-frontend code
docker run --rm --name shopping-frontend --network shopping-demo \
  -e BACKEND_URL=http://shopping-backend:8000 -p 5000:5000 shopping-list-frontend
```

Open port 5000 for the web UI. The UI supports adding, updating, and deleting
items, and its “Check backend” link displays the backend hostname.
