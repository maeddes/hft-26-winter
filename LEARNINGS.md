# Learnings

Corrections and ideas collected after each session: what was imprecise, outdated or worth going deeper. Newest on top.

- [x] addressed in class
- [ ] not yet addressed (or only published here)

## 2026-Nov-20

### Corrections

- [ ] **The P in CAP is partition *tolerance*, not partitioning:** "CAP stands for consistency, availability, and partitioning", "if we scale into multiple instances, then we have partitioning". A partition is a broken network between nodes – messages get lost – not the fact that there are several instances. Several instances are the precondition; the partition is the failure. In a distributed system partitions cannot be ruled out, so P is not a choice: *during* a partition, a system chooses between C and A. This is what the quote on your own slide 7 says (Brewer, 2012).
- [ ] **The bank is CP, not AP:** consistency first, transactions one after the other, availability is the price – "this would be an example for, let's say, AP". The description was right, the label wrong: that is **CP**. DNS was correctly the AP example.
- [ ] **"Two out of three at a given point in time"** – and slide 8, "Choose 2" – is exactly the misunderstanding Brewer warns about on slide 7. Without a partition, there is no trade-off between C and A. (PACELC extends this: *else*, between latency and consistency.)
- [ ] **The live demo was not CAP:** "that's like CAP theorem without partitioning … no availability, no consistency", and four instances with different lists: "full availability, but no consistency". The instances share no state at all – nothing is replicated, so nothing could become inconsistent through a partition. The demo shows why state must leave the instances; CAP becomes relevant once instances share state through replicas.
- [ ] **Conway was a computer scientist:** "before computers were even there … technical manufacturing". Melvin Conway's paper "How Do Committees Invent?" appeared in *Datamation* in April 1968 (submitted 1967), about the design of computer systems. Conway was a programmer – the term *coroutine* goes back to him.
- [ ] **AWS did not use VMware:** "infrastructure as a service, most particularly through Amazon Web Services with VMware technology". EC2 ran on the Xen hypervisor; since 2017 on Nitro (KVM-based).
- [ ] **Git is older than the 12 factors:** "after 2012, I don't know exactly when Git was released". Git appeared in 2005, GitHub in 2008. In 2011/12 Git was already widespread, Subversion still common – hence "revision control".
- [ ] **The Twelve-Factor App is from around 2011,** not 2012 (slide 25): written by Adam Wiggins, co-founder of Heroku. Heroku has belonged to Salesforce since the end of 2010.
- [ ] **FaaS is not five years old:** "came up maybe five years ago or so". AWS Lambda launched in November 2014.
- [ ] **`docker compose push` exists:** "if you're going to push them, that's something Docker Compose is not going to do for you". `docker compose push` pushes the images of all services with an `image:` name – that name has to include the registry or Docker ID.
- [ ] **Build vs. release (factor V):** "such a release could, for example, be a container image. And then the config can be added to that release". In twelve-factor terms, the image is the *build*; the *release* is build plus configuration.
- [ ] **Small details:** "ubiquitous network access" once more – NIST says *broad network access* (see Oct-23). The Scrum Guide (2020) says "typically 10 or fewer people", not seven or eight.
- [ ] **Slides (Cloud-Native SW Dev):**
  - p. 10: "As cloud native applications are considered as stateless, Partition Tolerance is given in the Cloud" – partitions are not prevented by stateless applications; the state just moves to the backing services, where CAP applies.
  - p. 33: the title says "Disposability, Dev/Prod Parity", the content is Logs and Admin processes.
  - p. 45: "FaaS fully implements 12-Factor App" – an overstatement.
  - "semester 2024", Novatec branding; the job title differs between this deck and the REST deck.

### Ideas to go deeper

