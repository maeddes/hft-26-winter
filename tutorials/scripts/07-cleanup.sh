#!/usr/bin/env bash
# Removes what tutorial 07 created – and nothing else. No prune.

source "$(dirname "$0")/lib.sh"

step "Clean up tutorial 07"
run 'docker compose -p shopping down 2>/dev/null || true'
run 'docker rmi shopping-backend shopping-frontend toolbox 2>/dev/null || true'
run 'docker ps -a --filter name=shopping'
run "docker images --filter 'reference=shopping-*' --filter 'reference=toolbox'"
say "traefik:v3.6 stays – remove it with 'docker rmi traefik:v3.6' if you like."
