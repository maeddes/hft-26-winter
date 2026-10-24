# Learnings

Corrections and ideas collected after each session: what was imprecise, outdated or worth going deeper. Newest on top.

- [x] addressed in class
- [ ] not yet addressed (or only published here)

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

- [ ] **Each fallacy has a countermeasure.** Timeouts and retries with backoff (reliability, latency), caching and compression (bandwidth), TLS/mTLS (security), service discovery (topology), observability (one administrator). Retries create duplicates, which leads to **idempotency** and fits the REST session.
- [ ] **Service discovery in practice:** client-side vs. server-side discovery. In Kubernetes: DNS and Services, so no extra registry is needed.
- [ ] **Serverless and scale to zero** as the extreme end of elasticity and "pay per use".
- [ ] **Shared responsibility:** who secures what in IaaS, PaaS and SaaS.
- [ ] **The codespace is a container:** defined by a `devcontainer.json` ([containers.dev](https://containers.dev)) – the bridge to the container session.

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
