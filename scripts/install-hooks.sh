#!/usr/bin/env bash
# scripts/install-hooks.sh
# Run once after cloning to install the pre-push git hook.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_FILE="$REPO_ROOT/.git/hooks/pre-push"

cat > "$HOOK_FILE" << 'HOOK'
#!/usr/bin/env bash
# .git/hooks/pre-push — installed by scripts/install-hooks.sh
# Runs validate.sh (without FULL=1) before every push.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "[pre-push] Running validate.sh..."
bash scripts/validate.sh
HOOK

chmod +x "$HOOK_FILE"
echo "Pre-push hook installed at $HOOK_FILE"
echo "Every 'git push' will now run scripts/validate.sh automatically."
