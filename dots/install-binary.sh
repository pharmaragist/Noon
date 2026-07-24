#!/usr/bin/env bash
set -euo pipefail

DESTDIR="${DESTDIR:-}"

cat > "$DESTDIR/usr/local/bin/noon" <<'EOF'
#!/bin/sh
QS_CONFIG="${SHELL_PATH:-$HOME/.config/noon}"
exec qs -c "$QS_CONFIG" "$@"
EOF
chmod 755 "$DESTDIR/usr/local/bin/noon"
