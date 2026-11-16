# Next Session: 2026-Nov-20

Prepared after 2026-Nov-13. Start at the top.

## Plan

1. **What was wrong with the codespace** (~5 min): names resolved, connections timed out, a fresh codespace worked. Then redo the part that failed – frontend and backend on `shop-net`, toolbox in the network – in a codespace tested before class ([tutorial 04](tutorials/04-container-networking.md)).
2. **Corrections** (~5 min) – top three from [LEARNINGS.md → 2026-Nov-13](LEARNINGS.md#2026-nov-13):
   - A Compose service is not a container – `replicas: 2` gives two containers, both reachable as `backend`
   - `docker stop` / `start` keep the file system, not the memory
   - `VOLUME` in a Dockerfile creates an anonymous volume on every run
3. **Traefik explained** (as announced): Docker provider and labels, the dashboard on port 8080, round robin per request – and why the frontend seems stuck on one instance ([tutorial 07](tutorials/07-scaling.md)).
4. **Storage live:** the nginx start page as a bind mount (promised), then a named volume. The backend in `code/` still gets no database.
5. **Last year's PVL examples and suggestions** (as announced) – the PVL can start now.

Before class: test a fresh codespace (`docker compose up` plus the toolbox), and send the tutorial update if not done yet.

**To confirm:** "two sessions from now, there is no session (Studienprojekt)" – that would be 2026-Nov-27. Tell the students.

## Promised in class

- [ ] Update the tutorials and send them out "by Sunday" (Nov-15): frontend as a local process in 04, bind mount example, toolbox – see LEARNINGS
- [ ] Explain Traefik in detail
- [ ] Repeat the toolbox debugging quickly at the start
- [ ] Find out what broke the codespace ("fix this until next week")
- [ ] Examples from last year's PVL groups, suggestions for topics
- [ ] Upload the videos right after the lecture
- [ ] Publish more samples in the repository (Spring Boot, Quarkus, Hono, Go, Rust were shown)
- [ ] Spreadsheet for PVL teams and topics
- [ ] PVL description for this semester
- [ ] Fix the multi-platform image issue
- [ ] Kubernetes environment for students without a capable machine
- [ ] Find out how far the free Copilot tier gets alongside Codespaces