- [ ] **Show CAP for real** once the backend has a database: two replicas, `docker network disconnect` between them, write on one side, read on the other – then decide: refuse (CP) or answer with old data (AP).
- [ ] **AI coding assistants and the service models** (asked in class): SaaS or a tool on the PaaS level? A good exam or discussion question.
- [ ] **Name the pattern:** cutting a monolith into pieces with an anti-corruption layer in between is the *Strangler Fig* pattern (Martin Fowler).
- [ ] **Dependencies in `requirements.txt` are ranges** (`fastapi>=0.115,<1.0`): explicit, but not reproducible. The image fixes the versions at build time; a lock file (`pip freeze`, `uv.lock`) fixes them in the repository. Fits factor II.
- [ ] **Traefik is in the landscape, but not a CNCF project** (Traefik Labs) – like Grafana (Oct-23).
- [ ] **REST deck before using it** (not shown yet): p. 6 calls REST "a communications protocol" – it is an architectural style; p. 12 "Stateless (on Client-side)" – it is the server that keeps no session state; "HATEOS" → HATEOAS; the constraints *cacheable* and *layered system* are missing; p. 15 says "three steps" for a model with four levels (0–3); p. 14 is a leftover agenda (Spring Cloud, Config Server); "Winter Semester 2024".
- [ ] **New polyglot example** (announced): frontend in Python, backend in Java or another language – same API, to show factor VIII.

## 2026-Nov-13

### Corrections

- [ ] **A Compose service is not a container:** "a service in that context is a container", "every service is basically a container". A service describes *how* to run a container; Compose starts one or more containers from it. The session showed it a few minutes later: `replicas: 2` – one service `backend`, two containers `shopping-backend-1` and `shopping-backend-2`. That is also the step to Kubernetes, where a Service is something else again.
- [ ] **Both replicas can be called `backend`:** "only one of them can be called backend" is not right. In a Compose network every container of a service gets the service name as a DNS alias; Docker's DNS returns the addresses of all replicas. What it does not do is balance load: the client picks an address (usually the first one) – that is why the proxy is needed.
- [ ] **`docker stop` / `start` and state:** "starting and stopping means it doesn't lose the state" – and right after, the shopping list was empty. Both are true, for different things: the writable layer, name, ports and configuration survive; the process restarts, so everything in memory is gone.
- [ ] **No sticky session:** the frontend did not stick to one backend. Every page calls the backend twice (`/hello` and `/shopping-list`); with two instances and round robin per request, `/hello` always lands on the same one. `curl /hello` directly alternates, as shown right after.
- [ ] **`VOLUME` in a Dockerfile does create a volume:** "it's just a reference to a volume and it's not going to create one". `VOLUME` declares a mount point (a path in the container, not a volume name). On every `docker run` without `-v` for that path, Docker creates a new *anonymous* volume – these pile up in `docker volume ls`. The slide (`VOLUME log-volume`) suggests a named volume; it actually creates the directory `/log-volume` as a mount point.
- [ ] **Dockerfile layers and `commit`, again:** "every line in a docker file results in a layer" (see Nov-06) – the `docker history` output in class showed `EXPOSE` and `CMD` with `0B`, metadata only. "Under the hood, the Dockerfile mechanism uses that commit command" was true for the legacy builder; BuildKit does not create intermediate containers.
- [ ] **Small slip:** "`docker run ubuntu` creates an image of that container" – it creates a container from the image.
- [ ] **Slides (Network, Storage & Compose):**
  - p. 16: the nginx bind mount goes to `/var/www/html`, but the official nginx image serves `/usr/share/nginx/html` – the example would not show the files.
  - p. 23: `openjdk` images are deprecated since 2022 (use `eclipse-temurin`); `VOLUME log-volume` see above; `CMD` lacks the closing `]`.
  - p. 20: `ubuntu:18.04` is out of standard support since 2023.
  - p. 29/32: `version: '3.7'` is obsolete – current Compose ignores it and prints a warning.
  - p. 32: PostgreSQL with `PGDATA=/var/lib/postgresql/data/pgdata` – with the current `postgres` (18) the data directory moved (see Nov-06).
  - Novatec branding.

### Ideas to go deeper

