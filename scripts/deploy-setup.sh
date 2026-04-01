#!/bin/bash
# =============================================================================
# deploy-setup.sh
# First-time Replit → GitHub → Render setup script
#
# Pull into any Replit project and run:
#   curl -s https://raw.githubusercontent.com/tmenna/REPO/main/scripts/deploy-setup.sh | bash
# Or if already cloned:
#   bash scripts/deploy-setup.sh
# =============================================================================

set -e

BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

header() { echo -e "\n${CYAN}${BOLD}=== $1 ===${RESET}\n"; }
step()   { echo -e "${GREEN}▶ $1${RESET}"; }
note()   { echo -e "${YELLOW}⚠ $1${RESET}"; }
pause()  { echo -e "\n${BOLD}$1${RESET}"; read -p "  Press ENTER when done..."; }

clear
echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   Replit → GitHub → Render Setup Tool   ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"

# =============================================================================
# STEP 1 — Collect config
# =============================================================================
header "Configuration"
echo "Answer the prompts below. Press ENTER to accept the default in [brackets]."
echo ""

read -p "  GitHub username [tmenna]: " GITHUB_USER
GITHUB_USER=${GITHUB_USER:-tmenna}

read -p "  Repository name (must match your GitHub repo): " REPO_NAME
while [ -z "$REPO_NAME" ]; do
  echo "  Repository name cannot be empty."
  read -p "  Repository name: " REPO_NAME
done

read -p "  App display name for Render [${REPO_NAME}]: " APP_NAME
APP_NAME=${APP_NAME:-$REPO_NAME}

echo ""
echo "  App type:"
echo "    1) static  — React/Vite, no server (free, no sleep)"
echo "    2) node    — Express/Node.js server"
read -p "  Choose [1]: " APP_TYPE_INPUT
APP_TYPE_INPUT=${APP_TYPE_INPUT:-1}
if [ "$APP_TYPE_INPUT" = "2" ] || [ "$APP_TYPE_INPUT" = "node" ]; then
  APP_TYPE="node"
else
  APP_TYPE="static"
fi

read -p "  pnpm workspace package name (e.g. holtek-solutions): " PKG_NAME
while [ -z "$PKG_NAME" ]; do
  echo "  Package name cannot be empty."
  read -p "  pnpm workspace package name: " PKG_NAME
done

if [ "$APP_TYPE" = "static" ]; then
  read -p "  Build output path relative to project root [artifacts/${PKG_NAME}/dist/public]: " PUBLISH_PATH
  PUBLISH_PATH=${PUBLISH_PATH:-artifacts/${PKG_NAME}/dist/public}
fi

echo ""
step "Config summary:"
echo "    GitHub user : $GITHUB_USER"
echo "    Repo name   : $REPO_NAME"
echo "    App name    : $APP_NAME"
echo "    App type    : $APP_TYPE"
echo "    Package     : $PKG_NAME"
[ "$APP_TYPE" = "static" ] && echo "    Publish path: $PUBLISH_PATH"
echo ""
read -p "Looks good? Press ENTER to continue (or Ctrl+C to abort)..."

# =============================================================================
# STEP 2 — SSH key
# =============================================================================
header "SSH Key"

if [ -f ~/.ssh/id_ed25519 ]; then
  note "SSH key already exists — skipping generation."
else
  step "Generating SSH key..."
  ssh-keygen -t ed25519 -C "${REPO_NAME}-replit" -f ~/.ssh/id_ed25519 -N ""
  step "SSH key created."
fi

step "Writing SSH config..."
mkdir -p ~/.ssh
cat > ~/.ssh/config << 'SSHEOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking no
SSHEOF
chmod 600 ~/.ssh/config
chmod 700 ~/.ssh

echo ""
echo -e "${BOLD}Your public key (copy everything below the line):${RESET}"
echo "────────────────────────────────────────────────"
cat ~/.ssh/id_ed25519.pub
echo "────────────────────────────────────────────────"

pause "ACTION: Go to https://github.com/settings/ssh/new and paste the key above"

# =============================================================================
# STEP 3 — Test SSH
# =============================================================================
header "Testing GitHub SSH Connection"
step "Connecting to GitHub..."
SSH_RESULT=$(ssh -T git@github.com 2>&1 || true)
echo "  $SSH_RESULT"

if echo "$SSH_RESULT" | grep -q "successfully authenticated"; then
  step "SSH connection confirmed."
