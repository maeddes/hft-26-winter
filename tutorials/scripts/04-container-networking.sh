#!/usr/bin/env bash
# Runs all steps of tutorials/04-container-networking.md.
# Interactive shells are replayed with `docker exec <container> <command>`
# and one-shot toolbox containers.
#
#   tutorials/scripts/04-container-networking.sh           all at once
#   PAUSE=1 tutorials/scripts/04-container-networking.sh   one command at a time
#   FRONTEND_PORT=5001 tutorials/scripts/04-...            on a Mac (port 5000 is AirPlay)
#   tutorials/scripts/04-cleanup.sh                        removes everything again

source "$(dirname "$0")/lib.sh"

FP=${FRONTEND_PORT:-5000}
VENV=$(mktemp -d)
trap 'rm -rf "$VENV"' EXIT
NETS='{{range $name, $net := .NetworkSettings.Networks}}{{$name}} {{$net.IPAddress}}{{println}}{{end}}'
MEMBERS='{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'

step "2. Build the two images"
run 'docker build -q -t shopping-backend code/backend-fastapi'
run 'docker build -q -t shopping-frontend code/frontend-flask'
run "docker images --filter 'reference=shopping-*'"

step "3. The frontend as a local process"
run 'docker run -d --name backend -p 8000:8000 shopping-backend'
run 'docker ps'
sleep 2
run 'curl -s localhost:8000/hello'
run "python3 -m venv $VENV/.venv"
run "$VENV/.venv/bin/pip install -q -r code/frontend-flask/requirements.txt"
show "python app.py        (in code/frontend-flask, in the background here)"
(cd code/frontend-flask && PORT=$FP exec "$VENV/.venv/bin/python" app.py) >/dev/null 2>&1 &
APP=$!
sleep 3
run "curl -s localhost:$FP/hello | grep -o 'Server: <strong>[^<]*'"
say "The frontend process reached the backend container at 127.0.0.1:8000 – the published port."
run "curl -s -X POST localhost:8000/shopping-list -H 'Content-Type: application/json' -d '{\"name\": \"kiwis\", \"amount\": 30}'"
run "curl -s localhost:$FP | grep -o 'item-name\">[^<]*'"
say "Added with curl at the backend, shown by the frontend – the data is in the backend."
kill "$APP"; wait "$APP" 2>/dev/null || true
show 'Ctrl+C'
fails "curl -s localhost:$FP"
run 'curl -s localhost:8000/shopping-list'
show "BACKEND_URL=http://127.0.0.1:8001 python app.py"
(cd code/frontend-flask && PORT=$FP BACKEND_URL=http://127.0.0.1:8001 exec "$VENV/.venv/bin/python" app.py) >/dev/null 2>&1 &
APP=$!
sleep 3
run "curl -s localhost:$FP | grep -o 'Could not reach backend at [^:]*:[^:]*:[0-9]*'"
kill "$APP"; wait "$APP" 2>/dev/null || true
show 'Ctrl+C'

step "4. The frontend in a container"
run "docker run -d --name frontend -p $FP:5000 -e BACKEND_URL=http://127.0.0.1:8000 shopping-frontend"
run 'docker ps'
sleep 2
run "curl -s localhost:$FP | grep -o 'Could not reach backend at [^:]*:[^:]*:[0-9]*'"
say "127.0.0.1 is now the frontend container itself."
run 'docker rm -f frontend'
run "docker run -d --name frontend -p $FP:5000 -e BACKEND_URL=http://backend:8000 shopping-frontend"
sleep 2
run "curl -s localhost:$FP | grep -o 'Failed to resolve[^)]*)' | head -1"

step "5. Inside the backend"
fails 'docker exec backend curl localhost:8000/hello'
run "docker exec backend sh -c 'for t in curl nc ping getent python; do command -v \$t || echo \"\$t: not found\"; done'"
run "docker exec backend python -c \"import urllib.request; print(urllib.request.urlopen('http://localhost:8000/hello').read().decode())\""

step "6. Inside the frontend"
run 'docker exec frontend hostname'
fails 'docker exec frontend getent hosts backend'
run 'docker exec frontend cat /etc/hosts'

step "7. Which network are they in?"
run 'docker network ls'
run "docker network inspect bridge --format '$MEMBERS'"
run "docker container inspect frontend --format '$NETS'"

step "7.1 A toolbox container"
run 'cat code/toolbox/Dockerfile'
run 'docker build -q -t toolbox code/toolbox'
run "docker images --filter 'reference=shopping-*' --filter 'reference=toolbox'"
show 'docker run -it --rm --name toolbox toolbox     (replayed one command at a time)'
fails 'docker run --rm toolbox nslookup backend'
fails 'docker run --rm toolbox ping -c 2 backend'
BIP=$(docker container inspect backend --format '{{(index .NetworkSettings.Networks "bridge").IPAddress}}')
run "docker run --rm toolbox ping -c 2 $BIP"
run "docker run --rm toolbox curl -s $BIP:8000/hello"
say "By address it works – the default network only has no names."

step "8. A network for both"
run 'docker network create shop-net'
run 'docker network ls'
run "docker network inspect shop-net --format '$MEMBERS'"
run 'docker network connect shop-net backend'
run "docker network inspect shop-net --format '$MEMBERS'"
run 'docker network connect shop-net frontend'
run "docker network inspect shop-net --format '$MEMBERS'"
run "docker container inspect frontend --format '$NETS'"
run "curl -s localhost:$FP/hello | grep -o 'Server: <strong>[^<]*'"
run 'docker exec frontend getent hosts backend'

step "9. From one container to the other"
show 'docker run -it --rm --name toolbox --network shop-net toolbox     (replayed)'
run 'docker run --rm --network shop-net toolbox nslookup backend'
run 'docker run --rm --network shop-net toolbox nslookup frontend'
run 'docker run --rm --network shop-net toolbox ping -c 2 backend'
run 'docker run --rm --network shop-net toolbox curl -s backend:8000/hello'
run 'docker run --rm --network shop-net toolbox nc -zv backend 8000'
run 'docker run --rm --network shop-net toolbox nc -zv frontend 5000'
run "docker run --rm --network shop-net toolbox sh -c 'printf \"GET /hello HTTP/1.0\r\n\r\n\" | nc -w 3 backend 8000'"
run 'docker run -d --name toolbox --network shop-net toolbox sleep 30'
run "docker network inspect shop-net --format '$MEMBERS'"
run 'docker rm -f toolbox'
run "docker network inspect shop-net --format '$MEMBERS'"

step "9.1 Between frontend and backend"
run "docker exec frontend python -c \"import requests; print(requests.get('http://backend:8000/hello', timeout=3).text)\""
run 'docker exec backend getent hosts frontend'
run "docker exec backend python -c \"import urllib.request; print(urllib.request.urlopen('http://frontend:5000').status)\""

step "10. The backend does not need a published port"
run 'docker rm -f backend'
run "docker network inspect shop-net --format '$MEMBERS'"
run "curl -s localhost:$FP | grep -o 'Failed to resolve[^)]*)' | head -1"
run 'docker run -d --name backend --network shop-net shopping-backend'
run "docker network inspect shop-net --format '$MEMBERS'"
sleep 2
fails 'curl -s localhost:8000/hello'
run 'docker ps --format "table {{.Names}}\t{{.Ports}}"'
run "curl -s localhost:$FP/hello | grep -o 'Server: <strong>[^<]*'"
run "docker ps --filter name=backend --format '{{.ID}}'"
say "A new backend container, a new hostname – but the same name, so the frontend finds it."
run "curl -s -X POST localhost:$FP/items -d 'name=apples&amount=3' -o /dev/null -w '%{http_code}\n'"
run "curl -s localhost:$FP | grep -o 'item-name\">[^<]*'"
say "Only apples: the kiwis lived in the memory of the old backend container."

step "Done"
say "Running: backend and frontend in shop-net. Clean up with tutorials/scripts/04-cleanup.sh"
