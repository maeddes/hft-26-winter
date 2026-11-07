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

> **Output**
> ```text
> Client:
>  Version:           29.9.2-2
>  API version:       1.56
>  Go version:        go1.27.3
>  Git commit:        a82e528901260c8df6073311379eac65f92db204
>  Built:             Thu Oct 22 00:00:00 2026
>  OS/Arch:           linux/amd64
>  Context:           default
>
> Server:
>  Engine:
>   Version:          29.9.2-2
>   API version:      1.56 (minimum version 1.40)
>   Go version:       go1.27.3
>   Git commit:       0367cbeb49b9d98cb0b4f51e95f7b54b4803e76c
>   Built:            Thu Oct 22 00:00:00 2026
>   OS/Arch:          linux/amd64
>   Experimental:     false
>  ...
> ```

You need to see both parts: the **Client** (the `docker` command you type) and the **Server** (the Docker daemon that does the work). If the server part is missing, the daemon is not running.

## 3. Pull images

Pull the smallest possible image:

```bash
docker pull hello-world
```

Should display output like:

> **Output**
> ```text
> Using default tag: latest
> latest: Pulling from library/hello-world
> ...
> Status: Downloaded newer image for hello-world:latest
> docker.io/library/hello-world:latest
> ```

Without a tag, Docker uses `latest`. Pull a second image, this time with an explicit tag:

```bash
docker pull alpine:3.22
```

List the images in your local image store:

```bash
docker images
```

Should display output like:

> **Output**
> ```text
> IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
> alpine:3.22          bfe7ceb9f09e       12.9MB         3.88MB
> hello-world:latest   c567b231f656       25.9kB         9.49kB
> ```

Alpine is a minimal Linux distribution – just a few megabytes.

## 4. Run containers from existing images

Run the hello-world image:

```bash
docker run hello-world
```

Should display output like:

> **Output**
> ```text
> Hello from Docker!
> This message shows that your installation appears to be working correctly.
> ...
> ```

Read the four steps in the output – they describe exactly what just happened.

List the running containers:

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
> ```

Nothing is running. List all containers, including stopped ones:

```bash
docker ps -a
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND    CREATED          STATUS                      PORTS     NAMES
> 70732510b6f7   hello-world   "/hello"   30 seconds ago   Exited (0) 29 seconds ago             infallible_torvalds
> ```

The container still exists, but it has exited: it ran its command `/hello`, printed the message and was done.

**Your CONTAINER ID and NAME will be different.** Docker generates both for every new container – the ID as a random hash, the name from an adjective and the name of a scientist. All IDs and names in this tutorial are examples.

Now run Alpine without any further arguments:

```bash
docker run alpine:3.22
```

Nothing seems to happen – you get your prompt back right away. Look again:

```bash
docker ps -a
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND     CREATED          STATUS                      PORTS     NAMES
> 5e3a1c9d8b27   alpine:3.22   "/bin/sh"   5 seconds ago    Exited (0) 4 seconds ago              quirky_lovelace
> 70732510b6f7   hello-world   "/hello"    1 minute ago     Exited (0) 1 minute ago               infallible_torvalds
> ```

A container was created and started. Its command is `/bin/sh`, the default command defined in the Alpine image. A shell without anyone typing into it has nothing to do – so it exited immediately.

Now give the container a command of your own. Everything after the image name **replaces** the default command:

```bash
docker run alpine:3.22 echo "Hello from inside a container"
```

> **Output**
> ```text
> Hello from inside a container
> ```

```bash
docker ps -a
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND                  CREATED          STATUS                      PORTS     NAMES
> 87dd75f6889b   alpine:3.22   "echo 'Hello from in…"   5 seconds ago    Exited (0) 4 seconds ago              hungry_dhawan
> 5e3a1c9d8b27   alpine:3.22   "/bin/sh"                1 minute ago     Exited (0) 1 minute ago               quirky_lovelace
> 70732510b6f7   hello-world   "/hello"                 2 minutes ago    Exited (0) 2 minutes ago              infallible_torvalds
> ```

Same image, different command: this time the container ran `echo` instead of `/bin/sh`.

Find out which operating system the container sees:

```bash
docker run --rm alpine:3.22 cat /etc/os-release
```

> **Output**
> ```text
> NAME="Alpine Linux"
> ID=alpine
> VERSION_ID=3.22.8
> PRETTY_NAME="Alpine Linux v3.22"
> ...
> ```

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

## 5. Find and remove containers

The stopped containers are still there. Before removing one, you need its ID or name – `docker ps` has options to show just that.

Only the IDs (`-q` for *quiet*):

```bash
docker ps -aq
```

> **Output**
> ```text
> 87dd75f6889b
> 5e3a1c9d8b27
> 70732510b6f7
> ```

Only the columns you are interested in:

```bash
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
```

> **Output**
> ```text
> CONTAINER ID   NAMES                 STATUS
> 87dd75f6889b   hungry_dhawan         Exited (0) 3 minutes ago
> 5e3a1c9d8b27   quirky_lovelace       Exited (0) 4 minutes ago
> 70732510b6f7   infallible_torvalds   Exited (0) 5 minutes ago
> ```

Only the stopped ones:

```bash
docker ps -a --filter status=exited
```

Now pick **one ID from your own list** and remove that container. The first few characters are enough, as long as they are unique:

```bash
docker rm 87dd
```

Docker answers with what you typed. Pick **one name from your own list** and remove that container, too:

```bash
docker rm quirky_lovelace
```

Check the result:

```bash
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
```

> **Output**
> ```text
> CONTAINER ID   NAMES                 STATUS
> 70732510b6f7   infallible_torvalds   Exited (0) 6 minutes ago
> ```

The IDs and names in this tutorial are examples – yours are different, so copying `87dd` or `quirky_lovelace` will fail with `No such container`.

## 6. A long-running container: a web server

So far every container ran one command and exited. A web server is different: it keeps running and waits for requests. In this section you start the same image several times, each time with one more option.

### 6.1 Run it in the foreground

Start nginx without any options:

```bash
docker run nginx:1.29-alpine
```

Should display output like:

> **Output**
> ```text
> /docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
> ...
> 2026/11/07 10:10:00 [notice] 1#1: nginx/1.29.3
> 2026/11/07 10:10:00 [notice] 1#1: start worker processes
> 2026/11/07 10:10:00 [notice] 1#1: start worker process 30
> ```

The output of the container appears directly in your terminal, and you don't get your prompt back: the container is running in the foreground. **Open a second terminal** (in a codespace: the **+** in the terminal panel) and list the running containers:

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED          STATUS          PORTS     NAMES
> 3f9c2a7b1d4e   nginx:1.29-alpine   "/docker-entrypoint.…"   20 seconds ago   Up 19 seconds   80/tcp    eager_hopper
> ```