- [ ] **The broken codespace:** names resolved, but `ping`, `curl` and `nc` timed out – with plain `docker` and with Compose. A fresh codespace worked. Likely broken packet filter rules of the Docker daemon in that codespace (a student suggested iptables), not verified. Before throwing one away next time: `sudo iptables -S FORWARD`, `cat /proc/sys/net/ipv4/ip_forward` (must be `1`), `docker info`. "Codespaces: Rebuild Container" is faster than a new codespace. And test a fresh codespace before class.
- [ ] **Tutorial 04: frontend as a local process first** – noticed in class as missing. It shows that the state lives in the backend before containers come in.
- [ ] **Toolbox as a Compose service** (suggested in class): with `profiles: [debug]` it only starts on `docker compose --profile debug up`.
- [ ] **Bind mount example with nginx** ("maybe I'll add this example to the tutorial"): the start page stays on the host and is mounted instead of copied – the dynamic counterpart to the `commit` demo.
- [ ] **Sketch:** the debug container is labelled "Ubuntu", the toolbox is Alpine.
- [ ] **Rename the API paths** ("shopping list is not really a good REST thing"): e.g. `/items` and `/items/{name}` – a natural moment to talk about resource naming in REST.
- [ ] **Exam idea mentioned in class:** a long `docker run` command, explain every switch. Already in the review questions.
- [ ] **127.0.0.1 inside a container** was a strong teaching moment: the same address that worked for the local process now points to the frontend container itself. Worth keeping exactly as it happened.

## 2026-Nov-06

### Corrections

- [ ] **ARM is not the exception any more:** AWS (Graviton, since 2018), Azure (Cobalt) and Google Cloud (Axion) all offer arm64 machines, often at a lower price; add Apple Silicon and Raspberry Pi. And the other side is x86-64 (`amd64`), which includes AMD, not only Intel. Most Docker Official Images are multi-platform for exactly this reason. The sketch label "ARM-based HW (exception)" should go.
- [ ] **`docker run` does not check for a newer image:** it pulls only if the image is missing locally (`--pull=missing` is the default). An updated `latest` on Docker Hub is ignored until you run `docker pull` or `docker run --pull=always`. That is precisely why `latest` is treacherous.
- [ ] **Not every Dockerfile line is a layer:** only instructions that change the file system (`RUN`, `COPY`, `ADD`) create layers; `CMD`, `EXPOSE`, `ENV` and the like only add metadata. Starting a temporary container per step was the legacy builder; BuildKit, the default since Docker Engine 23 (2023), works differently and can run independent steps in parallel.
- [ ] **The build context is the path you pass**, not the directory you run the command in. `-f` points to the Dockerfile independently of it. (The demo with `backend/` showed it correctly.)
- [ ] **Local image store, not local registry:** a registry is a server (Docker Hub, GHCR, Harbor). `docker images` lists the local image store. On a Mac, `/var/lib/docker` is not missing because of permissions – it lives inside the Linux VM of Docker Desktop.
- [ ] **The hostname demo is namespaces at work:** each container gets its own UTS namespace, so `gethostname()` returns the container ID. Better than "each container gets its own part of the operating system" – there is still one kernel.
- [ ] **`/crash` does not crash the process:** FastAPI turns the exception into an HTTP 500 and keeps running. A real crash needs `os._exit(1)` – two lines, no Copilot needed. Combined with `docker run --restart=on-failure` it shows self-healing and leads straight to Kubernetes.
- [ ] **"Will still run in 10 years":** it will start, but its base image gets no security fixes. Images need to be rebuilt regularly, even if the code does not change.
- [ ] **Small details:** `docker logs` works on stopped containers too; any unique prefix of a container ID works, there is no minimum of three characters.

### Ideas to go deeper

