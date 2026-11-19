#!/usr/bin/env bash
# Runs all steps of tutorials/03-looking-inside-containers.md.
# Interactive steps (-it) are replayed with piped input or `docker exec ... sh -c`.
#
#   tutorials/scripts/03-looking-inside-containers.sh           all at once
#   PAUSE=1 tutorials/scripts/03-looking-inside-containers.sh   one command at a time
#   tutorials/scripts/03-cleanup.sh                             removes everything again

source "$(dirname "$0")/lib.sh"

step "2. A container that runs one command"
run 'docker run alpine:3.22'
run 'docker ps'
run 'docker ps -a --filter ancestor=alpine:3.22'
say "Exited right away. Once more – a second container:"
run 'docker run alpine:3.22'
run 'docker ps -a --filter ancestor=alpine:3.22'
say "A command after the image name replaces the default command:"
run 'docker run alpine:3.22 hostname'
run 'docker ps -a --filter ancestor=alpine:3.22'
say "The hostname is the ID of the newest container."
run 'docker run alpine:3.22 whoami'
run 'whoami'
run 'docker run alpine:3.22 cat /etc/os-release'
run 'docker ps -a --filter ancestor=alpine:3.22'
say "Five runs, five containers, all exited. Remove them:"
run 'docker rm $(docker ps -aq --filter ancestor=alpine:3.22)'
run 'docker ps -a --filter ancestor=alpine:3.22'

step "3. Input and a terminal: -i and -t"
run 'docker run alpine:3.22 sh'
run 'echo hostname | docker run alpine:3.22 sh'
say "Nothing – without -i the input does not reach the container."
run 'echo hostname | docker run -i alpine:3.22 sh'
run 'docker ps -a --filter ancestor=alpine:3.22'
say "Replaying 'docker run -it --name shell alpine:3.22 sh' with piped input:"
run "printf 'hostname\nps\ntouch /tmp/hello\n' | docker run -i --name shell alpine:3.22 sh"
run 'docker ps'
run 'docker ps -a --filter name=shell'
say "The input ended, the shell ended, the container stopped. Start it again:"
run "echo 'ls /tmp' | docker start -ai shell"
say "The file survived the stop – the container's file system is kept until it is removed."
run 'docker rm shell'
run 'docker rm $(docker ps -aq --filter ancestor=alpine:3.22)'
run 'docker ps -a --filter ancestor=alpine:3.22'

step "4. Into a running container: docker exec"
run 'docker run -d --name web -p 8080:80 nginx:1.29-alpine'
run 'docker ps'
run 'sleep 1; curl -s localhost:8080 | grep "<title>"'
run 'docker exec web hostname'
run 'docker exec web ls /usr/share/nginx/html'
run 'docker exec web ps'
run 'docker top web'
run 'docker ps -a --filter name=web'
say "Still one container – exec starts a process, not a container."

step "5. The writable layer"
run 'docker diff web'
say "Replaying 'docker exec -it web sh' and the echo inside it:"
run "docker exec web sh -c 'echo \"<h1>Changed inside the container</h1>\" > /usr/share/nginx/html/index.html'"
run 'curl -s localhost:8080'
run 'docker diff web'
say "New line: C /usr/share/nginx/html/index.html"
run 'docker run -d --name web2 -p 8081:80 nginx:1.29-alpine'
run 'docker ps'
run 'sleep 1; curl -s localhost:8081 | grep "<title>"'
run 'docker diff web2'
say "Stop and start keep the writable layer:"
run 'docker stop web'
run 'docker ps'
run 'docker ps -a --filter name=web'
fails 'curl -s localhost:8080'
run 'docker start web'
run 'sleep 1; curl -s localhost:8080'
run 'docker rm -f web2'

step "6. Turning a container into an image"
run "docker images --filter 'reference=*nginx*'"
run 'docker commit web my-nginx:changed'
run "docker images --filter 'reference=*nginx*'"
run 'docker run -d --name web3 -p 8082:80 my-nginx:changed'
run 'docker ps'
run 'sleep 1; curl -s localhost:8082'
run 'docker history my-nginx:changed'
say "Remove web and start a fresh one from the original image:"
run 'docker rm -f web'
run 'docker run -d --name web -p 8080:80 nginx:1.29-alpine'
run 'sleep 1; curl -s localhost:8080 | grep "<title>"'
run 'sleep 1; curl -s localhost:8082'

step "7. The reproducible way: a Dockerfile"
DIR=$(mktemp -d)
say "Working directory: $DIR"
run "echo '<h1>Built from a Dockerfile</h1>' > $DIR/index.html"
run "printf 'FROM nginx:1.29-alpine\nCOPY index.html /usr/share/nginx/html/index.html\n' > $DIR/Dockerfile"
run "cat $DIR/Dockerfile"
run "docker build -q -t my-nginx:v1 $DIR"
run "docker images --filter 'reference=*nginx*'"
run 'docker run -d --name web4 -p 8083:80 my-nginx:v1'
run 'docker ps'
run 'sleep 1; curl -s localhost:8083'
run 'docker history my-nginx:v1'
run 'docker history nginx:1.29-alpine'
run 'docker history my-nginx:changed'
rm -r "$DIR"

step "Done"
say "Running: web (8080), web3 (8082), web4 (8083). Clean up with tutorials/scripts/03-cleanup.sh"