Running, listening on port `80/tcp`. Try to reach it:

```bash
curl localhost:80
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 80 after 0 ms: Couldn't connect to server
> ```

nginx listens on port 80 – but *inside* the container. We come back to this in a moment.

Go back to the **first terminal** and stop the container with **Ctrl+C**. You get your prompt back. In either terminal:

```bash
docker ps -a
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS                     PORTS     NAMES
> 3f9c2a7b1d4e   nginx:1.29-alpine   "/docker-entrypoint.…"   1 minute ago    Exited (0) 5 seconds ago             eager_hopper
> ...
> ```

Ctrl+C stopped the process – and with it the container.

### 6.2 Run it in the background

Start nginx again, this time detached (`-d`):

```bash
docker run -d nginx:1.29-alpine
```

> **Output**
> ```text
> b81e4c6a2f9d0c3e7a5b1d8f2e6c4a9b7d3f1e5c8a2b6d4f9e1c7a3b5d8f2e6c
> ```

Docker prints the full ID of the new container and gives you the prompt back right away. The container runs in the background.

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS         PORTS     NAMES
> b81e4c6a2f9d   nginx:1.29-alpine   "/docker-entrypoint.…"   5 seconds ago   Up 4 seconds   80/tcp    sharp_babbage
> ```

`docker ps` shows only the running container. `docker ps -a` shows both – the new running one and the stopped one from before:

```bash
docker ps -a
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS                     PORTS     NAMES
> b81e4c6a2f9d   nginx:1.29-alpine   "/docker-entrypoint.…"   10 seconds ago  Up 9 seconds               80/tcp    sharp_babbage
> 3f9c2a7b1d4e   nginx:1.29-alpine   "/docker-entrypoint.…"   2 minutes ago   Exited (0) 1 minute ago              eager_hopper
> ...
> ```

Two different containers from the same image. Where did the output go? It is still collected – look at the logs (use the ID from *your* output):

```bash
docker logs b81e
```

> **Output**
> ```text
> ...
> 2026/11/07 10:12:00 [notice] 1#1: start worker processes
> 2026/11/07 10:12:00 [notice] 1#1: start worker process 30
> ```

nginx is up and listening. Try again:

```bash
curl localhost:80
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 80 after 0 ms: Couldn't connect to server
> ```

Still no connection – running in the background does not change the isolation. Stop the container:

```bash
docker stop b81e
```

### 6.3 Publish the port

Start a new container and publish container port 80 as port 8080 on your machine (`-p <host-port>:<container-port>`):

```bash
docker run -d -p 8080:80 nginx:1.29-alpine
```

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS         PORTS                                     NAMES
> c4d7e2a9f1b3   nginx:1.29-alpine   "/docker-entrypoint.…"   5 seconds ago   Up 4 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   tender_curie
> ```

The `PORTS` column now shows an arrow: port 8080 on your machine leads to port 80 in the container.

```bash
curl localhost:8080
```

> **Output**
> ```text
> <!DOCTYPE html>
> <html>
> <head>
> <title>Welcome to nginx!</title>
> ...
> ```

It works. In a codespace you can also open the **Ports** tab and open port 8080 in the browser. Your request now shows up in the logs:

```bash
docker logs c4d7
```

