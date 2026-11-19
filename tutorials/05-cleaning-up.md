# Cleaning Up – Step by Step

## 1. About

Containers, images, networks, volumes and build cache pile up quickly. This walkthrough shows how to look at what is there, remove things selectively, and finally reset Docker to an empty state.

So that every command has something to remove, you first make some mess on purpose – and mark all of it with a **label**, `tutorial=05`. Each section then works in two steps:

1. remove only what carries the label (`--filter label=tutorial=05`) – safe on any machine
2. the same command without the filter – removes it for **everything** unused

After each step you look again and compare.

Every code block contains **exactly one command**. IDs in the outputs are examples; yours will differ.

> **Warning:** in a codespace, the commands without a filter are harmless. On your own machine, they remove unused Docker data of *all* projects – including images and volumes you may still want. There, stick to the filtered commands, or look at the lists first.

## 2. Make some mess

Two containers that run one command and stop:

```bash
docker run --label tutorial=05 alpine:3.22 echo one
```

```bash
docker run --label tutorial=05 alpine:3.22 echo two
```

One that keeps running:

```bash
docker run -d --label tutorial=05 --name mess-web nginx:1.29-alpine
```

One with an *anonymous* volume – `-v` with only a path inside the container, no name:

```bash
docker run --label tutorial=05 --name mess-anon -v /data alpine:3.22 true
```

An image, built twice under the same name. Create a small Dockerfile:

```bash
mkdir mess
```

```bash
echo 'FROM alpine:3.22' > mess/Dockerfile
```

```bash
echo 'ARG N' >> mess/Dockerfile
```

```bash
echo 'RUN echo $N > /n' >> mess/Dockerfile
```

```bash
cat mess/Dockerfile
```

> **Output**
> ```text
> FROM alpine:3.22
> ARG N
> RUN echo $N > /n
> ```

Build it with `N=1`, then again with `N=2` – different content, same tag:

```bash
docker build --label tutorial=05 --build-arg N=1 -t mess mess
```

```bash
docker build --label tutorial=05 --build-arg N=2 -t mess mess
```

A network and a named volume:

```bash
docker network create --label tutorial=05 mess-net
```

```bash
docker volume create --label tutorial=05 mess-data
```

## 3. Look first

How much space does Docker use, and where?

```bash
docker system df
```

> **Output**
> ```text
> TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
> Images          6         2         1.31GB    1.1GB (84%)
> Containers      4         1         2.1kB     1.4kB (66%)
> Local Volumes   2         0         47.8MB    47.8MB (100%)
> Build Cache     21        0         84.2MB    84.2MB
> ```

*Active* means: in use by a container. *Reclaimable* is what you could free. Now the mess, piece by piece:

```bash
docker ps -a --filter label=tutorial=05
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED          STATUS                     PORTS     NAMES
> 3284cab768ad   alpine:3.22         "true"                   10 seconds ago   Exited (0) 9 seconds ago             mess-anon
> 5dbcafb11563   nginx:1.29-alpine   "/docker-entrypoint.…"   20 seconds ago   Up 19 seconds              80/tcp    mess-web
> 0a94cbe01d41   alpine:3.22         "echo two"               30 seconds ago   Exited (0) 29 seconds ago            brave_cohen
> af62a9c481b3   alpine:3.22         "echo one"               40 seconds ago   Exited (0) 39 seconds ago            eager_albattani
> ```

```bash
docker images --filter label=tutorial=05
```

> **Output**
> ```text
> IMAGE         ID             DISK USAGE   CONTENT SIZE   EXTRA
> mess:latest   a284ab718b1e       8.54MB             0B
> ```

Only one `mess` – where is the first build? The tag moved to the second one. The first build has no name any more – it is *dangling*:

```bash
docker images --filter dangling=true --filter label=tutorial=05
```

> **Output**
> ```text
> IMAGE        ID             DISK USAGE   CONTENT SIZE   EXTRA
> <untagged>   d2ae64d16b0a       8.54MB             0B
> ```

```bash
docker network ls --filter label=tutorial=05
```

```bash
docker volume ls --filter label=tutorial=05
```

> **Output**
> ```text
> DRIVER    VOLUME NAME
> local     mess-data
> ```

Only the named volume. The anonymous one of `mess-anon` has no label – a volume does not inherit the labels of its container. All volumes:

```bash
docker volume ls
```

> **Output**
> ```text
> DRIVER    VOLUME NAME
> local     bde5cbf45813a49c71ae573e7eca7965b5cba0af89b408a45aaee3f2e645305a
> local     mess-data
> ```

The long hash is the anonymous volume. Remember it for section 7.

## 4. Containers

Only the IDs of the stopped containers with the label:

```bash
docker ps -aq --filter status=exited --filter label=tutorial=05
```

> **Output**
> ```text
> 3284cab768ad
> 0a94cbe01d41
> af62a9c481b3
> ```

Three – `mess-web` is running. Remove the stopped ones (confirm with `y`):

```bash
docker container prune --filter label=tutorial=05
```

Look:

```bash
docker ps -a --filter label=tutorial=05
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS          PORTS     NAMES
> 5dbcafb11563   nginx:1.29-alpine   "/docker-entrypoint.…"   1 minute ago    Up 1 minute     80/tcp    mess-web
> ```

`prune` only removes stopped containers – `mess-web` is still there. A running container needs `-f`:

```bash
docker rm -f mess-web
```

```bash
docker ps -a --filter label=tutorial=05
```

Empty.

**Without the filter** – all stopped containers, of every project:

