#!/bin/bash
# push-desktop-repos.sh — Turn non-repo Desktop folders into GitHub repos.
#
# Usage:
#   push-desktop-repos.sh [--dry-run]
#
# Requires:
#   - git
#   - gh CLI authenticated, OR GH_TOKEN env var set for curl fallback
#   - GitHub username in git config or GH_USER env var
#
# Excludes: CV Project, Extra CV-Proj, and anything already a git repo.

set -euo pipefail

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
fi

DESKTOP_DIR="${DESKTOP_DIR:-$HOME/Desktop}"
MANIFEST_DIR="$HOME/Projects/OS-Toolkit"
MANIFEST="$MANIFEST_DIR/desktop-repos-manifest.txt"

GH_USER="${GH_USER:-$(git config github.user || true)}"
if [ -z "$GH_USER" ]; then
    GH_USER="${GITHUB_USER:-}"
fi
if [ -z "$GH_USER" ]; then
    echo "ERROR: Set GitHub username via 'git config --global github.user <user>' or GH_USER env var."
    exit 1
fi

mkdir -p "$MANIFEST_DIR"

# Manifest header
{
    echo "# Desktop folder -> GitHub repo manifest"
    echo "# generated: $(date -Iseconds)"
    echo "# user: $GH_USER"
} > "$MANIFEST"

cd "$DESKTOP_DIR"

for dir in */; do
    dir="${dir%/}"

    # Skip files / non-dirs
    [ -d "$dir" ] || continue

    # Skip CV Project / Extra CV-Proj (local-only)
    if [[ "$dir" == "CV Project" || "$dir" == "Extra CV-Proj" ]]; then
        echo "SKIP (local-only CV): $dir"
        continue
    fi

    REPO_NAME="desktop-$(echo "$dir" | tr ' [:upper:]' '-[:lower:]' | tr -cd 'a-z0-9-')"
    # If the dir is already a git repo, use its actual remote name instead of guessing
    if [ -d "$DESKTOP_DIR/$dir/.git" ]; then
        existing_remote=$(git -C "$DESKTOP_DIR/$dir" remote get-url origin 2>/dev/null || true)
        if [ -n "$existing_remote" ]; then
            REPO_NAME=$(basename "$existing_remote" .git)
        fi
    fi

    printf '%s\t%s\thttps://github.com/%s/%s.git\n' "$dir" "$REPO_NAME" "$GH_USER" "$REPO_NAME" >> "$MANIFEST"
    echo "PROCESS: $dir -> github.com:$GH_USER/$REPO_NAME"

    if [ "$DRY_RUN" = true ]; then
        echo "  DRY RUN: would init, commit, create repo, and push"
        continue
    fi

    cd "$DESKTOP_DIR/$dir"

    if [ -d .git ] && git remote get-url origin >/dev/null 2>&1; then
        echo "  Already a git repo with remote; skipping"
        cd "$DESKTOP_DIR"
        continue
    fi

    if [ ! -d .git ]; then
        git init
        git checkout -b main 2>/dev/null || git checkout -b master
    fi

    # Commit current contents
    git add -A
    if git diff --cached --quiet; then
        echo "  Nothing to commit in $dir"
    else
        git commit -m "Initial commit of Desktop/$dir"
    fi

    # Create GitHub repo via gh or curl
    REPO_CREATED=false
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        if ! gh repo view "$GH_USER/$REPO_NAME" >/dev/null 2>&1; then
            gh repo create "$REPO_NAME" --private --source=. --push
            REPO_CREATED=true
        fi
        if [ "$REPO_CREATED" = false ]; then
            git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$GH_USER/$REPO_NAME.git"
            git push -u origin HEAD
        fi
    elif [ -n "${GH_TOKEN:-}" ]; then
        if ! curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GH_TOKEN" "https://api.github.com/repos/$GH_USER/$REPO_NAME" | grep -q '^20'; then
            curl -s -H "Authorization: token $GH_TOKEN" \
                 -H "Accept: application/vnd.github.v3+json" \
                 -d "{\"name\":\"$REPO_NAME\",\"private\":true}" \
                 "https://api.github.com/user/repos" >/dev/null
        fi
        git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://$GH_TOKEN@github.com/$GH_USER/$REPO_NAME.git"
        git push -u origin HEAD
    else
        echo "ERROR: No GitHub auth. Install 'gh' and login, or set GH_TOKEN."
        exit 1
    fi

cd "$DESKTOP_DIR"
done

echo ""
echo "Done. Manifest: $MANIFEST"