> **Output**
> ```text
> ...
> 172.17.0.1 - - [07/Nov/2026:10:14:02 +0000] "GET / HTTP/1.1" 200 896 "-" "curl/8.5.0" "-"
> ```

Stop it:

```bash
docker stop c4d7
```

### 6.4 Give it a name

Looking up IDs gets tedious. Start one more container, this time with a name:

```bash
docker run -d --name web -p 8080:80 nginx:1.29-alpine
```

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS         PORTS                                     NAMES
> 9b2789d81f72   nginx:1.29-alpine   "/docker-entrypoint.…"   5 seconds ago   Up 4 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   web
> ```

The `NAMES` column shows `web` instead of a random name. From now on you can use the name instead of the ID:

```bash
docker logs web
```

```bash
docker stop web
```

It is not running any more, but it still exists – together with the containers from before:

```bash
docker ps -a
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED          STATUS                      PORTS     NAMES
> 9b2789d81f72   nginx:1.29-alpine   "/docker-entrypoint.…"   1 minute ago     Exited (0) 5 seconds ago              web
> c4d7e2a9f1b3   nginx:1.29-alpine   "/docker-entrypoint.…"   3 minutes ago    Exited (0) 2 minutes ago              tender_curie
> b81e4c6a2f9d   nginx:1.29-alpine   "/docker-entrypoint.…"   5 minutes ago    Exited (0) 4 minutes ago              sharp_babbage
> 3f9c2a7b1d4e   nginx:1.29-alpine   "/docker-entrypoint.…"   7 minutes ago    Exited (0) 6 minutes ago              eager_hopper
> ...
> ```

Four containers from one image – each with its own configuration. You don't change a container's configuration; you start a new one and throw the old one away.

Start `web` again – same container, same name, same port:

```bash
docker start web
```

```bash
curl localhost:8080
```

Try to remove it while it is running:

```bash
docker rm web
```

> **Output**
> ```text
> Error response from daemon: cannot remove container "web": container is running: stop the container before removing or force remove
> ```

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

> **Output**
> ```text
> IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
> alpine:3.22          bfe7ceb9f09e       12.9MB         3.88MB
> my-alpine:demo       bfe7ceb9f09e       12.9MB         3.88MB
> ...
> ```

Both names show the **same ID**: a tag is just a pointer to an image. Nothing was copied.

Remove the new name:

```bash
docker rmi my-alpine:demo
```

> **Output**
> ```text
> Untagged: my-alpine:demo
> ```

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

> **Output**
> ```text
>  => => naming to docker.io/library/hello-container:v1
> ```

```bash
docker images
```

> **Output**
> ```text
> IMAGE                   ID             DISK USAGE   CONTENT SIZE   EXTRA
> hello-container:v1      4284bbcd5402       12.9MB         3.88MB
> ...
> ```

Run it:

```bash
docker run --rm hello-container:v1
```

> **Output**
> ```text
> Hello from my first image
> ```

## 9. Images are immutable – build a new version

Change the text file:

```bash
echo "Hello from version 2" > hello.txt
```

Run the existing image again:

```bash
docker run --rm hello-container:v1
```

> **Output**
> ```text
> Hello from my first image
> ```

Still the old text: the file was copied into the image at build time. Changing it on disk does not change the image. Build a new version:

```bash
docker build -t hello-container:v2 .
```

```bash
docker run --rm hello-container:v2
```

> **Output**
> ```text
> Hello from version 2
> ```

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

List what is left:

```bash
docker ps -a
```

Remove a single stopped container by ID or name (use one from *your* output):

```bash
docker rm eager_hopper
```

Remove several at once:

```bash
docker rm tender_curie sharp_babbage
```

Remove **all** stopped containers in one go (confirm with `y`):

```bash
docker container prune
```

> **Output**
> ```text
> WARNING! This will remove all stopped containers.
> Are you sure you want to continue? [y/N] y
> Deleted Containers:
> ...
> ```

```bash
docker ps -a
```

Now the images. Remove your own images:

```bash
docker rmi hello-container:v1 hello-container:v2
```

An image cannot be removed while a container still uses it – even a stopped one. That is why the containers go first.

Remove the pulled images, too:

```bash
docker rmi nginx:1.29-alpine alpine:3.22 hello-world
```

```bash
docker images
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
| `docker ps -aq` / `--format "table {{.ID}}\t{{.Names}}"` / `--filter status=exited` | only IDs / chosen columns / only stopped containers |
| `docker logs <container>` | shows the output of a container |
| `docker stop` / `docker start` / `docker rm` | stops / starts / removes a container |
| `docker container prune` | removes all stopped containers |
| `docker tag <image> <new-name>` | adds a name to an image |
| `docker rmi <image>` | removes a name, and the image once no name is left |
| `docker build -t <name>:<tag> <context>` | builds an image from a Dockerfile |
| `docker login` / `docker push <image>` | logs in to a registry / uploads an image |

Next: [02 – A REST API in a Container](02-rest-api-in-a-container.md) · [03 – Looking Inside Containers](03-looking-inside-containers.md)