- [ ] **`EXPOSE` alone publishes nothing:** the demo Dockerfile says `EXPOSE 8000`, and `curl` still fails until `-p 8000:8000` is added. Worth saying explicitly – students often expect `EXPOSE` to open the port. It is documentation in the image metadata; `-P` publishes all exposed ports to random host ports.
- [x] **Clean up `code/`:** the backend is built with `code/backend-fastapi` as context, the frontend with `code/` – exactly the build-context confusion from class. Moving each Dockerfile into its service folder (`code/backend-fastapi/Dockerfile`) makes it `docker build -t backend:v1 code/backend-fastapi`, like the multi-language samples shown.
- [ ] **Remove the tracked `__pycache__/main.cpython-314.pyc`:** `.gitignore` does not affect files that are already committed – `git rm --cached -r __pycache__`.
- [ ] **Non-root in the demo Dockerfiles:** recommended in class, but `Dockerfile-backend` and `Dockerfile-frontend` still run as root. A `USER` line would make them consistent.
- [ ] **The frontend has `timeout=5`:** a concrete countermeasure for "the network is reliable" and "latency is zero" – worth pointing out when connecting the two containers.
- [x] **State per instance:** v1 and v2 each keep their own shopping list in memory. Scaling or replacing a container loses data – the bridge to stateless services, volumes and a database.
- [ ] **Copilot acted in the background:** it built and tested the image before being asked, which is why the first `docker build` was already cached. Worth making visible to students: agent mode runs commands.
- [ ] **Multi-platform fix still to be shown live** (postponed from Oct-30 again).
- [ ] **PostgreSQL 18 moved its data directory:** the image declares the volume at `/var/lib/postgresql` (PGDATA `/var/lib/postgresql/18/docker`). Most guides still mount `/var/lib/postgresql/data` – with version 18 that no longer persists the data as expected.
- [x] **Storage by configuration instead of profiles:** FastAPI has no Spring-style profiles, but one environment variable (`DATABASE_URL`) is enough to switch the same image between memory and PostgreSQL – 12-factor "config in the environment". Used in tutorial 07.
- [ ] **Tutorial 08 idea:** swap the implementation behind the load balancer – a Spring Boot or Go backend with the same API – without touching proxy or database. The polyglot exchange from the KubeCon talk.

## 2026-Oct-30

### Corrections

- [ ] **Origin of the shipping container:** not a tobacco farmer in the 1800s. Modern containerization goes back to Malcom McLean, a US trucking entrepreneur: his converted tanker *Ideal X* carried 58 containers from Newark to Houston on 26 April 1956. McLean released his patents, which helped turn the container into an international standard.
- [ ] **The kernel is not split up:** "each container has its own slice of the kernel" is misleading. There is exactly one kernel; containers are ordinary processes on it. Namespaces restrict what a process can *see*, cgroups what it can *use*. (Explained correctly later in the session: "just an isolated Linux process".)
- [ ] **cgroups timeline:** developed at Google from 2006 under the name "process containers", merged into Linux 2.6.24 in January 2008. The building blocks were complete in 2008, not 2006. Namespaces arrived step by step from 2002 (mount) to 2013 (user namespaces).
- [ ] **LXC (2008)** was initially developed at IBM, not Canonical; Canonical sponsored it later (LXD). Google's own tool was called *lmctfy – "Let Me Contain That For You"* (2013).
- [ ] **Hypervisor type 1 runs directly on the hardware** ("bare metal"), not on an operating system. Type 2 runs on top of an operating system.
- [x] **The Apple Silicon demo:** images are built for one CPU architecture. The codespace built `linux/amd64`, the Mac is `arm64`. The "manifest" needed is an *image index* (manifest list): `docker buildx build --platform linux/amd64,linux/arm64 -t <name> --push .` builds both variants under one tag. Docker Desktop can also run amd64 images on Apple Silicon through emulation (`--platform linux/amd64`), just slower. Portability holds per architecture – a good teaching point rather than a failed demo.
- [ ] **"One process" and "only network" are conventions, not limits:** a container can run several processes, and containers can share volumes or namespaces (in Kubernetes, containers in one pod even share localhost).
- [x] **`latest` is just a tag name:** the publisher decides where it points; it is not guaranteed to be the newest version. Locally it does not change until you pull again. Pinning a version is good; pinning a digest (`postgres@sha256:…`) is fully reproducible.
- [ ] **Closing the browser does not stop a codespace:** it keeps running until the idle timeout (default 30 minutes) and keeps consuming quota. Stop it explicitly. When it stops, processes end, but files and pulled images survive. Inactive codespaces are deleted after 30 days by default.
- [ ] **Bitnami is no longer a safe recommendation:** since 28 Aug 2025, Broadcom no longer offers free versioned Bitnami images. Old images moved to `bitnamilegacy` and get no updates.
- [ ] **`docker login` with a token:** use a Docker Hub Personal Access Token instead of the account password, as the CLI suggests. In a codespace the credentials end up unencrypted in `~/.docker/config.json`.

