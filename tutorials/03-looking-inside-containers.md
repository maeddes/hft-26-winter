# Looking Inside Containers – Step by Step

## 1. About

This walkthrough continues [01 – Docker Basics](01-docker-basics.md): you open a shell in a container, run commands in a running container, see where changes end up, and learn why a Dockerfile beats changing containers by hand.

The point is not to get through it fast. After almost every step you look again – `docker ps`, `docker ps -a`, `docker images`, `docker diff` – and compare with what you saw before. That is how the commands stick, and how you see what each one actually changed.

Every code block contains **exactly one command**. Some commands run *inside* a container – this is marked in the text. IDs, names and times in the outputs are examples; yours will differ.

### 1.1 Prerequisites

- [01 – Docker Basics](01-docker-basics.md)
- A GitHub Codespace or Docker on your own machine

### 1.2 Two terminals

Split the terminal (the **Split Terminal** icon in the terminal panel). Use the left one for the commands of this tutorial, the right one to look: whenever the text says *look* in bold, run the command there.

## 2. A container that runs one command

Run a container from the Alpine image, without anything else:

```bash
docker run alpine:3.22
```

Nothing happens – you get your prompt back. Look at the running containers:

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
> ```

Empty. Now look at all containers, including the stopped ones. `--filter ancestor=alpine:3.22` shows only those created from this image:

```bash
docker ps -a --filter ancestor=alpine:3.22
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND     CREATED         STATUS                     PORTS     NAMES
> 97a09e5cf8d0   alpine:3.22   "/bin/sh"   3 seconds ago   Exited (0) 2 seconds ago             funny_lichterman
> ```

There it is: it ran `/bin/sh`, the default command of the image, and exited with code 0. Run the same command again:

```bash
docker run alpine:3.22
```

Look again:

```bash
docker ps -a --filter ancestor=alpine:3.22
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND     CREATED          STATUS                      PORTS     NAMES
> 539ea48f5a86   alpine:3.22   "/bin/sh"   2 seconds ago    Exited (0) 2 seconds ago              frosty_satoshi
> 97a09e5cf8d0   alpine:3.22   "/bin/sh"   20 seconds ago   Exited (0) 19 seconds ago             funny_lichterman
> ```

Two containers. Every `docker run` creates a **new** container – it does not restart the old one.

### 2.1 A command of your own

A command after the image name replaces the default command:

```bash
docker run alpine:3.22 hostname
```

> **Output**
> ```text
> f35af2f48939
> ```

Look again:

```bash
docker ps -a --filter ancestor=alpine:3.22
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND      CREATED          STATUS                      PORTS     NAMES
> f35af2f48939   alpine:3.22   "hostname"   3 seconds ago    Exited (0) 2 seconds ago              serene_poincare
> 539ea48f5a86   alpine:3.22   "/bin/sh"    40 seconds ago   Exited (0) 39 seconds ago             frosty_satoshi
> 97a09e5cf8d0   alpine:3.22   "/bin/sh"    58 seconds ago   Exited (0) 57 seconds ago             funny_lichterman
> ```

Compare: the hostname printed by the container is the **CONTAINER ID** of the newest line, and its COMMAND is `"hostname"`.

Who are you inside the container?

```bash
docker run alpine:3.22 whoami
```

> **Output**
> ```text
> root
> ```

And outside?

```bash
whoami
```

> **Output**
> ```text
> codespace
> ```

Which operating system does the container see?

```bash
docker run alpine:3.22 cat /etc/os-release
```

> **Output**
> ```text
> NAME="Alpine Linux"
> ID=alpine
> VERSION_ID=3.22.8
> PRETTY_NAME="Alpine Linux v3.22"
> ...
> ```

And outside?

```bash
cat /etc/os-release
```

The Linux of your codespace – not Alpine. (On a Mac, the file does not exist.)

Look again:

```bash
docker ps -a --filter ancestor=alpine:3.22
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND                  CREATED              STATUS                          PORTS     NAMES
> eb17acebc683   alpine:3.22   "cat /etc/os-release"    5 seconds ago        Exited (0) 4 seconds ago                  zealous_morse
> 0f6e6200d2d7   alpine:3.22   "whoami"                 30 seconds ago       Exited (0) 29 seconds ago                 goofy_ptolemy
> f35af2f48939   alpine:3.22   "hostname"               About a minute ago   Exited (0) About a minute ago             serene_poincare
> 539ea48f5a86   alpine:3.22   "/bin/sh"                2 minutes ago        Exited (0) 2 minutes ago                  frosty_satoshi
> 97a09e5cf8d0   alpine:3.22   "/bin/sh"                2 minutes ago        Exited (0) 2 minutes ago                  funny_lichterman
> ```

Five runs, five containers, all exited. Each one did its command and stopped.

### 2.2 Clean up the five

`docker ps -aq` prints only the IDs – the filter still applies. Remove all five at once:

```bash
docker rm $(docker ps -aq --filter ancestor=alpine:3.22)
```

> **Output**
> ```text
> eb17acebc683
> 0f6e6200d2d7
> f35af2f48939
> 539ea48f5a86
> 97a09e5cf8d0
> ```

Look again:

```bash
docker ps -a --filter ancestor=alpine:3.22
```

> **Output**
> ```text
> CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
> ```

## 3. Input and a terminal: `-i` and `-t`

So why does the shell exit right away? Start it explicitly:

```bash
docker run alpine:3.22 sh
```

Same as before: back at the prompt. A shell reads commands from its input. Give it one – `echo` sends `hostname` into the pipe:

```bash
echo hostname | docker run alpine:3.22 sh
```

Nothing. Without `-i`, the input does not reach the container – the shell sees an empty input and ends. Now with `-i` (interactive):

```bash
echo hostname | docker run -i alpine:3.22 sh
```

> **Output**
> ```text
> 13fe82504d5c
> ```

The shell read `hostname`, ran it, reached the end of the input, and ended. Look:

```bash
docker ps -a --filter ancestor=alpine:3.22
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND   CREATED          STATUS                      PORTS     NAMES
> 13fe82504d5c   alpine:3.22   "sh"      5 seconds ago    Exited (0) 4 seconds ago              compassionate_satoshi
> 82cd0e63c9c9   alpine:3.22   "sh"      20 seconds ago   Exited (0) 19 seconds ago             romantic_mccarthy
> 9d759505116e   alpine:3.22   "sh"      40 seconds ago   Exited (0) 39 seconds ago             laughing_moser
> ```

Three more – one per run, as before.

### 3.1 A shell you can type into

To type yourself, you need the input open (`-i`) **and** a terminal (`-t`, tty) for the prompt. This time give the container a name:

```bash
docker run -it --name shell alpine:3.22 sh
```

The prompt changes to `/ #` – you are inside the container. **Inside the container**:

