#!/usr/bin/env bash
# Runs all steps of tutorials/07-scaling.md.
# The watching loop of the second terminal is replayed with short for loops.
# The edit of compose-lb.yaml in section 7 is replayed with an override file –
# the file in the repository stays unchanged.
#
#   tutorials/scripts/07-scaling.sh                     all at once
#   PAUSE=1 tutorials/scripts/07-scaling.sh             one command at a time
#   FRONTEND_PORT=5001 tutorials/scripts/07-scaling.sh  on a Mac (port 5000 is AirPlay)
#   tutorials/scripts/07-cleanup.sh                     removes everything again

source "$(dirname "$0")/lib.sh"

FP=${FRONTEND_PORT:-5000}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
F="-f compose-lb.yaml"
if [ "$FP" != "5000" ]; then
  printf 'services:\n  frontend:\n    ports: !override\n      - "%s:5000"\n' "$FP" > "$TMP/port.yaml"
  F="$F -f $TMP/port.yaml"
  say "Frontend on port $FP via $TMP/port.yaml"
fi
MEMBERS='{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'
LOOP='for i in 1 2 3 4 5 6; do curl -s localhost:8000/hello; echo; done'

step "2. The Compose file"
show 'cd code'
cd code
run 'cat compose-lb.yaml'

step "3. Start it"
run "docker compose $F up -d"
sleep 4
run "docker compose $F ps"
run "docker network inspect shopping_default --format '$MEMBERS'"

step "4. Watch the load balancer"
run "$LOOP"

step "5. Scale up while watching"
show 'while true; do curl -s localhost:8000/hello; echo; sleep 1; done     (second terminal – replayed with for loops)'
run "docker compose $F up -d --scale backend=3"
sleep 3
run "$LOOP"
run "docker compose $F ps backend"
run "docker network inspect shopping_default --format '$MEMBERS'"

step "6. Let instances crash"
run "curl -s localhost:8000/kill; echo"
sleep 2
run "$LOOP"
run "docker compose $F ps -a backend"
run "curl -s localhost:8000/kill; echo"
sleep 2
run "$LOOP"
run "curl -s localhost:8000/kill; echo"
sleep 2
run "$LOOP"
run "docker compose $F ps -a backend"
run "curl -s localhost:$FP | grep -o 'Backend returned HTTP [0-9]*[^<]*' | head -1"
say "Nobody brings them back. Stop it all:"
run "docker compose $F down"

step "7. Restart on failure"
printf 'services:\n  backend:\n    restart: on-failure\n' > "$TMP/restart.yaml"
F="$F -f $TMP/restart.yaml"
show "code compose-lb.yaml     (add 'restart: on-failure' to backend – replayed with $TMP/restart.yaml)"
run "docker compose $F config | sed -n '/^  backend:/,/^  [a-z]*:\$/p' | grep -E 'backend:|restart'"
run "docker compose $F up -d --scale backend=3"
sleep 4
run "docker compose $F ps backend"
run "curl -s localhost:8000/kill; echo"
sleep 2
run "$LOOP"
run "docker compose $F ps backend"
run "docker inspect --format '{{.Name}} {{.RestartCount}}' \$(docker compose $F ps -q backend)"
say "Now three kills in a row:"
run "curl -s localhost:8000/kill; echo"
run "curl -s localhost:8000/kill; echo"
run "curl -s localhost:8000/kill; echo"
sleep 3
run "$LOOP"
run "docker compose $F ps backend"
run "docker inspect --format '{{.Name}} {{.RestartCount}}' \$(docker compose $F ps -q backend)"

step "8. Where is the shopping list?"
run "curl -s -X POST localhost:8000/shopping-list -H 'Content-Type: application/json' -d '{\"name\": \"apples\", \"amount\": 3}'; echo"
run 'for i in 1 2 3 4 5 6; do curl -s localhost:8000/shopping-list; echo; done'
say "Each backend instance has its own list in memory."
run "curl -s localhost:8000/kill; echo"
sleep 3
run 'for i in 1 2 3 4 5 6; do curl -s localhost:8000/shopping-list; echo; done'

step "9. Clean up"
run "docker compose $F down"
run "docker compose $F ps"
