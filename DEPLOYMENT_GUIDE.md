# Replit → GitHub → Render Deployment Guide
### A Reusable Workflow for Any App (Static or Dynamic)

---

## Overview

```
Replit          →       GitHub        →       Render
(development)       (version control)        (hosting)
```

- **Replit** — where you build and test
- **GitHub** — where your code lives and acts as the deploy trigger
- **Render** — where your app runs in production

---

## Quickstart — Automated Scripts

Two scripts in `scripts/` handle everything that can be automated inside Replit.
Pull them into any new project from GitHub and run directly.

### First-time setup (run once per project)

```bash
bash scripts/deploy-setup.sh
```

This script will:
- Generate your SSH key and configure it for GitHub
- Ask you a few questions (username, repo name, app type, package name)
- Auto-generate the correct `render.yaml` for your app type
- Update `.gitignore`
- Configure your git identity and remote
- Walk you through the two manual steps (adding the SSH key to GitHub, creating the repo)
- Push your code

### Every future update (run after each code change)

```bash
bash scripts/deploy-push.sh "Describe what changed"
```

Or without an argument — it will prompt you for the message:

```bash
bash scripts/deploy-push.sh
```

### Pull the scripts into a fresh Replit project

Once this repo is on GitHub, you can pull the scripts into any new project:

```bash
# Pull just the scripts folder
curl -s https://raw.githubusercontent.com/tmenna/REPO-NAME/main/scripts/deploy-setup.sh -o deploy-setup.sh  # <-- CHANGE REPO-NAME
bash deploy-setup.sh
```

> Replace `REPO-NAME` with the actual repository you stored these scripts in.

---

## What Stays Manual (Outside Replit)

The scripts pause and give you exact URLs and instructions for the two steps that require a browser:

| Step | Where | What to do |
|---|---|---|
| Add SSH key | [github.com/settings/ssh/new](https://github.com/settings/ssh/new) | Paste your public key |
| Create repo | [github.com/new](https://github.com/new) | Name it, set Private, no README |
| Deploy | [render.com](https://render.com) | New → Blueprint → select repo → Apply |

---

## Manual Reference (if not using the scripts)

### render.yaml — Option A: Static Site (React/Vite, no server)

```yaml
services:
  - type: web
    name: repo-name              # <-- CHANGE THIS
    runtime: static
    branch: main
    buildCommand: npm install -g pnpm && pnpm install && pnpm --filter @workspace/pkg-name run build  # <-- CHANGE pkg-name
    staticPublishPath: ./artifacts/pkg-name/dist/public                                               # <-- CHANGE pkg-name
    envVars:
      - key: NODE_ENV
        value: production
      - key: BASE_PATH
        value: /
      - key: PORT
        value: 3000
```

> Static site rules — Render will error if violated:
> - Do **not** add `region`
> - Do **not** add `plan`

---

### render.yaml — Option B: Dynamic App (Node.js / Express)

```yaml
services:
  - type: web
    name: repo-name              # <-- CHANGE THIS
    plan: free
    runtime: node
    region: oregon               # <-- CHANGE if needed
    branch: main
    buildCommand: npm install -g pnpm && pnpm install --include=dev && pnpm --filter @workspace/pkg-name run build  # <-- CHANGE pkg-name
    startCommand: pnpm --filter @workspace/pkg-name run start                                                       # <-- CHANGE pkg-name
    healthCheckPath: /api/healthz
    envVars:
      - key: NODE_ENV
        value: production
      - key: SESSION_SECRET
        generateValue: true
```

---

### render.yaml — Option B + PostgreSQL

```yaml
databases:
  - name: repo-name-db          # <-- CHANGE THIS
    databaseName: appdb         # <-- CHANGE THIS
    user: appuser               # <-- CHANGE THIS

services:
  - type: web
    name: repo-name             # <-- CHANGE THIS
    plan: free
    runtime: node
    region: oregon
    branch: main
    buildCommand: npm install -g pnpm && pnpm install --include=dev && pnpm --filter @workspace/pkg-name run build && pnpm --filter @workspace/db run push
    startCommand: pnpm --filter @workspace/pkg-name run start
    healthCheckPath: /api/healthz
    envVars:
      - key: NODE_ENV
        value: production
      - key: SESSION_SECRET
        generateValue: true
      - key: DATABASE_URL
        fromDatabase:
          name: repo-name-db    # <-- CHANGE THIS to match databases[0].name
          property: connectionString
```

---

### Git commands (manual)

```bash
# First time
git config user.name "tmenna"
git config user.email "tmenna@users.noreply.github.com"
git remote add origin git@github.com:tmenna/repo-name.git   # <-- CHANGE repo-name
git add .
git commit -m "Initial commit"
git push -u origin main

# Test SSH
ssh -T git@github.com
# Expected: Hi tmenna! You've successfully authenticated

# Every future update
git add .
git commit -m "Describe what changed"
git push origin main
```

---

## Quick Reference — What to Change Per Project

| Item | Where | What to set |
|---|---|---|
| App name | `render.yaml` → `name:` | Your app's slug, e.g. `my-app` |
| Build filter | `render.yaml` → `buildCommand` | Your pnpm workspace package name |
| Start filter | `render.yaml` → `startCommand` (dynamic only) | Your pnpm workspace package name |
| Publish path | `render.yaml` → `staticPublishPath` (static only) | Path to built output folder |
| Runtime | `render.yaml` → `runtime:` | `static` or `node` |
| Repo name | Git remote URL | Your GitHub repository name |
| Database name | `render.yaml` → `databases[0].name` | Unique identifier for your DB |

---

## Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `static sites cannot have a region` | `region:` present for static type | Remove the `region:` field |
| `no such plan free for service type web` | `plan:` present for static type | Remove the `plan:` field |
| `tsx: not found` during build | Build skipped devDependencies | Use `npm install --include=dev` |
| App crashes on start | Port hardcoded | Use `process.env.PORT` in server |
| `DATABASE_URL must be set` | Env var not linked | Use `fromDatabase` in render.yaml |
| SSH push rejected | Key not added to GitHub | Re-run `deploy-setup.sh` step 2 |