```bash
hostname
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

The container sees only its own processes, and your shell is process 1. Create a file:

```bash
touch /tmp/hello
```

Now **look** (right terminal):

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND   CREATED          STATUS          PORTS     NAMES
> 4dcbc2d0fdba   alpine:3.22   "sh"      30 seconds ago   Up 29 seconds             shell
> ```

For the first time, an Alpine container is **Up**: the shell is waiting for your input. Compare the CONTAINER ID with the `hostname` output inside.

Back in the left terminal, **inside the container**, leave the shell:

```bash
exit
```

Look again:

```bash
docker ps
```

Empty.

```bash
docker ps -a --filter name=shell
```

> **Output**
> ```text
> CONTAINER ID   IMAGE         COMMAND   CREATED              STATUS                     PORTS     NAMES
> 4dcbc2d0fdba   alpine:3.22   "sh"      About a minute ago   Exited (0) 5 seconds ago             shell
> ```

`exit` ended the shell – process 1 – and with it the container.

### 3.2 Start it again

A stopped container is not gone. Start it again and attach to it (`-a` output, `-i` input):

```bash
docker start -ai shell
```

**Inside the container**:

```bash
ls /tmp
```

> **Output**
> ```text
> hello
> ```

The file is still there. Stopping a container keeps its file system; only the processes end.

```bash
exit
```

Remove it, and the other three:

```bash
docker rm shell
```

