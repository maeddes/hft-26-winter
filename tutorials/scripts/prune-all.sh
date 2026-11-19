#!/usr/bin/env bash
# Removes EVERYTHING from the Docker daemon this shell talks to – step by step,
# from gentle to crowbar:
#
#   1. stop all running containers
#   2. remove all containers
#   3. remove all networks you created (bridge, host and none stay)
#   4. remove all volumes
#   5. remove all images
#   6. crowbar: docker system prune -a --volumes and docker builder prune -a
#
#   tutorials/scripts/prune-all.sh        asks first
#   tutorials/scripts/prune-all.sh -y     no question – for a codespace you throw away anyway
#
# Meant for a codespace. On your own machine this deletes the containers, images
# and volumes of all your projects – that is why it asks for more than a "y" there.

source "$(dirname "$0")/lib.sh"

step "What is there"
run 'docker system df'

if [ "${1:-}" != "-y" ]; then
  if [ "${CODESPACES:-}" = "true" ]; then
    read -r -p "Remove ALL containers, networks, volumes, images and build cache? [y/N] " answer </dev/tty
    [ "$answer" = "y" ] || { say "Nothing removed."; exit 0; }
  else
    printf '%sThis is not a codespace. Everything of every project on this machine will be gone.%s\n' "$YELLOW" "$RESET"
    read -r -p "Type 'delete everything' to continue: " answer </dev/tty
    [ "$answer" = "delete everything" ] || { say "Nothing removed."; exit 0; }
  fi
fi

step "1. Stop all running containers (soft)"
if [ -n "$(docker ps -q)" ]; then
  run 'docker stop $(docker ps -q)'
else
  say "Nothing running."
fi
run 'docker ps -a'

step "2. Remove all containers"
if [ -n "$(docker ps -aq)" ]; then
  run 'docker rm -f $(docker ps -aq)'
else
  say "No containers."
fi
run 'docker ps -a'

step "3. Remove all networks you created"
if [ -n "$(docker network ls -q --filter type=custom)" ]; then
  run 'docker network rm $(docker network ls -q --filter type=custom)'
else
  say "No networks of your own."
fi
run 'docker network ls'

step "4. Remove all volumes"
if [ -n "$(docker volume ls -q)" ]; then
  run 'docker volume rm -f $(docker volume ls -q)'
else
  say "No volumes."
fi
run 'docker volume ls'

step "5. Remove all images"
if [ -n "$(docker images -aq)" ]; then
  run 'docker rmi -f $(docker images -aq | sort -u)'
else
  say "No images."
fi
run 'docker images'

step "6. Crowbar: whatever is left, including the build cache"
run 'docker system prune -a -f --volumes'
run 'docker builder prune -a -f'

step "Done"
run 'docker system df'
