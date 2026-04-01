#!/bin/bash
# =============================================================================
# deploy-push.sh
# Push updates to GitHub (Render redeploys automatically)
#
# Usage:
#   bash scripts/deploy-push.sh
#   bash scripts/deploy-push.sh "My commit message"
# =============================================================================

BOLD="\033[1m"
GREEN="\033[32m"
CYAN="\033[36m"
RESET="\033[0m"

header() { echo -e "\n${CYAN}${BOLD}=== $1 ===${RESET}\n"; }
step()   { echo -e "${GREEN}▶ $1${RESET}"; }

header "Deploy Push"

# Get commit message from argument or prompt
if [ -n "$1" ]; then
  COMMIT_MSG="$1"
else
  read -p "  Commit message: " COMMIT_MSG
  while [ -z "$COMMIT_MSG" ]; do
    echo "  Commit message cannot be empty."
    read -p "  Commit message: " COMMIT_MSG
  done
fi

step "Staging all changes..."
git add .

if git diff --cached --quiet; then
  echo "  Nothing to commit — working tree is clean."
  exit 0
fi

step "Committing..."
git commit -m "$COMMIT_MSG"

step "Pushing to GitHub..."
git push origin main

echo ""
echo -e "${BOLD}  Done! Render will auto-deploy in ~4 minutes.${RESET}"
REMOTE=$(git remote get-url origin 2>/dev/null | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
[ -n "$REMOTE" ] && echo "  Repo: $REMOTE"
echo ""