```bash
docker rm $(docker ps -aq --filter ancestor=alpine:3.22)
```

Look again:

```bash
docker ps -a --filter ancestor=alpine:3.22
```

Empty. With `docker rm`, the file is gone, too.

## 4. Into a running container: `docker exec`

So far, every shell was the main process of its own container. Often you want the opposite: a container is already running an application, and you want to look inside.

Start a web server in the background:

```bash
docker run -d --name web -p 8080:80 nginx:1.29-alpine
```

Look:

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS         PORTS                                     NAMES
> fb1883988e07   nginx:1.29-alpine   "/docker-entrypoint.…"   5 seconds ago   Up 4 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   web
> ```

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
docker exec web hostname
```

> **Output**
> ```text
> fb1883988e07
> ```

The CONTAINER ID from `docker ps`. You can use the name `web` instead of the ID because you gave it one.

```bash
docker exec web ls /usr/share/nginx/html
```

> **Output**
> ```text
> 50x.html
> index.html
> ```

```bash
docker exec web ps
```

> **Output**
> ```text
> PID   USER     TIME  COMMAND
>     1 root      0:00 nginx: master process nginx -g daemon off;
>    30 nginx     0:00 nginx: worker process
>    ...
>    54 root      0:00 ps
> ```

This time, process 1 is nginx – the command from the image. `ps` itself shows up as an additional process. Look:

```bash
docker ps -a --filter name=web
```

Still **one** container. `docker run` creates a container from an image; `docker exec` starts a process in a container that is already running.

### 4.1 A shell in the running container

```bash
docker exec -it web sh
```

**Inside the container**:

```bash
ps
```

> **Output**
> ```text
> PID   USER     TIME  COMMAND
>     1 root      0:00 nginx: master process nginx -g daemon off;
>    30 nginx     0:00 nginx: worker process
>    ...
>    55 root      0:00 sh
>    61 root      0:00 ps
> ```

Your shell is there, next to nginx. Now **look** at the same processes from outside:

```bash
docker top web
```

> **Output**
> ```text
> UID     PID     PPID    C   STIME   TTY     TIME       CMD
> root    37171   37148   0   16:50   ?       00:00:00   nginx: master process nginx -g daemon off;
> ...
> root    37402   37148   0   16:52   pts/0   00:00:00   sh
> ```

The same processes, with the process IDs of the host: a container is a set of ordinary processes, just with a restricted view.

```bash
docker ps
```

Still one container. **Inside the container**, leave the shell:

```bash
exit
```

Look again:

```bash
docker ps
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED         STATUS         PORTS                                     NAMES
> fb1883988e07   nginx:1.29-alpine   "/docker-entrypoint.…"   2 minutes ago   Up 2 minutes   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   web
> ```

Still **Up** – compare with section 3.1. There, the shell was process 1, so `exit` stopped the container. Here, nginx is process 1, and your shell was just an extra process.

## 5. The writable layer

Every container gets a thin writable layer on top of its image. `docker diff` shows what is in it – before you change anything:

```bash
docker diff web
```

> **Output**
> ```text
> C /etc
> C /etc/nginx
> C /etc/nginx/conf.d
> C /etc/nginx/conf.d/default.conf
> C /run
> A /run/nginx.pid
> C /var
> C /var/cache
> C /var/cache/nginx
> A /var/cache/nginx/client_temp
> ...
> ```

`C` means *changed*, `A` *added*, `D` *deleted*. Not empty: nginx itself wrote a few files when it started. Remember this list.

Open a shell in the container again:

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

```bash
curl localhost:8080
```

> **Output**
> ```text
> <h1>Changed inside the container</h1>
> ```

The web server delivers the new page right away. Look at the writable layer again:

```bash
docker diff web
```

> **Output**
> ```text
> ...
> C /usr
> C /usr/share
> C /usr/share/nginx
> C /usr/share/nginx/html
> C /usr/share/nginx/html/index.html
> ```

Compare with the first list: the lines for `/usr/share/nginx/html/index.html` are new.

### 5.1 A second container from the same image

```bash
docker run -d --name web2 -p 8081:80 nginx:1.29-alpine
```

