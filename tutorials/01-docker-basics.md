# Docker Basics – Step by Step

## 1. About

This walkthrough covers the Docker basics on the command line: pulling images, running containers, inspecting and removing them, and building a first image of your own.

Every code block contains **exactly one command** – copy it, paste it, run it, then compare with the expected output. Outputs will differ in IDs, timestamps and versions; that is fine.

### 1.1 Prerequisites

Recommended: a GitHub Codespace. Open this repository on GitHub, click **Code → Codespaces → Create codespace on main**. Docker is preinstalled.

Alternatively: Docker Desktop (macOS, Windows) or Docker Engine (Linux) on your own machine.

## 2. Validation

Validate the Docker installation:

```bash
docker version
```

Should display output like (versions might differ):

```text
Client:
 Version:           29.3.1
 API version:       1.54
 ...
Server:
 Engine:
  Version:          29.3.1
  API version:      1.54 (minimum version 1.40)
  ...
```

You need to see both parts: the **Client** (the `docker` command you type) and the **Server** (the Docker daemon that does the work). If the server part is missing, the daemon is not running.

## 3. Pull images

Pull the smallest possible image:

```bash
docker pull hello-world
```

Should display output like:

```text
Using default tag: latest
latest: Pulling from library/hello-world
...
Status: Downloaded newer image for hello-world:latest
docker.io/library/hello-world:latest
```

Without a tag, Docker uses `latest`. Pull a second image, this time with an explicit tag:

```bash
docker pull alpine:3.22
```

List the images in your local image store:

```bash
docker images
```

Should display output like:

```text
IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
alpine:3.22          062964a69725       8.54MB             0B
hello-world:latest   eb84fdc6f2a3        5.2kB             0B
```

Alpine is a minimal Linux distribution – less than 10 MB.

## 4. Run containers from existing images

Run the hello-world image:

```bash
docker run hello-world
```

Should display output like:

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
...
```

Read the four steps in the output – they describe exactly what just happened.

Run a single command in an Alpine container:

```bash
docker run alpine:3.22 echo "Hello from inside a container"
```

```text
Hello from inside a container
```

Find out which operating system the container sees:

```bash
docker run --rm alpine:3.22 cat /etc/os-release
```

```text
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.22.8
PRETTY_NAME="Alpine Linux v3.22"
...
```

`--rm` removes the container as soon as it exits.

Now compare the kernel version inside a container ...

```bash
docker run --rm alpine:3.22 uname -r
```

... with the kernel version of your machine:

```bash
uname -r
```

In a codespace both are identical: the container uses the kernel of its host – it does not bring its own. On macOS or Windows, the container shows the kernel of the small Linux VM that Docker Desktop runs in the background (e.g. `6.12.76-linuxkit`).

### 4.1 Interactive container

Start a shell inside a container:

```bash
docker run -it --rm alpine:3.22 sh
```

The prompt changes to `/ #`. You are now inside the container. Try:

```bash
hostname
```

```bash
ps
```

`ps` shows only the processes of this container – starting with `sh` as process 1. Leave the container:

```bash
exit
```

## 5. List and remove containers

List running containers:

```bash
docker ps
```

