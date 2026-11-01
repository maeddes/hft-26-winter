# Next Session: 2026-Nov-06

Prepared after 2026-Oct-30. Start at the top.

## Plan

1. **Corrections** (~10 min). Open in [LEARNINGS.md](LEARNINGS.md): 11 from Oct-30, 12 from Oct-23, 4 from Oct-16. Too many for one slot – suggested top five:
   - Shipping container origin: Malcom McLean, *Ideal X*, 1956 (Oct-30)
   - The kernel is not split up – containers are isolated processes on one kernel (Oct-30)
   - The Apple Silicon demo: CPU architecture and multi-platform images (Oct-30)
   - Who pays for a codespace, and closing the browser does not stop it (Oct-23, Oct-30)
   - Kubernetes was Google's answer to AWS, not Azure (Oct-23)
2. **Fix last week's demo live:** build the image as multi-platform (`docker buildx build --platform linux/amd64,linux/arm64 … --push`) and run it on the Mac. Shows architecture, image index and emulation.
3. **Containers, continued** (as announced):
   - A small REST service in a container – a long-running process instead of `cat`.
   - Networks and volumes: connecting containers, persisting data.
   - Docker Compose as the step towards a multi-container application.
4. **Practical tip for the class:** `docker login` before pulling. Anonymous pulls share one limit per IP – the whole class behind the HFT network.

Announced in class: be there in person, more live hacking, possibly not everything recorded.

Still open from earlier sessions: NIST essential characteristics and deployment models, shared responsibility, price of distribution, two axes of distribution – all in [LEARNINGS.md](LEARNINGS.md). Carried over twice now: cover briefly, or drop.

## Promised in class

- [ ] Fix the multi-platform image issue ("homework until next time")
- [ ] Spreadsheet for PVL teams and topics
- [ ] PVL description for this semester
- [ ] Kubernetes environment for students without a capable machine
- [ ] Find out how far the free Copilot tier gets alongside Codespaces
- [x] Link the Docker video a student recommended – now in the README
- [x] Docker tutorial – partly covered by the recommended video