```bash
docker ps
```

Two containers, same image, different ports.

```bash
curl localhost:8081
```

> **Output**
> ```text
> ...
> <title>Welcome to nginx!</title>
> ...
> ```

The original page. Look at its writable layer:

```bash
docker diff web2
```

Only the files nginx wrote at startup – no `index.html`. The change lives in the writable layer of `web`, not in the image.

### 5.2 Stop and start

Stop `web`:

```bash
docker stop web
```

Look:

```bash
docker ps
```

Only `web2`.

```bash
docker ps -a --filter name=web
```

> **Output**
> ```text
> CONTAINER ID   IMAGE               COMMAND                  CREATED          STATUS                     PORTS                                     NAMES
> 86104233d1d5   nginx:1.29-alpine   "/docker-entrypoint.…"   1 minute ago     Up 1 minute                0.0.0.0:8081->80/tcp, [::]:8081->80/tcp   web2
> fb1883988e07   nginx:1.29-alpine   "/docker-entrypoint.…"   5 minutes ago    Exited (0) 3 seconds ago                                             web
> ```

`web` is stopped – and has no port any more:

```bash
curl localhost:8080
```

> **Output**
> ```text
> curl: (7) Failed to connect to localhost port 8080 after 0 ms: Couldn't connect to server
> ```

Start it again:

```bash
docker start web
```

```bash
curl localhost:8080
```

> **Output**
> ```text
> <h1>Changed inside the container</h1>
> ```

The change survived – like `/tmp/hello` in section 3.2. `docker stop` and `docker start` keep the writable layer, the name, the ports and the configuration. What does not survive is the memory of the processes: they start fresh. An application that keeps its data only in memory loses it.

Remove `web2`, you do not need it any more:

```bash
docker rm -f web2
```

## 6. Turning a container into an image – and why you shouldn't

The change in `web` disappears as soon as the container is removed. Docker can save the state of a container as a new image. First look at your images:

```bash
docker images
```

> **Output**
> ```text
> IMAGE               ID             DISK USAGE   CONTENT SIZE   EXTRA
> alpine:3.22         062964a69725       8.54MB             0B
> nginx:1.29-alpine   7f7dcd27f920       61.6MB             0B   U
> ```

```bash
docker commit web my-nginx:changed
```

Look again:

```bash
docker images
```

> **Output**
> ```text
> IMAGE               ID             DISK USAGE   CONTENT SIZE   EXTRA
> alpine:3.22         062964a69725       8.54MB             0B
> my-nginx:changed    1e55fe3edcfc       61.6MB             0B
> nginx:1.29-alpine   7f7dcd27f920       61.6MB             0B   U
> ```

A new image. Run a container from it:

```bash
docker run -d --name web3 -p 8082:80 my-nginx:changed
```

```bash
docker ps
```

`web` and `web3`, from two different images.

```bash
curl localhost:8082
```

> **Output**
> ```text
> <h1>Changed inside the container</h1>
> ```

Now remove `web` – and with it its writable layer:

```bash
docker rm -f web
```

Start a fresh `web` from the original image:

```bash
docker run -d --name web -p 8080:80 nginx:1.29-alpine
```

```bash
curl localhost:8080
```

