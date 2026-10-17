# Next Session: 2026-Oct-23

Prepared after the kick-off on 2026-Oct-16. Start at the top.

## Plan

1. **Corrections from last session** (~10 min, list below)
2. **Fallacies of Distributed Computing**, the first topic. Together with the price of distribution:
   - Partial failure as the defining property. Hook (Leslie Lamport): *"A distributed system is one in which the failure of a computer you didn't even know existed can render your own computer unusable."*
   - Availability math: five services in a chain at 99 % each → 0.99⁵ ≈ 95 %. Without redundancy, distribution *lowers* availability. 99.9 % ≈ 8.8 h downtime per year.
   - Latency: a network call is orders of magnitude slower than an in-process call ("Latency Numbers Every Programmer Should Know").
3. **Revisit the consumer/provider sketch** and add what is missing (see below).
4. **Two axes of distribution**
   - Replication: the same software several times → availability, load distribution. Leads to containers.
   - Decomposition: different parts separately → independent updates, polyglot, team boundaries.
5. **Bridge to cloud: exercise.** Map the sketch to the five NIST essential characteristics. The students derived most of the cloud definition themselves:

   | NIST characteristic | already on the sketch / brainstorm |
   |---|---|
   | Resource pooling | Sharing Resources |
   | Rapid elasticity | Scalability |
   | Broad network access | independence of user device |
   | On-demand self-service | on-demand |
   | Measured service | *missing* → pay per use |

6. **Service models** (IaaS, PaaS, SaaS) as "who operates which layer?" → CaaS → containers

Later, not now: CAP (with persistence; "same state on all devices" is the hook), data sovereignty.

## Additions to "Why distribute?"

**Consumer**
- Partial failure instead of total outage: recommendations are gone, streaming still works
- Same state on all devices: stop on the phone, continue on the TV (leads to state and consistency)

**Provider**
- Limited blast radius: one failure does not take everything down
- Time to market: each team releases at its own pace
- Incremental modernisation: replace a legacy system piece by piece (strangler fig)
- Cost: scale only the hot component, scale to zero, pay per use
- Disaster recovery: several zones or regions
- Experiments: A/B testing

## Fallacies of Distributed Computing

1. The network is reliable.
2. Latency is zero.
3. Bandwidth is infinite.
4. The network is secure.
5. Topology doesn't change.
6. There is one administrator.
7. Transport cost is zero.
8. The network is homogeneous.

## Corrections from 2026-Oct-16

1. **Percentage and header-based routing do not need a service mesh any more.** The Kubernetes Gateway API (HTTPRoute) splits traffic by weight and routes by headers at the gateway. Service meshes add the same for service-to-service traffic inside the cluster, plus mTLS. (Slide: 66/33 should be 67/33.)
2. **A circuit breaker protects the caller from a failing dependency.** After too many errors or timeouts it opens and fails fast instead of waiting, then tries again (half-open). Protecting a system from too much incoming load is rate limiting / load shedding. A bulkhead isolates resources (e.g. separate connection pools) so one slow dependency cannot exhaust everything.
3. **Communication paths are Brooks's Law, not Conway's Law.** n people have n(n−1)/2 communication paths (Brooks, *The Mythical Man-Month*). Conway's Law: a system's structure mirrors the communication structure of the organisation that builds it.
4. **Scrum team size:** the Scrum Guide 2020 says "typically 10 or fewer people" for the whole Scrum Team (2017: 3–9 developers).
5. **Docker and scaling:** `docker compose up --scale` gives DNS round-robin across the instances, so there is basic distribution, but no health checks and no rolling updates. Docker Swarm mode had both built in; Kubernetes won the orchestration race anyway.
6. **Why Docker left Kubernetes:** Kubernetes talks to runtimes via the Container Runtime Interface (CRI). Docker did not implement it, so Kubernetes maintained an adapter ("dockershim"), deprecated in 1.20 (2020) and removed in 1.24 (2022). Images built with Docker keep working (OCI standard). Layers: Docker Engine → containerd → runc.
7. **Netflix OSS today:** Hystrix has been in maintenance mode since 2018, Ribbon and Zuul 1 as well. Spring Cloud replaced them with Resilience4j, Spring Cloud LoadBalancer and Spring Cloud Gateway. Eureka is still used.
8. **CNCF size:** the CNCF is part of the Linux Foundation, so it is not the largest open source organisation. The Linux Foundation is.
9. **Gitpod:** Gitpod Classic (pay-as-you-go) ended on 15 Oct 2025, the company is now called Ona. GitHub Codespaces remains available.
10. **PVL wording:** one Dockerfile per service, and *one* Compose file for the whole system.

## Promised in the kick-off

- [ ] Link to this repository in Moodle
- [ ] Docker tutorial (the former Novatec one is offline)
- [ ] Kubernetes environment for students without a capable machine
- [ ] PVL description for this semester
