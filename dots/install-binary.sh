#!/usr/bin/env bash
set -euo pipefail

DESTDIR="${DESTDIR:-}"
BIN_DIR="${DESTDIR}/usr/local/bin"

install -d "$BIN_DIR"
cat > "$BIN_DIR/noon" <<'EOF'
#!/bin/sh
QS_CONFIG="${SHELL_PATH:-$HOME/.config/noon}"
exec qs -c "$QS_CONFIG" "$@"
EOF
chmod 755 "$BIN_DIR/noon"
