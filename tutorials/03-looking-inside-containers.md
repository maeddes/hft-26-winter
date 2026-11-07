# Looking Inside Containers – Step by Step

## 1. About

This walkthrough continues [01 – Docker Basics](01-docker-basics.md): you open a shell in a container, run commands in a running container, see where changes end up, and learn why a Dockerfile beats changing containers by hand.

Every code block contains **exactly one command**. Some commands run *inside* a container – this is marked in the text.

### 1.1 Prerequisites

- [01 – Docker Basics](01-docker-basics.md)
- A GitHub Codespace or Docker on your own machine

## 2. An interactive container

So far, every container ran one command and exited. Start a container with a shell and stay in it:

```bash
docker run -it --rm alpine:3.22 sh
```

- `-i` (interactive) keeps the input open, so you can type
- `-t` (tty) gives you a terminal with a prompt

The prompt changes to `/ #` – you are now inside the container. Run these commands **inside the container**:

```bash
hostname
```

```bash
cat /etc/os-release
```

```bash
ps
```

> **Output**
> ```text
> PID   USER     TIME  COMMAND
>     1 root      0:00 sh
>     7 root      0:00 ps
> ```

The container sees only its own processes, and the shell you started is process 1. Leave the container:

```bash
exit
```

Because of `--rm`, the container is gone.

## 3. Into a running container: `docker exec`

Start a web server in the background:

```bash
docker run -d --name web -p 8080:80 nginx:1.29-alpine
```

```bash
curl localhost:8080
```

> **Output**
> ```text
> ...
> <title>Welcome to nginx!</title>
> ...
> ```

Run a single command in the running container:

```bash
docker exec web ls /usr/share/nginx/html
```

> **Output**
> ```text
> 50x.html
> index.html
> ```

Show its processes:

```bash
docker exec web ps
```

> **Output**
> ```text
> PID   USER     TIME  COMMAND
>     1 root      0:00 nginx: master process nginx -g daemon off;
>    30 nginx     0:00 nginx: worker process
>    ...
> ```

This time, process 1 is nginx – the command from the image. `docker exec` starts an *additional* process in the same container.

Open a shell in the running container:

```bash
docker exec -it web sh
```

**Inside the container**, replace the start page:

```bash
echo "<h1>Changed inside the container</h1>" > /usr/share/nginx/html/index.html
```

```bash
exit
```

Leaving the shell does not stop the container – nginx is still process 1. Call the web server:

```bash
curl localhost:8080
```

> **Output**
> ```text
> <h1>Changed inside the container</h1>
> ```

## 4. Where did the change go?

Ask Docker what changed in this container compared to its image:

```bash
docker diff web
```

Should display output like:

> **Output**
> ```text
> C /usr
> C /usr/share
> C /usr/share/nginx
> C /usr/share/nginx/html
> C /usr/share/nginx/html/index.html
> ...
> ```

`C` means *changed*, `A` *added*, `D` *deleted*. The changes live in the **writable layer** of this one container. Start a second container from the same image:

```bash
docker run -d --name web2 -p 8081:80 nginx:1.29-alpine
```

```bash
curl localhost:8081
```

> **Output**
> ```text
> ...
> <title>Welcome to nginx!</title>
> ...
> ```

The original page: the image is untouched.

## 5. Turning a container into an image – and why you shouldn't

Docker can save the state of a container as a new image:

```bash
docker commit web my-nginx:changed
```

Run it:

```bash
docker run -d --name web3 -p 8082:80 my-nginx:changed
```

```bash
curl localhost:8082
```

> **Output**
> ```text
> <h1>Changed inside the container</h1>
> ```

It works – but look at the history of that image:

```bash
docker history my-nginx:changed
```

> **Output**
> ```text
> IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
> 5c1e9a7b3d2f   1 minute ago     nginx -g daemon off;                            1.2kB
> <missing>      3 weeks ago      CMD ["nginx" "-g" "daemon off;"]                0B        buildkit.dockerfile.v0
> ...
> ```

The top layer says nothing about *what* was changed or *how*. Nobody can rebuild this image, and nobody can review it. That is the reproducibility problem again – this time inside Docker.

## 6. The reproducible way: a Dockerfile

Create a working directory and change into it:

```bash
mkdir my-nginx
```

```bash
cd my-nginx
```

Create the start page:

```bash
echo "<h1>Built from a Dockerfile</h1>" > index.html
```

Create the Dockerfile:

```bash
code Dockerfile
```

Paste this content and save:

```dockerfile
FROM nginx:1.29-alpine
COPY index.html /usr/share/nginx/html/index.html
```

No `CMD`: the base image already defines how nginx starts, and your image inherits it.

```bash
docker build -t my-nginx:v1 .
```

```bash
docker run -d --name web4 -p 8083:80 my-nginx:v1
```

```bash
curl localhost:8083
```

> **Output**
> ```text
> <h1>Built from a Dockerfile</h1>
> ```

Compare the history:

```bash
docker history my-nginx:v1
```

> **Output**
> ```text
> IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
> 8d2f4a6c1b3e   1 minute ago     COPY index.html /usr/share/nginx/html/index…   33B       buildkit.dockerfile.v0
> <missing>      3 weeks ago      CMD ["nginx" "-g" "daemon off;"]                0B        buildkit.dockerfile.v0
> ...
> ```

Read it bottom-up: the nginx layers, then exactly one layer of yours – and it says what it does. The Dockerfile documents how the image came about, and anyone can rebuild it.

Go back:

```bash
cd ..
```

## 7. Clean up

Remove all four containers (`-f` stops them first):

```bash
docker rm -f web web2 web3 web4
```

Remove your images:

```bash
docker rmi my-nginx:changed my-nginx:v1
```

Remove all stopped containers (confirm with `y`):

```bash
docker container prune
```

Remove images that no tag points to any more (confirm with `y`):

```bash
docker image prune
```

See how much space Docker uses:

```bash
docker system df
```

> **Output**
> ```text
> TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
> Images          5         0         1.2GB     1.2GB (100%)
> Containers      0         0         0B        0B
> Local Volumes   0         0         0B        0B
> Build Cache     12        0         45MB      45MB
> ```

## 8. Overview

| Command | What it does |
|---|---|
| `docker run -it <image> sh` | starts a container with an interactive shell |
| `docker exec <container> <command>` | runs an additional command in a running container |
| `docker exec -it <container> sh` | opens a shell in a running container |
| `docker diff <container>` | shows what changed in the writable layer |
| `docker commit <container> <image>` | saves a container as an image – works, but not reproducible |
| `docker history <image>` | shows the layers of an image and how they were created |
| `docker container prune` / `docker image prune` | removes stopped containers / untagged images |
| `docker system df` | shows the disk usage of images, containers, volumes and build cache |
