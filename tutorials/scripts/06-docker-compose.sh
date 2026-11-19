#!/usr/bin/env bash
# Runs all steps of tutorials/06-docker-compose.md.
#
#   tutorials/scripts/06-docker-compose.sh                     all at once
#   PAUSE=1 tutorials/scripts/06-docker-compose.sh             one command at a time
#   FRONTEND_PORT=5001 tutorials/scripts/06-docker-compose.sh  on a Mac (port 5000 is AirPlay)
#   tutorials/scripts/06-cleanup.sh                            removes everything again

source "$(dirname "$0")/lib.sh"

FP=${FRONTEND_PORT:-5000}
OVR=""
if [ "$FP" != "5000" ]; then
  OVR_FILE=$(mktemp -d)/port.yaml
  printf 'services:\n  frontend:\n    ports: !override\n      - "%s:5000"\n' "$FP" > "$OVR_FILE"
  OVR="-f $OVR_FILE"
  say "Frontend on port $FP via $OVR_FILE"
fi
D=""; [ -n "$OVR" ] && D="-f compose.yaml $OVR "
MEMBERS='{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'

step "2. Start from an empty setup"
run 'docker rm -f frontend backend toolbox 2>/dev/null || true'
run 'docker network rm shop-net 2>/dev/null || true'
run 'docker rmi shopping-backend shopping-frontend 2>/dev/null || true'
run 'docker ps -a --filter name=frontend --filter name=backend'
run "docker images --filter 'reference=shopping-*'"

step "3. The setup by hand"
run 'docker build -q -t shopping-backend code/backend-fastapi'
run 'docker build -q -t shopping-frontend code/frontend-flask'
run "docker images --filter 'reference=shopping-*'"
run 'docker network create shop-net'
run 'docker run -d --name backend --network shop-net shopping-backend'
run "docker run -d --name frontend --network shop-net -e BACKEND_URL=http://backend:8000 -p $FP:5000 shopping-frontend"
sleep 2
run "curl -s localhost:$FP/hello | grep -o 'Server: <strong>[^<]*'"
run 'docker ps'
run "docker network inspect shop-net --format '$MEMBERS'"
run 'docker rm -f frontend backend'
run 'docker network rm shop-net'
run 'docker ps -a --filter name=frontend --filter name=backend'

step "4. The same setup with Compose"
show 'cd code'
cd code
run 'cat compose.yaml'
run "docker compose ${D}up -d"
run "docker compose ${D}ps"
run 'docker ps'
run 'docker network ls --filter name=shopping'
run "docker network inspect shopping_default --format '$MEMBERS'"
run "docker images --filter 'reference=shopping-*'"
sleep 2
run "curl -s localhost:$FP/hello | grep -o 'Server: <strong>[^<]*'"
fails 'curl -s localhost:8000/hello'
run "docker compose ${D}exec frontend getent hosts backend"
run "curl -s -X POST localhost:$FP/items -d 'name=apples&amount=3' -o /dev/null -w '%{http_code}\n'"
run "docker compose ${D}logs backend | tail -3"
say "Once more – Compose compares and changes nothing:"
run "docker compose ${D}up -d"
run "docker compose ${D}ps"

step "4.1 The toolbox joins the Compose network"
run 'docker build -q -t toolbox toolbox'
show 'docker run -it --rm --network shopping_default toolbox     (replayed)'
run 'docker run --rm --network shopping_default toolbox nslookup backend'
run 'docker run --rm --network shopping_default toolbox curl -s backend:8000/shopping-list'
run 'docker run -d --name toolbox --network shopping_default toolbox sleep 30'
run "docker network inspect shopping_default --format '$MEMBERS'"
run 'docker rm -f toolbox'

step "5. Throw it away"
run "docker compose ${D}down"
run 'docker ps -a --filter name=shopping'
run 'docker network ls --filter name=shopping'
run "docker images --filter 'reference=shopping-*'"
say "Images stay. Up again – nothing to build:"
run "docker compose ${D}up -d"
say "With --build, Compose builds first:"
run "docker compose ${D}up -d --build 2>&1 | grep -E 'Built|Building|Running|Started|Recreated' || true"
run "docker compose ${D}down"

step "6.1 Only image"
run 'cat compose-image.yaml'
run "docker images --filter 'reference=shopping-*'"
fails "docker compose -f compose-image.yaml $OVR up -d"
run 'docker tag shopping-backend shopping-backend:v1'
run 'docker tag shopping-frontend shopping-frontend:v1'
run "docker images --filter 'reference=shopping-*'"
run "docker compose -f compose-image.yaml $OVR up -d"
run "docker compose -f compose-image.yaml $OVR ps"
run "docker compose -f compose-image.yaml $OVR build"
run "docker compose -f compose-image.yaml $OVR down"

step "6.2 Build and image"
run 'cat compose-build-image.yaml'
run "docker compose -f compose-build-image.yaml $OVR up -d 2>&1 | grep -v -E '^#|^$' || true"
run "docker images --filter 'reference=shopping-*'"
run "docker compose -f compose-build-image.yaml $OVR ps"
say "Once more – the images exist now, no pull, no build:"
run "docker compose -f compose-build-image.yaml $OVR up -d"
run "docker compose -f compose-build-image.yaml $OVR down"

step "Done"
say "Images left: shopping-backend/-frontend (latest, v1, v2) and toolbox. Clean up with tutorials/scripts/06-cleanup.sh"
