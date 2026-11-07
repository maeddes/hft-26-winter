# Next Session: 2026-Nov-13

Prepared after 2026-Nov-06. Start at the top.

## Plan

1. **Corrections** (~5 min) – top three from [LEARNINGS.md → 2026-Nov-06](LEARNINGS.md#2026-nov-06):
   - ARM is mainstream, not an exception (Graviton, Cobalt, Axion)
   - `docker run` does not check for a newer image
   - `EXPOSE` publishes nothing – only `-p` does
2. **Homework check:** who got their own application into a container? Collect the problems, solve one or two live.
3. **Multiple containers** (as announced):
   - Backend and frontend from [`code/`](code/) on a shared Docker network – the frontend reaches the backend by its container name.
   - Volumes: persisting data, and why the in-memory shopping list is lost.
   - Docker Compose as the next step.
4. **Last year's student projects and the PVL** (as announced). Hand out the PVL spreadsheet if it is ready.

Postponed twice now: the multi-platform fix (`docker buildx build --platform linux/amd64,linux/arm64 … --push`). Fits well right before the PVL – teams with Macs will need it.

Before class: clean up `code/` (Dockerfiles into the service folders, `__pycache__` out of Git) – see LEARNINGS.

## Promised in class

- [ ] Upload the videos right after the lecture (a student asked twice – time zones)
- [ ] Publish more samples in the repository (Spring Boot, Quarkus, Hono, Go, Rust were shown)
- [ ] Spreadsheet for PVL teams and topics
- [ ] PVL description for this semester
- [ ] Fix the multi-platform image issue
- [ ] Kubernetes environment for students without a capable machine
- [ ] Find out how far the free Copilot tier gets alongside Codespaces
- [x] Upload last week's slides – done at the start of the session
