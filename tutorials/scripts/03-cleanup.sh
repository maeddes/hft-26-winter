#!/usr/bin/env bash
# Removes what tutorial 03 created – and nothing else. No prune.

source "$(dirname "$0")/lib.sh"

step "Clean up tutorial 03"
run 'docker rm -f web web2 web3 web4 shell 2>/dev/null || true'
run 'docker rm $(docker ps -aq --filter ancestor=alpine:3.22) 2>/dev/null || true'
run 'docker rmi my-nginx:changed my-nginx:v1 2>/dev/null || true'
run 'docker ps -a --filter ancestor=alpine:3.22 --filter ancestor=nginx:1.29-alpine'
run "docker images --filter 'reference=my-nginx'"
say "The base images alpine:3.22 and nginx:1.29-alpine stay."
