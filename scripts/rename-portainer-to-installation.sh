#!/bin/bash
# Rename all PORTAINER.md files to INSTALLATION.md across the IAC repo
# This aligns documentation naming with the actual deployment method (Container Manager, not Portainer UI)

set -e

REPO_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "🔄 Renaming PORTAINER.md → INSTALLATION.md in $REPO_ROOT"
echo ""

# Find all PORTAINER.md files
PORTAINER_FILES=$(find "$REPO_ROOT" -name "PORTAINER.md" -type f)

if [ -z "$PORTAINER_FILES" ]; then
    echo "✅ No PORTAINER.md files found"
    exit 0
fi

# Count files
FILE_COUNT=$(echo "$PORTAINER_FILES" | wc -l)
echo "Found $FILE_COUNT PORTAINER.md file(s)"
echo ""

# Rename each file
echo "Renaming..."
echo "----------"
for file in $PORTAINER_FILES; do
    dir=$(dirname "$file")
    new_file="$dir/INSTALLATION.md"
    
    # Check if INSTALLATION.md already exists
    if [ -f "$new_file" ]; then
        echo "⚠️  Skipping $file → $new_file (destination already exists)"
        continue
    fi
    
    # Rename
    mv "$file" "$new_file"
    echo "✅ $file → $new_file"
done

echo ""
echo "✅ Done! Renamed $FILE_COUNT file(s)"
echo ""
echo "Next steps:"
echo "1. Update any references to PORTAINER.md in other documentation"
echo "2. Commit the changes: git add -A && git commit -m 'refactor(docs): rename PORTAINER.md to INSTALLATION.md'"