```bash
docker container prune
```

The same by hand – `$( … )` inserts the output of one command as the arguments of another:

```bash
docker rm $(docker ps -aq --filter status=exited)
```

And **all** containers, running or not:

```bash
docker rm -f $(docker ps -aq)
```

```bash
docker ps -a
```

## 5. Images

```bash
docker images --filter label=tutorial=05
```

Remove the dangling images with the label:

```bash
docker image prune --filter label=tutorial=05
```

> **Output**
> ```text
> Deleted Images:
> deleted: sha256:d2ae64d16b0afc6fc870cbe6286d1bf9e31d40f8b820210c28a630d03193aafe
> ```

Look:

```bash
docker images --filter label=tutorial=05
```

> **Output**
> ```text
> IMAGE         ID             DISK USAGE   CONTENT SIZE   EXTRA
> mess:latest   a284ab718b1e       8.54MB             0B
> ```

The first build is gone, `mess:latest` stays – it has a name. With `-a`, `prune` removes every image no container uses, named or not:

```bash
docker image prune -a --filter label=tutorial=05
```

```bash
docker images --filter label=tutorial=05
```

Empty.

**Without the filter** – dangling images of every project:

```bash
docker image prune
```

All images that no container uses:

```bash
docker image prune -a
```

Or every image by ID:

```bash
docker rmi $(docker images -q)
```

```bash
docker images
```

## 6. Networks

```bash
docker network ls --filter label=tutorial=05
```

```bash
docker network prune --filter label=tutorial=05
```

```bash
docker network ls --filter label=tutorial=05
```

Empty. **Without the filter** – all networks that no container uses:

```bash
docker network prune
```

```bash
docker network ls
```

> **Output**
> ```text
> NETWORK ID     NAME      DRIVER    SCOPE
> 1a2b3c4d5e6f   bridge    bridge    local
> 2b3c4d5e6f7a   host      host      local
> 3c4d5e6f7a8b   none      null      local
> ```

These three always stay – they belong to Docker itself.

## 7. Volumes

Volumes hold data that should outlive containers – so Docker is careful with them.

```bash
docker volume ls --filter label=tutorial=05
```

```bash
docker volume prune --filter label=tutorial=05
```

> **Output**
> ```text
> Total reclaimed space: 0B
> ```

Nothing removed. Look:

```bash
docker volume ls --filter label=tutorial=05
```

`mess-data` is still there: by default, `prune` removes only *anonymous* volumes. Named volumes need `-a`:

```bash
docker volume prune -a --filter label=tutorial=05
```

```bash
docker volume ls --filter label=tutorial=05
```

Empty. And the anonymous volume from section 2? It has no label, so the filter never matched it. Volumes no container uses are *dangling*:

```bash
docker volume ls --filter dangling=true
```

The long hash from section 3 – its container is gone, the volume is still there. Remove it by name (use *yours*):

```bash
docker volume rm bde5cbf45813a49c71ae573e7eca7965b5cba0af89b408a45aaee3f2e645305a
```

`docker rm -v` would have removed it together with the container, and `docker run --rm` removes anonymous volumes automatically.

**Without the filter** – all unused anonymous volumes:

```bash
docker volume prune
```

Named ones as well:

```bash
docker volume prune -a
```

```bash
docker volume ls
```

## 8. Build cache

Every `docker build` leaves cache layers behind to make the next build faster – including the two builds of `mess`. The build cache has no labels, so there is no filtered variant:

```bash
docker system df
```

```bash
docker builder prune
```

```bash
docker system df
```

Compare the *Build Cache* line. The next build of an image takes longer again.

## 9. Everything at once

`docker system prune` combines the steps above: stopped containers, unused networks, dangling images and build cache. It takes `--filter label=…`, too:

```bash
docker system prune
```

Everything unused, including all unused images and volumes – a fresh start:

```bash
docker system prune -a --volumes
```

> **Output**
> ```text
> WARNING! This will remove:
>   - all stopped containers
>   - all networks not used by at least one container
>   - all anonymous volumes not used by at least one container
>   - all images without at least one container associated to them
>   - all build cache
>
> Are you sure you want to continue? [y/N] y
> ...
> Total reclaimed space: 1.4GB
> ```

Check:

```bash
docker system df
```

> **Output**
> ```text
> TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
> Images          0         0         0B        0B
> Containers      0         0         0B        0B
> Local Volumes   0         0         0B        0B
> Build Cache     0         0         0B        0B
> ```

If a named volume is still listed, remove it with `docker volume prune -a` from section 7. Remove the working directory:

```bash
rm -r mess
```

## 10. Overview

| Command | Removes |
|---|---|
| `docker rm <container>` / `docker rm -f <container>` | one or more containers / also running ones |
| `docker rm -v <container>` | a container and its anonymous volumes |
| `docker rm $(docker ps -aq --filter status=exited)` | all stopped containers |
| `docker container prune` | all stopped containers |
| `docker image prune` / `docker image prune -a` | dangling images / all unused images |
| `docker network prune` | all unused networks |
| `docker volume prune` / `docker volume prune -a` | unused anonymous volumes / also named ones |
| `docker builder prune` | build cache |
| `docker system prune` | stopped containers, unused networks, dangling images, build cache |
| `docker system prune -a --volumes` | everything unused |
| `… prune --filter label=<key>=<value>` | only what carries that label |
| `docker images --filter dangling=true` / `docker volume ls --filter dangling=true` | what has no name / no container any more |

Next: [06 – Docker Compose](06-docker-compose.md)
