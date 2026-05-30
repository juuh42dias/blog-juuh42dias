#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="_site"
DEPLOY_FLAG="${1:-}"

# Remove static HTML files that would conflict with Jekyll-generated output
echo "==> Cleaning old generated files..."
rm -f blog/*.html blog/feed.atom
rm -rf tagged/

echo "==> Installing dependencies..."
bundle install

echo "==> Building site with Jekyll..."
bundle exec jekyll build

if [ "$DEPLOY_FLAG" = "--deploy" ]; then
  echo ""
  echo "==> Syncing _site/ to repository root for Codeberg deployment..."
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
    --exclude="build.sh" \
    --exclude="/index.html" \
    --exclude="/blog.html" \
    "$SITE_DIR/" .

  echo ""
  echo "==> Done. Review changes with 'git status' then commit and push."
fi