else
  note "SSH connection failed. Make sure you added the key to GitHub before continuing."
  echo "  Result: $SSH_RESULT"
  pause "Try adding the key again, then press ENTER to retry"
  ssh -T git@github.com 2>&1 || true
fi

# =============================================================================
# STEP 4 — render.yaml
# =============================================================================
header "Generating render.yaml"

if [ "$APP_TYPE" = "static" ]; then
  cat > render.yaml << YAML
services:
  - type: web
    name: ${APP_NAME}
    runtime: static
    branch: main
    buildCommand: npm install -g pnpm && pnpm install && pnpm --filter @workspace/${PKG_NAME} run build
    staticPublishPath: ./${PUBLISH_PATH}
    envVars:
      - key: NODE_ENV
        value: production
      - key: BASE_PATH
        value: /
      - key: PORT
        value: 3000
YAML
  note "Static sites: 'region' and 'plan' are intentionally omitted — Render errors if they are present."
else
  cat > render.yaml << YAML
services:
  - type: web
    name: ${APP_NAME}
    plan: free
    runtime: node
    region: oregon
    branch: main
    buildCommand: npm install -g pnpm && pnpm install --include=dev && pnpm --filter @workspace/${PKG_NAME} run build
    startCommand: pnpm --filter @workspace/${PKG_NAME} run start
    healthCheckPath: /api/healthz
    envVars:
      - key: NODE_ENV
        value: production
      - key: SESSION_SECRET
        generateValue: true
YAML
  note "Dynamic app: add a 'databases:' block to render.yaml if your app needs PostgreSQL."
fi

step "render.yaml written."

# =============================================================================
# STEP 5 — .gitignore
# =============================================================================
header "Updating .gitignore"

GITIGNORE_ENTRIES=(
  "node_modules/"
  "dist/"
  ".env"
  "uploads/"
  ".replit"
  "replit.nix"
  ".replitignore"
  ".local/"
  ".cache/"
)

for entry in "${GITIGNORE_ENTRIES[@]}"; do
  if ! grep -qxF "$entry" .gitignore 2>/dev/null; then
    echo "$entry" >> .gitignore
    echo "  Added: $entry"
  fi
done
step ".gitignore up to date."

# =============================================================================
# STEP 6 — Git config and remote
# =============================================================================
header "Configuring Git"

step "Setting git identity..."
git config user.name "$GITHUB_USER"
git config user.email "${GITHUB_USER}@users.noreply.github.com"

step "Setting remote origin..."
if git remote get-url origin &>/dev/null; then
  git remote set-url origin "git@github.com:${GITHUB_USER}/${REPO_NAME}.git"
  echo "  Updated existing remote."
else
  git remote add origin "git@github.com:${GITHUB_USER}/${REPO_NAME}.git"
  echo "  Remote added."
fi

# =============================================================================
# STEP 7 — Create GitHub repo (manual)
# =============================================================================
header "Create GitHub Repository"
echo "  You need to create the repository on GitHub before pushing."
echo ""
echo "  URL  : https://github.com/new"
echo "  Name : ${REPO_NAME}"
echo "  Set  : Private"
echo "  Note : Do NOT initialize with README"
echo ""
pause "ACTION: Create the repo on GitHub, then press ENTER"

# =============================================================================
# STEP 8 — Push
# =============================================================================
header "Pushing to GitHub"

step "Staging files..."
git add .

step "Creating initial commit..."
git diff --cached --quiet && echo "  Nothing new to commit — skipping." || git commit -m "Initial commit"

step "Pushing to origin/main..."
git push -u origin main

# =============================================================================
# DONE
# =============================================================================
header "All Done!"
echo "  Your code is now on GitHub:"
echo "  https://github.com/${GITHUB_USER}/${REPO_NAME}"
echo ""
echo -e "${BOLD}  Final step — Deploy on Render:${RESET}"
echo "  1. Go to https://render.com and sign in with GitHub"
echo "  2. Click  New → Blueprint"
echo "  3. Select your repository: ${REPO_NAME}"
echo "  4. Render reads render.yaml automatically — click Apply"
echo "  5. Wait 3–8 minutes"
echo "  6. Live at: https://${APP_NAME}.onrender.com"
echo ""
echo "  For future updates run:  bash scripts/deploy-push.sh"
echo ""
