#!/bin/bash
# Checks that every login flag the app can send (AuthCommand.requiredBackendFlag
# in src/Sources/ServerManager.swift) is either defined by the CLIProxyAPI binary
# under test or explicitly acknowledged as missing (runtime-gated in the app).
#
# Usage: scripts/check-backend-flag-parity.sh <path-to-cli-proxy-api-binary>
#
# Exit codes: 0 = parity holds; 1 = a required flag is missing without an entry
# in KNOWN_MISSING, or the Swift map could not be extracted.

set -euo pipefail

BINARY="${1:-}"
if [ -z "$BINARY" ] || [ ! -x "$BINARY" ]; then
  echo "error: pass the path to an executable CLIProxyAPI binary" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_SOURCE="$SCRIPT_DIR/../src/Sources/ServerManager.swift"

# Login flags the app maps but upstream stock builds no longer define. The app
# disables those logins at runtime (BackendCapabilities gate in ServerManager).
# Drop an entry as soon as the backend defines it again - and verify the flow
# actually works before removing the runtime gate.
declare -a KNOWN_MISSING=(
  "github-copilot-login|GitHub Copilot login (#351)"
  "login|Gemini login (#457, #396)"
  "qwen-login|Qwen login"
)

HELP="$("$BINARY" --help 2>&1 || true)"
echo "backend: $(printf '%s\n' "$HELP" | head -n 1)"

DEFINED="$(printf '%s\n' "$HELP" \
  | grep -oE '^[[:space:]]*-+[A-Za-z0-9_.-]+' \
  | sed 's/^[[:space:]]*-*//' \
  | sort -u)"

has_flag() {
  printf '%s\n' "$DEFINED" | grep -Fxq -- "$1"
}

known_missing_reason() {
  local flag="$1" entry
  for entry in "${KNOWN_MISSING[@]}"; do
    if [ "${entry%%|*}" = "$flag" ]; then
      printf '%s' "${entry#*|}"
      return 0
    fi
  done
  return 1
}

MAP="$(sed -n '/var requiredBackendFlag: String {/,/^    }$/p' "$SWIFT_SOURCE" \
  | grep -oE 'return "[A-Za-z0-9_.-]+"' \
  | sed 's/return "//;s/"$//' \
  || true)"

if [ -z "$MAP" ]; then
  echo "FAIL: could not extract requiredBackendFlag from $SWIFT_SOURCE" >&2
  exit 1
fi

STATUS=0
COUNT=0
while IFS= read -r flag; do
  [ -z "$flag" ] && continue
  COUNT=$((COUNT + 1))
  if has_flag "$flag"; then
    REASON="$(known_missing_reason "$flag" || true)"
    if [ -n "$REASON" ]; then
      echo "note: '$flag' ($REASON) is defined again - verify the login flow, then drop the allowlist entry"
    else
      echo "ok:   $flag"
    fi
  elif REASON="$(known_missing_reason "$flag")"; then
    echo "gate: $flag - missing ($REASON); the app disables this login at runtime"
  else
    echo "FAIL: the app sends '-$flag' but the backend does not define it"
    STATUS=1
  fi
done <<< "$MAP"

echo "checked $COUNT login flags"
exit "$STATUS"
