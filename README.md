# docker-agent-lab

Experiments with [Docker Agent](https://github.com/docker/cagent) configs running on local Ollama cloud models.
CLI only, no Docker Desktop, small disk footprint. Developed on Debian (WSL2).

## Prerequisites

- `docker-agent` standalone binary (e.g. `~/.local/bin/docker-agent`)
- [Ollama](https://ollama.com) running on `http://localhost:11434`
- Access to the Ollama cloud models the configs use (`nemotron-3-super:cloud`, `nemotron-3-ultra:cloud`)

Quick check:

```bash
docker-agent version
curl -s http://localhost:11434/api/tags | head -c 200
```

## Layout

```
agents/   agent configs (one YAML per experiment)
bench/    benchmark scripts and results
docs/     notes
fetched/  saved source pages (generated)
sandbox/  scratch space
```

## Agents

| File | Purpose |
|---|---|
| `agents/local.yaml` | Minimal single agent on `ollama/nemotron-3-super:cloud` |
| `agents/02-file-reader.yaml` | Agent that reads local files |
| `agents/03-team.yaml` | Multi-agent team |
| `agents/04-writer-critic.yaml` | Writer plus critic loop |
| `agents/20-pan-research.yaml` | Palo Alto Networks docs research pipeline (below) |

Run any config from the repo root:

```bash
docker-agent run --exec agents/local.yaml "your prompt"
```

Run from the repo root. If you are inside `agents/`, drop the `agents/` prefix.

## 20-pan-research: PANW docs research pipeline

Answers questions about Palo Alto Networks products (deepest on Prisma Cloud and Cortex Cloud) using only official documentation, and produces a compact briefing.

```
question -> researcher -> verifier -> writer -> briefing
```

| Agent | Model | Job |
|---|---|---|
| root | nemotron-3-super | Passes each step's output to the next, unchanged |
| researcher | nemotron-3-super | Fetches doc pages and extracts facts with exact quotes |
| verifier | nemotron-3-ultra | Re-fetches each URL, confirms the quote is verbatim, assigns a verdict |
| writer | nemotron-3-super | Writes the briefing from SUPPORTED facts only |

### Run

```bash
docker-agent run --exec agents/20-pan-research.yaml \
  "Why migrate from Prisma Cloud to Cortex Cloud?" 2>&1 | tee run.log
```

Extract just the final briefing and normalise characters:

```bash
awk '/^# PANW Briefing/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' run.log \
  | sed "s/‑/-/g; s/’/'/g" > briefing.md
```

Fetch calls prompt for approval. Answer `a` once for the session, or pass `--yolo` to skip prompts (needed when stdin is not a TTY).

### Output

Normal run:

```
# PANW Briefing: <topic>
**Bottom line:** ...
**Why move** / **How migration works** / **To confirm** / **Sources**
```

Special results:

- `OUT OF SCOPE: ...` the question is not about PANW
- `NO FACTS FOUND: ...` the sources did not answer
- Briefing with `Bottom line: No claims could be verified` every fact was rejected (see **To confirm**)
- `NO SUPPORTED FACTS AVAILABLE FOR BRIEFING.` the verifier returned nothing

### Safety

- `permissions.deny` blocks `write_*` and `exec_*`
- Fetch toolsets are limited to `paloaltonetworks.com`, `prismacloud.io`, `pan.dev`, `cortex-docs.paloaltonetworks.com`
- Quotes may only come from real documentation pages. Any URL containing `?` (including the GitBook `?ask=` endpoint, which returns generated answers) is rejected by the verifier

### Known limitations

- Small models are nondeterministic. A run can fail verification and need a re-run
- The docs `?ask=` endpoint is slow and often times out, so migration questions use seed pages instead
- The researcher may extract only a few facts per page. Check **Sources** against the pages for completeness
- Briefings reflect vendor documentation, not independent testing

## Conventions

- Setup instructions are CLI-only
- Keep generated output (`run.log`, `briefing.md`, `fetched/`) out of git
