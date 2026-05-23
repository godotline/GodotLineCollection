#!/bin/bash
# Sync #Template directory from upstream godot-line repository

set -e

echo "=========================================="
echo "  Sync #Template from upstream/godot-line"
echo "=========================================="
echo ""

# Fetch latest changes from upstream
echo "[1/4] Fetching upstream changes..."
if ! git fetch upstream; then
    echo "ERROR: Failed to fetch upstream. Make sure 'upstream' remote exists."
    echo "Run: git remote add upstream https://github.com/meny2333/godot-line.git"
    exit 1
fi

# Check for differences
echo ""
echo "[2/4] Checking for differences..."
git diff --stat HEAD upstream/main -- "#Template/"

echo ""
echo "Current branch: $(git branch --show-current)"

echo ""
echo "=========================================="
echo "  WARNING: This will REPLACE your local"
echo "  #Template directory with upstream version!"
echo "=========================================="
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Cancelled."
    exit 0
fi

# Remove current #Template
echo ""
echo "[3/4] Removing current #Template..."
git rm -r "#Template"
git commit -m "chore(template): remove #Template for upstream sync"

# Read tree from upstream
echo ""
echo "[4/4] Importing #Template from upstream..."
git read-tree -u --prefix="#Template/" upstream/main:"#Template/"
git add "#Template/"
git commit -m "feat(template): sync #Template from upstream/godot-line"

echo ""
echo "=========================================="
echo "  Sync completed successfully!"
echo "=========================================="
echo ""
echo "You can now push the changes:"
echo "  git push origin main"
