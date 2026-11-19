#!/usr/bin/env bash
# Removes what tutorial 05 created, if something is left – only things with the
# label tutorial=05 or the names the tutorial uses. No unfiltered prune.

source "$(dirname "$0")/lib.sh"

L='--filter label=tutorial=05'
step "Clean up tutorial 05"
ANON=$(docker inspect --format '{{range .Mounts}}{{.Name}}{{end}}' mess-anon 2>/dev/null || true)
run 'docker rm -f mess-web mess-anon 2>/dev/null || true'
run "docker container prune -f $L"
run "docker image prune -a -f $L"
run "docker network prune -f $L"
run "docker volume prune -a -f $L"
if [ -n "$ANON" ]; then run "docker volume rm $ANON"; fi
run "docker ps -a $L"
run "docker images $L"
