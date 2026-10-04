# solo-operator — projects root

Infrastructure / orchestration layer for the local **solo-operator** stack.
Application code lives in the two nested, separately-versioned repos.

## Layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Unified compose file — api, redis, pipeline, dashboard, status |
| `run.ps1` | Master task runner (status / test / lint / build / deploy / watch) |
| `auto-recovery.ps1` | Health & recovery checks (Docker, WSL, containers, disk) |
| `status/` | nginx status page (served on `:8080`) |
| `NEXT-STEPS.md` | Planning notes |
| `my-node-app/` | ↳ own git repo — Express API (`:3000`) |
| `csv-pipeline/` | ↳ own git repo — CSV pipeline + FastAPI dashboard (`:8500`) |

## Git hygiene

- **`.gitattributes`** pins line endings: the index is always LF, while
  `*.ps1` files are checked out as CRLF on Windows. Prevents EOL churn in
  the nightly auto-commits.
- **`.gitignore`** keeps secrets (`.env*`, `*.key`, `*.pem`, `*.pgpass`, …)
  and the two nested repos out of this repository (no gitlinks).
- **`.githooks/pre-commit`** blocks credential files and high-confidence
  secret patterns (PEM private keys, AWS / GitHub / Slack / Google tokens).
  Bypass only when certain: `git commit --no-verify`.

### Enable the hook (must be done once per clone — it is local config)

```sh
git config core.hooksPath .githooks
```

## Related

- Nightly git auto-commit + daily maintenance both append to
  `C:\Users\mufftop\maintenance.log`.
- No remotes are configured yet; the nightly job skips `git push` until an
  `origin` exists.
