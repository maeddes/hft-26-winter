# Docker Basics – Step by Step

## 1. About

This walkthrough covers the Docker basics from the lectures on 30 Oct and 6 Nov: pulling images, running and removing containers, publishing a port, tags, and building a first image of your own.

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
 Version:           29.9.2-2
 API version:       1.56
 Go version:        go1.27.3
 Git commit:        a82e528901260c8df6073311379eac65f92db204
 Built:             Thu Oct 22 00:00:00 2026
 OS/Arch:           linux/amd64
 Context:           default

Server:
 Engine:
  Version:          29.9.2-2
  API version:      1.56 (minimum version 1.40)
  Go version:       go1.27.3
  Git commit:       0367cbeb49b9d98cb0b4f51e95f7b54b4803e76c
  Built:            Thu Oct 22 00:00:00 2026
  OS/Arch:          linux/amd64
  Experimental:     false
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
alpine:3.22          bfe7ceb9f09e       12.9MB         3.88MB
hello-world:latest   c567b231f656       25.9kB         9.49kB
```

Alpine is a minimal Linux distribution – just a few megabytes.

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

List the running containers:

```bash
docker ps
```

```text
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

Nothing is running. List all containers, including stopped ones:

```bash
docker ps -a
```

```text
CONTAINER ID   IMAGE         COMMAND    CREATED          STATUS                      PORTS     NAMES
70732510b6f7   hello-world   "/hello"   30 seconds ago   Exited (0) 29 seconds ago             infallible_torvalds
```

The container still exists, but it has exited: it ran its command `/hello`, printed the message and was done. Docker generated a random name for it.

Now run Alpine without any further arguments:

```bash
docker run alpine:3.22
```

Nothing seems to happen – you get your prompt back right away. Look again:

```bash
docker ps -a
```

```text
CONTAINER ID   IMAGE         COMMAND     CREATED          STATUS                      PORTS     NAMES
5e3a1c9d8b27   alpine:3.22   "/bin/sh"   5 seconds ago    Exited (0) 4 seconds ago              quirky_lovelace
70732510b6f7   hello-world   "/hello"    1 minute ago     Exited (0) 1 minute ago               infallible_torvalds
```

A container was created and started. Its command is `/bin/sh`, the default command defined in the Alpine image. A shell without anyone typing into it has nothing to do – so it exited immediately.

Now give the container a command of your own. Everything after the image name **replaces** the default command:

```bash
docker run alpine:3.22 echo "Hello from inside a container"
```

```text
Hello from inside a container
```

```bash
docker ps -a
```

```text
CONTAINER ID   IMAGE         COMMAND                  CREATED          STATUS                      PORTS     NAMES
87dd75f6889b   alpine:3.22   "echo 'Hello from in…"   5 seconds ago    Exited (0) 4 seconds ago              hungry_dhawan
5e3a1c9d8b27   alpine:3.22   "/bin/sh"                1 minute ago     Exited (0) 1 minute ago               quirky_lovelace
70732510b6f7   hello-world   "/hello"                 2 minutes ago    Exited (0) 2 minutes ago              infallible_torvalds
```

Same image, different command: this time the container ran `echo` instead of `/bin/sh`.

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

`--rm` removes the container as soon as it exits – it will not show up in `docker ps -a`.

Now compare the kernel version inside a container ...

```bash
docker run --rm alpine:3.22 uname -r
```

... with the kernel version of your machine:

```bash
uname -r
```

In a codespace both are identical: the container uses the kernel of its host – it does not bring its own. On macOS or Windows, the container shows the kernel of the small Linux VM that Docker Desktop runs in the background (e.g. `6.12.76-linuxkit`).

## 5. Remove containers

The stopped containers are still listed in `docker ps -a`. Remove one by its ID – the first few characters are enough, as long as they are unique (use an ID from *your* output):

```bash
docker rm 87dd
```

You can also use the name:

```bash
docker rm quirky_lovelace
```

```bash
docker ps -a
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
alpine:3.22          bfe7ceb9f09e       12.9MB         3.88MB
my-alpine:demo       bfe7ceb9f09e       12.9MB         3.88MB
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
hello-container:v1      4284bbcd5402       12.9MB         3.88MB
...
```

Run it:

```bash
docker run --rm hello-container:v1
```

```text
Hello from my first image
```

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

## 10. Share your image (optional)

This needs a free Docker ID from [hub.docker.com](https://hub.docker.com). Log in – the CLI suggests using a Personal Access Token instead of your password:

```bash
docker login -u <your-docker-id>
```

Give the image a name that starts with your Docker ID:

```bash
docker tag hello-container:v2 <your-docker-id>/hello-container:v2
```

Push it to Docker Hub:

```bash
docker push <your-docker-id>/hello-container:v2
```

Anyone can now run your image – on a machine with the same CPU architecture:

```bash
docker run --rm <your-docker-id>/hello-container:v2
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

## 12. Overview

| Command | What it does |
|---|---|
| `docker version` | shows client and server versions |
| `docker pull <image>:<tag>` | downloads an image from a registry |
| `docker images` | lists images in the local image store |
| `docker run <image>` | creates and starts a container (pulls the image if it is missing) |
| `docker run --rm` / `-d` / `-p` / `--name` | remove on exit / background / publish a port / name it |
| `docker ps` / `docker ps -a` | lists running / all containers |
| `docker logs <container>` | shows the output of a container |
| `docker stop` / `docker start` / `docker rm` | stops / starts / removes a container |
| `docker tag <image> <new-name>` | adds a name to an image |
| `docker rmi <image>` | removes a name, and the image once no name is left |
| `docker build -t <name>:<tag> <context>` | builds an image from a Dockerfile |
| `docker login` / `docker push <image>` | logs in to a registry / uploads an image |

Next: [02 – A REST API in a Container](02-rest-api-in-a-container.md) · [03 – Looking Inside Containers](03-looking-inside-containers.md)
