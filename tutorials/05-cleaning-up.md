# Cleaning Up – Step by Step

## 1. About

Containers, images, networks, volumes and build cache pile up quickly. This walkthrough shows how to look at what is there, remove things selectively, and finally reset Docker to an empty state – the starting point for [06 – Docker Compose](06-docker-compose.md).

Every code block contains **exactly one command**.

> **Warning:** in a codespace this is harmless. On your own machine, the commands in sections 7 and 8 remove *all* unused Docker data – including images and volumes of other projects.

## 2. Look first

How much space does Docker use, and where?

```bash
docker system df
```

> **Output**
> ```text
> TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
> Images          6         1         1.31GB    1.1GB (84%)
> Containers      4         1         2.1kB     1.4kB (66%)
> Local Volumes   2         0         47.8MB    47.8MB (100%)
> Build Cache     21        0         84.2MB    84.2MB
> ```

*Active* means: in use by a container. *Reclaimable* is what you could free.

```bash
docker ps -a
```

```bash
docker images
```

```bash
docker network ls
```

```bash
docker volume ls
```

## 3. Containers

Only the IDs of stopped containers:

```bash
docker ps -aq --filter status=exited
```

Remove exactly those – `$( … )` inserts the output of one command as the arguments of another:

```bash
docker rm $(docker ps -aq --filter status=exited)
```

The same, built into Docker (confirm with `y`):

```bash
docker container prune
```

Running containers are not touched by either. To remove **all** containers, running or not, `-f` stops them first:

```bash
docker rm -f $(docker ps -aq)
```

```bash
docker ps -a
```

> **Output**
> ```text
> CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
> ```

## 4. Images

*Dangling* images have no name any more – typically old builds whose tag moved to a newer build. Remove them:

```bash
docker image prune
```

Remove **all** images that no container uses (`-a`):

```bash
docker image prune -a
```

Or remove every image by ID:

```bash
docker rmi $(docker images -q)
```

```bash
docker images
```

## 5. Networks

Remove all networks that no container uses:

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

## 6. Volumes

Volumes hold data that should outlive containers – so Docker is careful with them. By default, `prune` removes only *anonymous* volumes that no container uses:

```bash
docker volume prune
```

To remove *named* volumes as well, add `-a`:

```bash
docker volume prune -a
```

```bash
docker volume ls
```

## 7. Build cache

Every `docker build` leaves cache layers behind to make the next build faster:

```bash
docker builder prune
```

## 8. Everything at once

`docker system prune` combines the steps above: stopped containers, unused networks, dangling images and build cache:

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

If a named volume is still listed, remove it with `docker volume prune -a` from section 6.

## 9. Overview

| Command | Removes |
|---|---|
| `docker rm <container>` / `docker rm -f <container>` | one or more containers / also running ones |
| `docker rm $(docker ps -aq --filter status=exited)` | all stopped containers |
| `docker container prune` | all stopped containers |
| `docker image prune` / `docker image prune -a` | dangling images / all unused images |
| `docker network prune` | all unused networks |
| `docker volume prune` / `docker volume prune -a` | unused anonymous volumes / also named ones |
| `docker builder prune` | build cache |
| `docker system prune` | stopped containers, unused networks, dangling images, build cache |
| `docker system prune -a --volumes` | everything unused |

Next: [06 – Docker Compose](06-docker-compose.md)
