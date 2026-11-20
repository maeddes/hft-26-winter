# Next Session: 2026-Dec-04

Prepared after 2026-Nov-20. No session on Nov-27 (Studienprojekt). Start at the top.

## Plan

1. **Corrections** (~5 min) – top three from [LEARNINGS.md → 2026-Nov-20](LEARNINGS.md#2026-nov-20):
   - The P in CAP is partition *tolerance* – a broken network between nodes, not "several instances"
   - The bank example is CP, not AP
   - `docker compose push` exists – Compose can push the images it built
2. **Tutorial 07 once more** (as announced: "definitely gonna repeat that next time"), two terminals side by side: request loop, scale, kill, `restart: on-failure`.
3. **State out of the instances** (announced as the goal: "a full-blown application with a network component, a database component, scaled instances"):
   - backend with a database, configured by `DATABASE_URL` (factor III), so the shopping list survives restarts and is the same on every instance
   - then the CAP question for real: two replicas, cut the network between them (idea in LEARNINGS)
4. **Last year's PVL examples and suggestions** – announced on Nov-13, not done yet. Start the PVL.
5. If there is time: **REST** – the slides were shared but not covered; fits with renaming `/shopping-list` (Nov-13 idea). Look at the slide notes in LEARNINGS first.

Before class: decide how the database gets into `code/` – until now the rule was "no database in the backend yet". Rework [tutorial 08](tutorials/08-state.md) accordingly (still a draft on `shopping-api`). Test in a fresh codespace.

## Promised in class

- [ ] Repeat tutorial 07 (Nov-20)
- [ ] Database for the backend, scaled instances with shared state (Nov-20)
- [ ] A new example with a backend in another language, e.g. Java (Nov-20)
- [ ] Look deeper into CAP, the fallacies and resilience later on; Kubernetes and OpenTelemetry later in the semester (Nov-20)
- [ ] Examples from last year's PVL groups, suggestions for topics (Nov-13)
- [ ] Repeat the toolbox debugging quickly (Nov-13)
- [ ] Find out what broke the codespace on Nov-13
- [ ] Upload the videos right after the lecture
- [ ] Publish more samples in the repository (Spring Boot, Quarkus, Hono, Go, Rust were shown)
- [ ] Spreadsheet for PVL teams and topics
- [ ] PVL description for this semester
- [ ] Fix the multi-platform image issue
- [ ] Kubernetes environment for students without a capable machine
- [ ] Find out how far the free Copilot tier gets alongside Codespaces
- [x] Tutorials updated: frontend as a local process (04), Compose build vs. image (06), Traefik explained (07), scripts
