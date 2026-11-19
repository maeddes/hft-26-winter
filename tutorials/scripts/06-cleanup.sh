#!/usr/bin/env bash
# Removes what tutorial 06 created – and nothing else. No prune.

source "$(dirname "$0")/lib.sh"

step "Clean up tutorial 06"
run 'docker compose -p shopping down 2>/dev/null || true'
run 'docker rm -f frontend backend toolbox 2>/dev/null || true'
run 'docker network rm shop-net 2>/dev/null || true'
run 'docker rmi shopping-backend shopping-frontend shopping-backend:v1 shopping-frontend:v1 shopping-backend:v2 shopping-frontend:v2 toolbox 2>/dev/null || true'
run 'docker ps -a --filter name=shopping'
run "docker images --filter 'reference=shopping-*' --filter 'reference=toolbox'"
