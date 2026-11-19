#!/usr/bin/env bash
# Runs the steps of tutorials/05-cleaning-up.md that are safe on any machine:
# everything the tutorial creates carries the label tutorial=05, and every prune
# here is filtered by that label. The commands that remove *everything* are only
# printed (marked "not run"), never executed.
#
#   tutorials/scripts/05-cleaning-up.sh           all at once
#   PAUSE=1 tutorials/scripts/05-cleaning-up.sh   one command at a time
#   tutorials/scripts/05-cleanup.sh               removes leftovers if the script stopped halfway

source "$(dirname "$0")/lib.sh"

L='--filter label=tutorial=05'
not_run() { show "$1        (not run here – removes everything unused)"; }
DIR=$(mktemp -d)
trap 'rm -rf "$DIR"' EXIT

step "2. Make some mess"
run 'docker run --label tutorial=05 alpine:3.22 echo one'
run 'docker run --label tutorial=05 alpine:3.22 echo two'
run 'docker run -d --label tutorial=05 --name mess-web nginx:1.29-alpine'
run 'docker run --label tutorial=05 --name mess-anon -v /data alpine:3.22 true'
ANON=$(docker inspect --format '{{range .Mounts}}{{.Name}}{{end}}' mess-anon)
run "printf 'FROM alpine:3.22\nARG N\nRUN echo \$N > /n\n' > $DIR/Dockerfile"
run "cat $DIR/Dockerfile"
run "docker build -q --label tutorial=05 --build-arg N=1 -t mess $DIR"
run "docker build -q --label tutorial=05 --build-arg N=2 -t mess $DIR"
run 'docker network create --label tutorial=05 mess-net'
run 'docker volume create --label tutorial=05 mess-data'

step "3. Look first"
run 'docker system df'
run "docker ps -a $L"
run "docker images $L"
run "docker images --filter dangling=true $L"
run "docker network ls $L"
run "docker volume ls $L"
run "docker volume ls --filter name=$ANON"
say "The anonymous volume of mess-anon has no label – volumes do not inherit the container's labels."

step "4. Containers"
run "docker ps -aq --filter status=exited $L"
run "docker container prune -f $L"
run "docker ps -a $L"
say "mess-web is still running – prune only removes stopped containers."
run 'docker rm -f mess-web'
run "docker ps -a $L"
not_run 'docker container prune'
not_run 'docker rm -f $(docker ps -aq)'

step "5. Images"
run "docker images $L"
run "docker image prune -f $L"
run "docker images $L"
say "The dangling one is gone, mess:latest is still there – it has a name."
run "docker image prune -a -f $L"
run "docker images $L"
not_run 'docker image prune'
not_run 'docker image prune -a'

step "6. Networks"
run "docker network ls $L"
run "docker network prune -f $L"
run "docker network ls $L"
not_run 'docker network prune'

step "7. Volumes"
run "docker volume ls $L"
run "docker volume prune -f $L"
run "docker volume ls $L"
say "Still there – without -a, prune leaves named volumes alone."
run "docker volume prune -a -f $L"
run "docker volume ls $L"
run "docker volume ls --filter dangling=true --filter name=$ANON"
say "The anonymous volume is left. It has no label, so remove it by name:"
run "docker volume rm $ANON"
not_run 'docker volume prune'
not_run 'docker volume prune -a'

step "8. Build cache"
run 'docker system df'
not_run 'docker builder prune'

step "9. Everything at once"
not_run 'docker system prune'
not_run 'docker system prune -a --volumes'
run 'docker system df'
