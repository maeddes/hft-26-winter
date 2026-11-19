#!/usr/bin/env bash
# Runs all steps of tutorials/01-docker-basics.md (except the optional push).
#
#   tutorials/scripts/01-docker-basics.sh           all at once
#   PAUSE=1 tutorials/scripts/01-docker-basics.sh   one command at a time
#   tutorials/scripts/01-cleanup.sh                 removes everything again

source "$(dirname "$0")/lib.sh"

step "2. Validation"
run 'docker version'

step "3. Pull images"
run 'docker pull hello-world'
run 'docker images'
run 'docker pull alpine:3.22'
run 'docker images'
say "Pull the same image again – nothing to download:"
run 'docker pull alpine:3.22'
run "docker image inspect alpine:3.22 --format '{{.Os}}/{{.Architecture}}'"
run 'uname -m'

step "4. Run containers from existing images"
run 'docker run hello-world'
run 'docker ps'
run 'docker ps -a'
say "Run the same image again – a second container:"
run 'docker run hello-world'
run 'docker ps -a'
run 'docker images'
say "Running containers did not change the images."
run 'docker run alpine:3.22'
run 'docker ps -a'
run 'docker run alpine:3.22 echo "Hello from inside a container"'
run 'docker ps -a'
run 'docker run --rm alpine:3.22 cat /etc/os-release'
run 'docker ps -a'
say "No new container – --rm removed it."
run 'docker run --rm alpine:3.22 uname -r'
run 'uname -r'

step "5. Find and remove containers"
run 'docker ps -aq'
run 'docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"'
run 'docker ps -a --filter status=exited'
ECHO_ID=$(docker ps -aq --filter ancestor=alpine:3.22 --filter status=exited | head -1)
SH_NAME=$(docker ps -a --filter ancestor=alpine:3.22 --format '{{.Names}}' | tail -1)
run "docker rm ${ECHO_ID:0:4}"
run "docker rm $SH_NAME"
run 'docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"'

step "6.1 Run nginx in the foreground"
show 'docker run nginx:1.29-alpine        (stopped with Ctrl+C after a few seconds)'
docker run nginx:1.29-alpine &
FG=$!
sleep 4
run 'docker ps'
run 'docker images'
fails 'curl -s localhost:80'
kill -INT "$FG"; wait "$FG" || true
run 'docker ps -a'

step "6.2 Run it in the background"
BG=$(docker run -d nginx:1.29-alpine)
show 'docker run -d nginx:1.29-alpine'
echo "$BG"
run 'docker ps'
run 'docker ps -a'
sleep 1
run "docker logs ${BG:0:4}"
fails 'curl -s localhost:80'
run "docker stop ${BG:0:4}"
run 'docker ps'
run 'docker ps -a'

step "6.3 Publish the port"
PUB=$(docker run -d -p 8080:80 nginx:1.29-alpine)
show 'docker run -d -p 8080:80 nginx:1.29-alpine'
echo "$PUB"
run 'docker ps'
sleep 1
run 'curl -s localhost:8080 | head -4'
run "docker logs ${PUB:0:4} | tail -1"
run "docker stop ${PUB:0:4}"
fails 'curl -s localhost:8080'

step "6.4 Give it a name"
run 'docker run -d --name web -p 8080:80 nginx:1.29-alpine'
run 'docker ps'
say "The same name a second time:"
fails 'docker run -d --name web -p 8081:80 nginx:1.29-alpine'
say "The same port a second time:"
fails 'docker run -d --name web2 -p 8080:80 nginx:1.29-alpine'
run 'docker ps -a --filter name=web'
run 'docker rm web2'
sleep 1
run 'docker logs web | tail -3'
run 'docker stop web'
fails 'curl -s localhost:8080'
run 'docker ps -a'
run 'docker start web'
sleep 1
run 'curl -s localhost:8080 | head -4'
fails 'docker rm web'
run 'docker rm -f web'

step "7. Tags and image IDs"
run 'docker images'
run 'docker tag alpine:3.22 my-alpine:demo'
run 'docker images'
run 'docker rmi my-alpine:demo'
run 'docker images'

step "8. Build your first image"
DIR=$(mktemp -d)
say "Working directory: $DIR"
run "echo 'Hello from my first image' > $DIR/hello.txt"
run "printf 'FROM alpine:3.22\nCOPY hello.txt /hello.txt\nCMD [\"cat\", \"/hello.txt\"]\n' > $DIR/Dockerfile"
run "cat $DIR/Dockerfile"
run "docker build -q -t hello-container:v1 $DIR"
run 'docker images'
run 'docker run hello-container:v1'
run 'docker ps -a --filter ancestor=hello-container:v1'
say "COMMAND is the CMD from the Dockerfile."
run 'docker run --rm hello-container:v1'
run 'docker ps -a --filter ancestor=hello-container:v1'

step "9. Images are immutable – build a new version"
run "echo 'Hello from version 2' > $DIR/hello.txt"
run 'docker run --rm hello-container:v1'
run "docker build -q -t hello-container:v2 $DIR"
run 'docker run --rm hello-container:v2'
run 'docker run --rm hello-container:v1'
run 'docker images'
rm -r "$DIR"

step "10. Share your image (optional)"
say "Skipped here: docker login, docker tag <your-docker-id>/hello-container:v2, docker push."

step "11. Clean up"
run 'docker ps -a'
fails 'docker rmi nginx:1.29-alpine'
say "A stopped container still uses the image."
run 'docker rm $(docker ps -aq --filter ancestor=nginx:1.29-alpine --filter status=exited)'
run 'docker rm $(docker ps -aq --filter ancestor=hello-world) $(docker ps -aq --filter ancestor=hello-container:v1)'
run 'docker ps -a'
run 'docker rmi hello-container:v1 hello-container:v2 hello-world'
run 'docker images'
say "alpine:3.22 and nginx:1.29-alpine stay for tutorial 03 – the tutorial removes them, too."