```text
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

Nothing is running: every container so far ran one command and exited. List all containers, including stopped ones:

```bash
docker ps -a
```

Should display output like:

```text
CONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS                     PORTS     NAMES
87dd75f6889b   alpine:3.22   "echo 'Hello from in…"   1 minute ago    Exited (0) 1 minute ago              hungry_dhawan
70732510b6f7   hello-world   "/hello"                 2 minutes ago   Exited (0) 2 minutes ago             infallible_torvalds
```

The containers started with `--rm` are gone; the others are still there. Docker generated random names for them.

Remove one container by its ID – the first few characters are enough, as long as they are unique (use an ID from *your* output):

```bash
docker rm 87dd
```

Remove all stopped containers at once (confirm with `y`):

```bash
docker container prune
```

## 6. A long-running container: a web server

Start nginx in the background (`-d`), give it a name, and publish its port 80 as port 8080 on your machine:

```bash
docker run -d --name web -p 8080:80 nginx:1.29-alpine
```

Docker prints the full container ID. Check that it is running:

```bash
docker ps
```

```text
CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS         PORTS                                     NAMES
9b2789d81f72   nginx:1.29-alpine   "/docker-entrypoint.…"   5 seconds ago   Up 4 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   web
```

Call the web server:

```bash
curl localhost:8080
```

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

In a codespace you can also open the **Ports** tab and open port 8080 in the browser.

Look at the logs of the container – your `curl` request is at the end:

```bash
docker logs web
```

```text
...
192.168.65.1 - - [07/Nov/2026:10:10:02 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.7.1" "-"
```

Run a command inside the running container:

```bash
docker exec web ls /usr/share/nginx/html
```

```text
50x.html
index.html
```

Stop the container:

```bash
docker stop web
```

It is not running any more, but it still exists:

```bash
docker ps -a
```

Start it again – same container, same name, same configuration:

```bash
docker start web
```

Try to remove it while it is running:

```bash
docker rm web
```

```text
Error response from daemon: cannot remove container "web": container is running: stop the container before removing or force remove
```

Force the removal (`-f` stops and removes in one step):

```bash
docker rm -f web
```

## 7. Tags and image IDs

Give an existing image a second name:

```bash
docker tag alpine:3.22 my-alpine:demo
```

```bash
docker images
```

```text
IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
alpine:3.22          062964a69725       8.54MB             0B
my-alpine:demo       062964a69725       8.54MB             0B
...
```

Both names show the **same ID**: a tag is just a pointer to an image. Nothing was copied.

Remove the new name:

```bash
docker rmi my-alpine:demo
```

```text
Untagged: my-alpine:demo
```

Only the name is gone – `alpine:3.22` and the image itself are still there.

## 8. Build your first image

Create a working directory and change into it:

```bash
mkdir hello-container
```

```bash
cd hello-container
```

Create a text file:

```bash
echo "Hello from my first image" > hello.txt
```

Create a file named `Dockerfile` (in a codespace, this command opens it in the editor):

```bash
code Dockerfile
```

Paste this content and save:

```dockerfile
FROM alpine:3.22
COPY hello.txt /hello.txt
CMD ["cat", "/hello.txt"]
```

- `FROM` – the base image
- `COPY` – copies a file from your directory into the image
- `CMD` – the command a container runs when it starts

Build the image and tag it as `hello-container:v1`. The `.` at the end is the build context – the directory whose files `COPY` can see:

```bash
docker build -t hello-container:v1 .
```

The output ends with a line like:

```text
 => => naming to docker.io/library/hello-container:v1
```

```bash
docker images
```

```text
IMAGE                   ID             DISK USAGE   CONTENT SIZE   EXTRA
hello-container:v1      4284bbcd5402       8.54MB             0B
...
```

Run it:

```bash
docker run --rm hello-container:v1
```

```text
Hello from my first image
```

Look at the layers of your image:

```bash
docker history hello-container:v1
```

Should display output like:

```text
IMAGE          CREATED          CREATED BY                          SIZE      COMMENT
4284bbcd5402   1 minute ago     CMD ["cat" "/hello.txt"]            0B        buildkit.dockerfile.v0
<missing>      1 minute ago     COPY hello.txt /hello.txt # build…  26B       buildkit.dockerfile.v0
<missing>      3 weeks ago      CMD ["/bin/sh"]                     0B
<missing>      3 weeks ago      ADD alpine-minirootfs-3.22.8-…      8.5MB
```

Read it bottom-up: the Alpine layers, then your `COPY` layer with just a few bytes. `CMD` adds no files, only metadata (0B).

## 9. Images are immutable – build a new version

Change the text file:

```bash
echo "Hello from version 2" > hello.txt
```

Run the existing image again:

```bash
docker run --rm hello-container:v1
```

```text
Hello from my first image
```

Still the old text: the file was copied into the image at build time. Changing it on disk does not change the image. Build a new version:

```bash
docker build -t hello-container:v2 .
```

```bash
docker run --rm hello-container:v2
```

```text
Hello from version 2
```

```bash
docker images
```

`v1` and `v2` have different IDs. They share the Alpine layers – those are stored only once.

## 10. Changes inside a container stay in that container

Start a container with a shell and keep it after it exits (no `--rm` this time):

```bash
docker run -it --name playground hello-container:v2 sh
```

Inside the container, change the file:

```bash
echo "changed inside the container" > /hello.txt
```

```bash
cat /hello.txt
```

```bash
exit
```

Ask Docker what has changed in this container compared to its image:

```bash
docker diff playground
```

```text
C /hello.txt
...
```

`C` stands for *changed*. Now start a fresh container from the same image:

```bash
docker run --rm hello-container:v2
```

```text
Hello from version 2
```

The change only exists in the writable layer of the container `playground` – the image is untouched. Remove the container:

```bash
docker rm playground
```

## 11. Clean up

Go back to the parent directory:

```bash
cd ..
```

Remove your images:

```bash
docker rmi hello-container:v1 hello-container:v2
```

Remove all stopped containers:

```bash
docker container prune
```

See how much space Docker uses:

```bash
docker system df
```

## 12. Overview

| Command | What it does |
|---|---|
| `docker version` | shows client and server versions |
| `docker pull <image>:<tag>` | downloads an image from a registry |
| `docker images` | lists images in the local image store |
| `docker run <image>` | creates and starts a container (pulls the image if it is missing) |
| `docker run --rm` / `-d` / `-it` / `-p` / `--name` | remove on exit / background / interactive / publish a port / name it |
| `docker ps` / `docker ps -a` | lists running / all containers |
| `docker logs <container>` | shows the output of a container |
| `docker exec <container> <command>` | runs a command in a running container |
| `docker stop` / `docker start` / `docker rm` | stops / starts / removes a container |
| `docker tag <image> <new-name>` | adds a name to an image |
| `docker rmi <image>` | removes a name, and the image once no name is left |
| `docker build -t <name>:<tag> <context>` | builds an image from a Dockerfile |
| `docker history <image>` | shows the layers of an image |
| `docker diff <container>` | shows what changed in a container |

Next: [02 – A REST API in a container](02-rest-api-in-a-container.md)