The original page – the change went away with the old container. It only survives in `my-nginx:changed`:

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
> 1e55fe3edcfc   1 minute ago     nginx -g daemon off;                            1.13kB
> 7f7dcd27f920   7 months ago     RUN /bin/sh -c set -x     && apkArch="$(cat …   48.3MB    buildkit.dockerfile.v0
> <missing>      7 months ago     ENV ACME_VERSION=0.3.1                          0B        buildkit.dockerfile.v0
> ...
> <missing>      7 months ago     CMD ["nginx" "-g" "daemon off;"]                0B        buildkit.dockerfile.v0
> ...
> ```

The top layer is yours: 1.13 kB, and it says nothing about *what* was changed or *how*. Nobody can rebuild this image, and nobody can review it. That is the reproducibility problem again – this time inside Docker.

## 7. The reproducible way: a Dockerfile

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

Look at your images:

```bash
docker images
```

> **Output**
> ```text
> IMAGE               ID             DISK USAGE   CONTENT SIZE   EXTRA
> alpine:3.22         062964a69725       8.54MB             0B
> my-nginx:changed    1e55fe3edcfc       61.6MB             0B   U
> my-nginx:v1         914fc45918a9       61.6MB             0B
> nginx:1.29-alpine   7f7dcd27f920       61.6MB             0B   U
> ```

Two images of yours on the same base – one from `commit`, one from a Dockerfile.

```bash
docker run -d --name web4 -p 8083:80 my-nginx:v1
```

```bash
docker ps
```

Three containers: `web` (original image), `web3` (commit), `web4` (Dockerfile). Call all three:

```bash
curl localhost:8080
```

```bash
curl localhost:8082
```

```bash
curl localhost:8083
```

> **Output**
> ```text
> <h1>Built from a Dockerfile</h1>
> ```

Now compare the histories. The new image:

```bash
docker history my-nginx:v1
```

> **Output**
> ```text
> IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
> 914fc45918a9   1 minute ago     COPY index.html /usr/share/nginx/html/index.…   33B       buildkit.dockerfile.v0
> <missing>      7 months ago     RUN /bin/sh -c set -x     && apkArch="$(cat …   48.3MB    buildkit.dockerfile.v0
> <missing>      7 months ago     ENV ACME_VERSION=0.3.1                          0B        buildkit.dockerfile.v0
> ...
> ```

The base image:

```bash
docker history nginx:1.29-alpine
```

> **Output**
> ```text
> IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
> 7f7dcd27f920   7 months ago     RUN /bin/sh -c set -x     && apkArch="$(cat …   48.3MB    buildkit.dockerfile.v0
> <missing>      7 months ago     ENV ACME_VERSION=0.3.1                          0B        buildkit.dockerfile.v0
> ...
> ```

And the committed one once more:

```bash
docker history my-nginx:changed
```

Read them bottom-up. All three share the lines of `nginx:1.29-alpine`. On top, `my-nginx:v1` has exactly one line of yours – `COPY index.html ...`, 33 bytes – and it says what it does. `my-nginx:changed` has an anonymous line instead.

Look at the `SIZE` column, too: `COPY` and `RUN` add files and have a size. `ENV`, `CMD` and `EXPOSE` show `0B` – they only change the image's metadata.

Go back:

```bash
cd ..
```

## 8. Clean up

Remove the three containers (`-f` stops them first):

```bash
docker rm -f web web3 web4
```

Look:

```bash
docker ps -a
```

None of them left. Remove your two images:

```bash
docker rmi my-nginx:changed my-nginx:v1
```

Look:

```bash
docker images
```

> **Output**
> ```text
> IMAGE               ID             DISK USAGE   CONTENT SIZE   EXTRA
> alpine:3.22         062964a69725       8.54MB             0B
> nginx:1.29-alpine   7f7dcd27f920       61.6MB             0B
> ```

The base images stay – you will need them again. Remove the working directory:

```bash
rm -r my-nginx
```

Removing many things at once with `prune` comes in [05 – Cleaning Up](05-cleaning-up.md).

## 9. Overview

| Command | What it does |
|---|---|
| `docker run <image> <command>` | creates a new container and runs the command instead of the default one |
| `docker ps -a --filter ancestor=<image>` | lists all containers created from an image |
| `docker rm $(docker ps -aq --filter ...)` | removes all containers the filter matches |
| `docker run -i ...` | keeps the input open – piped input reaches the container |
| `docker run -it <image> sh` | starts a container with an interactive shell |
| `docker start -ai <container>` | starts a stopped container again and attaches to it |
| `docker exec <container> <command>` | runs an additional process in a running container |
| `docker exec -it <container> sh` | opens a shell in a running container |
| `docker top <container>` | shows the processes of a container, seen from the host |
| `docker diff <container>` | shows what changed in the writable layer |
| `docker stop` / `docker start` | stop and start a container – the writable layer stays |
| `docker commit <container> <image>` | saves a container as an image – works, but not reproducible |
| `docker history <image>` | shows the layers of an image and how they were created |

Next: [04 – Container Networking](04-container-networking.md)
