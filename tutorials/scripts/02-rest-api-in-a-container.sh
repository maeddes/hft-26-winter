#!/usr/bin/env bash
# Runs all steps of tutorials/02-rest-api-in-a-container.md.
# Works in a temporary directory instead of shopping-api/, so your own copy stays untouched.
#
#   tutorials/scripts/02-rest-api-in-a-container.sh           all at once
#   PAUSE=1 tutorials/scripts/02-rest-api-in-a-container.sh   one command at a time
#   tutorials/scripts/02-cleanup.sh                           removes everything again

source "$(dirname "$0")/lib.sh"

DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT

step "2. A first endpoint"
say "Working directory: $DIR"
cat > "$DIR/requirements.txt" <<'EOF'
fastapi>=0.115,<1.0
uvicorn>=0.30,<1.0
EOF
cat > "$DIR/main.py" <<'EOF'
import socket

from fastapi import FastAPI

app = FastAPI(title="Shopping List API")


@app.get("/hello")
def hello() -> dict[str, str]:
    return {"message": "Hello!", "hostname": socket.gethostname()}
EOF
run "cat $DIR/requirements.txt"
run "cat $DIR/main.py"

step "3. Run it as a normal process"
run "python3 -m venv $DIR/.venv"
run "$DIR/.venv/bin/pip install -q -r $DIR/requirements.txt"
show "uvicorn main:app --host 0.0.0.0 --port 8000        (in the background here)"
(cd "$DIR" && exec .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000) &
APP=$!
sleep 3
run 'curl -s localhost:8000/hello'
run 'hostname'
run 'docker ps'
say "The app runs, but no container – it is a plain process."
kill "$APP"; wait "$APP" 2>/dev/null || true
show 'Ctrl+C'
fails 'curl -s localhost:8000/hello'

step "4. Put it into a container"
cat > "$DIR/Dockerfile" <<'EOF'
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
run "cat $DIR/Dockerfile"
run "docker images --filter 'reference=shopping-api' --filter 'reference=python'"
run "docker build -q -t shopping-api:v1 $DIR"
run "docker images --filter 'reference=shopping-api' --filter 'reference=python'"
run 'docker history shopping-api:v1'

step "5. Why curl fails at first"
run 'docker run -d --name api-v1 shopping-api:v1'
run 'docker ps'
sleep 2
fails 'curl -s localhost:8000/hello'
run 'docker rm -f api-v1'
run 'docker ps -a --filter name=api-v1'
run 'docker run -d --name api-v1 -p 8000:8000 shopping-api:v1'
sleep 2
run 'curl -s localhost:8000/hello'
run 'docker ps'

step "6. The code is part of the image"
run "mv $DIR/main.py $DIR/main.py.bak"
run "ls $DIR"
run 'docker restart api-v1'
sleep 2
run 'curl -s localhost:8000/hello'
run 'docker run --rm shopping-api:v1 ls /app'
fails "docker build -q -t shopping-api:broken $DIR"
run "mv $DIR/main.py.bak $DIR/main.py"

step "7. Two versions side by side"
run "sed -i.orig 's/\"Hello!\"/\"Good morning!\"/' $DIR/main.py && rm $DIR/main.py.orig"
run "grep message $DIR/main.py"
run "docker build -q -t shopping-api:v2 $DIR"
run "docker images --filter 'reference=shopping-api'"
say "Options in the wrong place – everything after the image name is the command:"
fails 'docker run -d shopping-api:v2 --name api-v2 -p 8001:8000'
run 'docker ps -a --filter ancestor=shopping-api:v2'
run 'docker rm $(docker ps -aq --filter ancestor=shopping-api:v2)'
run 'docker run -d --name api-v2 -p 8001:8000 shopping-api:v2'
run 'docker ps'
sleep 2
run 'curl -s localhost:8000/hello'
run 'curl -s localhost:8001/hello'

step "8. Complete the API"
cp code/backend-fastapi/main.py "$DIR/main.py"
say "main.py replaced with the complete version (code/backend-fastapi/main.py)"
run "docker build -q -t shopping-api:v3 $DIR"
run "docker images --filter 'reference=shopping-api'"
run 'docker rm -f api-v1'
run 'docker ps'
run 'docker run -d --name api-v3 -p 8000:8000 shopping-api:v3'
run 'docker ps'
sleep 2

step "9. Use the API"
run 'curl -s localhost:8000/shopping-list'
run "curl -s -X POST localhost:8000/shopping-list -H 'Content-Type: application/json' -d '{\"name\": \"apples\", \"amount\": 3}'"
run "curl -s -X POST localhost:8000/shopping-list -H 'Content-Type: application/json' -d '{\"name\": \"bananas\", \"amount\": 5}'"
run 'curl -s localhost:8000/shopping-list'
run "curl -s -X PUT localhost:8000/shopping-list/apples -H 'Content-Type: application/json' -d '{\"name\": \"apples\", \"amount\": 6}'"
run 'curl -s -X DELETE localhost:8000/shopping-list/bananas -w "%{http_code}\n"'
run 'curl -s localhost:8000/shopping-list/bananas'
run "curl -s -X POST localhost:8000/shopping-list -H 'Content-Type: application/json' -d '{\"name\": \"apples\", \"amount\": 1}'"
run 'curl -s localhost:8000/shopping-list'
run 'docker logs api-v3'

step "10. The data lives in the container"
run 'docker ps --filter name=api-v3'
run 'docker restart api-v3'
run 'docker ps --filter name=api-v3'
sleep 2
run 'curl -s localhost:8000/shopping-list'
run 'curl -s localhost:8001/shopping-list'

step "11. Errors"
run 'curl -s -i localhost:8000/crash | head -1'
run 'docker ps'
run 'docker logs api-v3 2>&1 | grep RuntimeError'
fails 'curl -s localhost:8000/kill'
sleep 1
run 'docker ps'
run 'docker ps -a --filter name=api-v3'

step "11.1 Let Docker restart it"
run 'docker rm api-v3'
run 'docker run -d --name api-v3 --restart on-failure -p 8000:8000 shopping-api:v3'
sleep 2
run "curl -s -X POST localhost:8000/shopping-list -H 'Content-Type: application/json' -d '{\"name\": \"kiwis\", \"amount\": 30}'"
fails 'curl -s localhost:8000/kill'
sleep 2
run 'docker ps'
run 'docker inspect -f "{{.RestartCount}}" api-v3'
run 'curl -s localhost:8000/shopping-list'

step "12. Clean up"
run 'docker rm -f api-v2 api-v3'
run 'docker ps -a --filter name=api-'
run 'docker rmi shopping-api:v1 shopping-api:v2 shopping-api:v3'
run "docker images --filter 'reference=shopping-api'"
