#!/usr/bin/env bash
# Removes what tutorial 04 created – and nothing else. No prune.

source "$(dirname "$0")/lib.sh"

step "Clean up tutorial 04"
run 'docker rm -f frontend backend toolbox 2>/dev/null || true'
run 'docker network rm shop-net 2>/dev/null || true'
run 'docker rmi shopping-frontend shopping-backend toolbox 2>/dev/null || true'
run 'docker network ls --filter name=shop-net'
run "docker images --filter 'reference=shopping-*' --filter 'reference=toolbox'"
say "Delete code/frontend-flask/.venv yourself if you created it in section 3."
