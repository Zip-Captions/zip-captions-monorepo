#!/usr/bin/env bash
# install-hooks.sh -- Run once after cloning to install local git hooks.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/usr/bin/env bash
# pre-push: runs dart analyze before every push.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
echo "pre-push: running dart analyze --fatal-infos..."
dart analyze --fatal-infos packages/zip_core packages/zip_broadcast
EOF

chmod +x "$HOOKS_DIR/pre-push"
echo "pre-push hook installed at $HOOKS_DIR/pre-push"
