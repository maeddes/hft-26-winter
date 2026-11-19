#!/usr/bin/env bash
# Runs all steps of tutorials/07-scaling.md.
#
#   tutorials/scripts/07-scaling.sh                     all at once
#   PAUSE=1 tutorials/scripts/07-scaling.sh             one command at a time
#   FRONTEND_PORT=5001 tutorials/scripts/07-scaling.sh  on a Mac (port 5000 is AirPlay)
#   tutorials/scripts/07-cleanup.sh                     removes everything again

source "$(dirname "$0")/lib.sh"

FP=${FRONTEND_PORT:-5000}
F="-f compose-lb.yaml"
if [ "$FP" != "5000" ]; then
  OVR_FILE=$(mktemp -d)/port.yaml
  printf 'services:\n  frontend:\n    ports: !override\n      - "%s:5000"\n' "$FP" > "$OVR_FILE"
  F="$F -f $OVR_FILE"
  say "Frontend on port $FP via $OVR_FILE"
fi
MEMBERS='{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'
SERVERS='curl -s localhost:8080/api/http/services/backend@docker | grep -o "\"url\":\"[^\"]*\""'
LOOP_PROXY='for i in 1 2 3 4 5 6; do curl -s localhost:8000/hello; echo; done'
LOOP_FRONT="for i in 1 2 3 4 5 6; do curl -s localhost:$FP/hello | grep -o 'Server: <strong>[^<]*'; done"

step "2. The Compose file"
show 'cd code'
cd code
run 'cat compose-lb.yaml'

step "3. Start it"
run "docker compose $F up -d"
sleep 4
run "docker compose $F ps"
run "docker network inspect shopping_default --format '$MEMBERS'"

step "4. How Traefik finds the backends"
run "$SERVERS"
say "Two servers – the addresses of the two backend containers in shopping_default."

step "5. Watch the load balancer"
run "$LOOP_PROXY"
run "$LOOP_FRONT"

step "5.1 Why not just the name backend?"
run 'docker build -q -t toolbox toolbox'
run 'docker run --rm --network shopping_default toolbox nslookup backend'
run "docker run --rm --network shopping_default toolbox sh -c 'for i in 1 2 3 4 5 6; do curl -s backend:8000/hello; echo; done'"

step "6. Scale up and down"
run "docker compose $F up -d --scale backend=3"
sleep 3
run "docker compose $F ps"
run "docker network inspect shopping_default --format '$MEMBERS'"
run "$SERVERS"
run "$LOOP_PROXY"
run "$LOOP_FRONT"
run "docker compose $F up -d --scale backend=1"
sleep 2
run "docker compose $F ps"
run "$SERVERS"
run "$LOOP_PROXY"

step "7. Let an instance crash"
run "docker compose $F up -d --scale backend=3"
sleep 3
run "docker compose $F ps backend"
run "curl -s localhost:8000/kill; echo"
sleep 2
run "docker compose $F ps backend"
run "docker inspect --format '{{.Name}} {{.RestartCount}}' \$(docker compose $F ps -q backend)"
run "$LOOP_PROXY"

step "8. Where is the shopping list?"
run "curl -s -X POST localhost:8000/shopping-list -H 'Content-Type: application/json' -d '{\"name\": \"apples\", \"amount\": 3}'; echo"
run 'for i in 1 2 3 4 5 6; do curl -s localhost:8000/shopping-list; echo; done'
say "Each backend instance has its own list in memory."

step "Done"
say "Running: proxy, 3 backends, frontend. Clean up with tutorials/scripts/07-cleanup.sh"
