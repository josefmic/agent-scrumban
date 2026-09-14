#!/bin/bash
REAL=/Applications/supacode.app/Contents/Resources/zmx/zmx
EXTRA=/tmp/e2e-scrumban/zmx-extra
SCREEN=/tmp/e2e-scrumban/screens/$2
if [ "$1" = "history" ] && [ -f "$SCREEN" ]; then cat "$SCREEN"; exit 0; fi
"$REAL" "$@"
if [ "$1" = "list" ] && [ -f "$EXTRA" ]; then cat "$EXTRA"; fi
