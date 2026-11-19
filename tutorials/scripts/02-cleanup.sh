#!/usr/bin/env bash
# Removes what tutorial 02 created – and nothing else. No prune.
# The shopping-api/ folder stays: tutorial 08 builds on it.

source "$(dirname "$0")/lib.sh"

step "Clean up tutorial 02"
run 'docker rm -f api-v1 api-v2 api-v3 2>/dev/null || true'
run 'docker rm -f $(docker ps -aq --filter ancestor=shopping-api:v1 --filter ancestor=shopping-api:v2 --filter ancestor=shopping-api:v3) 2>/dev/null || true'
run 'docker rmi shopping-api:v1 shopping-api:v2 shopping-api:v3 shopping-api:broken 2>/dev/null || true'
run "docker images --filter 'reference=shopping-api'"
say "The base image python:3.12-slim stays. Your shopping-api/ folder stays, too – tutorial 08 uses it."
