#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="_site"

DO_DEPLOY=false
DO_PUSH=false
for arg in "$@"; do
  case "$arg" in
    --deploy) DO_DEPLOY=true ;;
    --push)   DO_PUSH=true ;;
  esac
done

echo "==> Cleaning old generated files..."
rm -f index.html blog.html
rm -f blog/*.html blog/feed.atom
rm -rf tagged/

echo "==> Installing dependencies..."
bundle install

echo "==> Building site with Jekyll..."
bundle exec jekyll build

if [ "$DO_DEPLOY" = true ]; then
  echo ""
  echo "==> Syncing _site/ to repository root..."
  rsync -a --delete \
    --exclude="_site" \
    --exclude=".git" \
    --exclude=".bundle" \
    --exclude=".jekyll-cache" \
    --exclude=".ruby-lsp" \
    --exclude="_posts" \
    --exclude="_layouts" \
    --exclude="_includes" \
    --exclude="_my_tags" \
    --exclude="_data" \
    --exclude="_drafts" \
    --exclude="Gemfile" \
    --exclude="Gemfile.lock" \
    --exclude="_config.yml" \
    --exclude=".gitignore" \
    --exclude=".domains" \
    --exclude="build.sh" \
    --exclude="/index.md" \
    --exclude="/blog.md" \
    "$SITE_DIR/" .

  echo ""
  echo "==> Deploy synced to root."

  if [ "$DO_PUSH" = true ]; then
    REMOTE=$(git remote | head -1)
    echo ""
    echo "==> Staging all changes..."
    git add -A

    if git diff --cached --quiet; then
      echo "==> Nothing to commit."
    else
      git commit -m "deploy: rebuild site"
      echo "==> Pushing to $REMOTE/main..."
      git push "$REMOTE" main
      echo "==> Done. Site deployed to Codeberg Pages."
    fi
  fi
fi