### Ideas to go deeper

- [ ] **Docker Hub pull limits hit classrooms:** anonymous pulls are limited to 100 per 6 hours *per IP address*. A whole class behind the HFT network shares one IP. With `docker login`, each student gets 200 pulls per 6 hours of their own.
- [ ] **Fix the Apple Silicon demo live** with a multi-platform build – it shows image index, architecture and emulation in one go.
- [x] **`docker commit` vs. Dockerfile:** commit works, but is not reproducible. A Dockerfile documents how the image came about – the same reproducibility argument as the DevOps problem.
- [ ] **Sketch:** label the "OS" layer as *OS userland / base image* and show the shared kernel below the container runtime. That answers the "VM without an operating system" question from the chat.
- [x] **Image layers in practice:** `docker history <image>` shows the layers and their sizes; `docker system df` and `docker system prune` for cleaning up.

## 2026-Oct-23

### Corrections

- [ ] **Who pays for a codespace:** anyone can create a codespace from a public repository. Usage is billed to the account that *creates* the codespace, not to the repository owner. Students can open codespaces on the lecture repositories with their own quota; pushing changes needs a fork or write access.
- [ ] **Codespaces quota:** the free plan includes 120 core-hours and 15 GB storage per month – 60 hours on the default 2-core machine, 30 hours on 4 cores. Verified students get GitHub Pro via the [Student Developer Pack](https://education.github.com/pack) with 180 core-hours per month, plus Copilot access.
- [ ] **Kubernetes vs. AWS, not Azure:** Google pushed Kubernetes to compete with AWS's dominance.
- [ ] **AWS timeline:** S3 and EC2 launched in 2006. AWS's lead came from being years ahead, not from around 2015/16.
- [ ] **"Netflix was up to a quarter of AWS":** no source found. Netflix is one of AWS's largest customers. The well-known figure is a different one: Netflix made up over a third of North American peak downstream internet traffic (around 2015).
- [ ] **Gartner Magic Quadrant names changed:** Cloud Infrastructure as a Service (until 2019), Cloud Infrastructure and Platform Services (2019–2022), Strategic Cloud Platform Services (since 2023). The slide labels the 2023 quadrant as IaaS.
- [ ] **CNCF maturity levels:** there are three – sandbox, incubating, graduated – and they only exist for projects hosted by the CNCF. Grafana has none because Grafana Labs chose not to donate it: it is in the landscape, but not a CNCF project.
- [ ] **Cilium is primarily networking**, not a service mesh: a CNI with network policies and observability, based on eBPF. Service mesh is one of its features. eBPF itself is a Linux kernel technology, not a CNCF project; Cilium made it popular in cloud native.
- [ ] **OpenTracing** (in the 2017 landscape) merged with OpenCensus into OpenTelemetry in 2019 and has been archived.
- [ ] **"Ubiquitous language" is something else:** the AI answer read out in class refers to Domain-Driven Design (Eric Evans) – a shared vocabulary of developers and domain experts. NIST's "ubiquitous network access" corresponds to *broad network access*: available over the network through standard mechanisms, from any kind of client device.
- [ ] **Wording:** it is the Fallacies of Distributed *Computing*. Throttling slows requests down or limits their rate; it does not let every second request through.
- [ ] **Slides:** the Gitpod Classic slide still says "April 2025" (it ended on 15 Oct 2025); the canary slide in the patterns deck still says 66/33.

### Ideas to go deeper

- [x] **Each fallacy has a countermeasure.** Timeouts and retries with backoff (reliability, latency), caching and compression (bandwidth), TLS/mTLS (security), service discovery (topology), observability (one administrator). Retries create duplicates, which leads to **idempotency** and fits the REST session.
- [ ] **Service discovery in practice:** client-side vs. server-side discovery. In Kubernetes: DNS and Services, so no extra registry is needed.
- [x] **Serverless and scale to zero** as the extreme end of elasticity and "pay per use".
- [ ] **Shared responsibility:** who secures what in IaaS, PaaS and SaaS.
- [x] **The codespace is a container:** defined by a `devcontainer.json` ([containers.dev](https://containers.dev)) – the bridge to the container session.

## 2026-Oct-16

### Corrections

- [x] **Percentage and header-based routing do not need a service mesh any more.** The Kubernetes Gateway API (HTTPRoute) splits traffic by weight and routes by headers at the gateway. Service meshes add the same for service-to-service traffic inside the cluster, plus mTLS. (Slide: 66/33 should be 67/33.)
- [x] **A circuit breaker protects the caller from a failing dependency.** After too many errors or timeouts it opens and fails fast instead of waiting, then tries again (half-open). Protecting a system from too much incoming load is rate limiting / load shedding. A bulkhead isolates resources (e.g. separate connection pools) so one slow dependency cannot exhaust everything.
- [x] **Communication paths are Brooks's Law, not Conway's Law.** n people have n(n−1)/2 communication paths (Brooks, *The Mythical Man-Month*). Conway's Law: a system's structure mirrors the communication structure of the organisation that builds it.
- [x] **Scrum team size:** the Scrum Guide 2020 says "typically 10 or fewer people" for the whole Scrum Team (2017: 3–9 developers).
- [ ] **Docker and scaling:** `docker compose up --scale` gives DNS round-robin across the instances, so there is basic distribution, but no health checks and no rolling updates. Docker Swarm mode had both built in; Kubernetes won the orchestration race anyway.
- [ ] **Why Docker left Kubernetes:** Kubernetes talks to runtimes via the Container Runtime Interface (CRI). Docker did not implement it, so Kubernetes maintained an adapter ("dockershim"), deprecated in 1.20 (2020) and removed in 1.24 (2022). Images built with Docker keep working (OCI standard). Layers: Docker Engine → containerd → runc.
- [x] **Netflix OSS today:** Hystrix has been in maintenance mode since 2018, Ribbon and Zuul 1 as well. Spring Cloud replaced them with Resilience4j, Spring Cloud LoadBalancer and Spring Cloud Gateway. Eureka is still used.
- [ ] **CNCF size:** the CNCF is part of the Linux Foundation, so it is not the largest open source organisation. The Linux Foundation is.
- [x] **Gitpod:** Gitpod Classic (pay-as-you-go) ended on 15 Oct 2025, the company is now called Ona. GitHub Codespaces remains available.
- [ ] **PVL wording:** one Dockerfile per service, and *one* Compose file for the whole system.

### Ideas to go deeper

- [x] **Fallacies of Distributed Computing** as the first topic of the next session.
- [ ] **The price of distribution:** partial failure as the defining property (Leslie Lamport: *"A distributed system is one in which the failure of a computer you didn't even know existed can render your own computer unusable."*); availability math (five services at 99 % in a chain → 0.99⁵ ≈ 95 %; 99.9 % ≈ 8.8 h downtime per year); latency of a network call vs. an in-process call.
- [ ] **Two axes of distribution:** replication (the same software several times → availability, load) vs. decomposition (different parts separately → independent updates, polyglot, team boundaries). Three instances behind a load balancer are a distributed system, too.
- [ ] **Additions to "Why distribute?"** Consumer: partial failure instead of total outage, same state on all devices. Provider: limited blast radius, time to market, incremental modernisation (strangler fig), cost (scale only the hot component, scale to zero), disaster recovery, A/B testing.
- [ ] **NIST mapping exercise:** map the five essential characteristics to the consumer/provider sketch – resource pooling ↔ sharing resources, rapid elasticity ↔ scalability, broad network access ↔ independence of user device, on-demand self-service ↔ on-demand, measured service ↔ *missing*.
- [ ] **Scale cube** (Abbott & Fisher, *The Art of Scalability*): X = cloning, Y = functional decomposition, Z = data partitioning.
