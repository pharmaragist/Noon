#!/bin/sh
# matugen post_hook: apply the regenerated Helium theme.
# Live reload is impossible for theme extensions in Helium (developerPrivate.reload
# disables them), so this is a hash-gated restart — no-op unless colors changed.
exec /home/pharmaracist/.local/bin/helium-retheme
