#!/usr/bin/env bash
# Removes what tutorial 01 created – and nothing else. No prune.

source "$(dirname "$0")/lib.sh"

step "Clean up tutorial 01"
run 'docker rm -f web web2 2>/dev/null || true'
run 'docker rm -f $(docker ps -aq --filter ancestor=hello-world --filter ancestor=hello-container:v1 --filter ancestor=hello-container:v2 --filter ancestor=nginx:1.29-alpine --filter ancestor=alpine:3.22) 2>/dev/null || true'
run 'docker rmi hello-container:v1 hello-container:v2 my-alpine:demo hello-world 2>/dev/null || true'
run "docker images --filter 'reference=hello-*' --filter 'reference=my-alpine'"
say "The base images alpine:3.22 and nginx:1.29-alpine stay."
