#!/usr/bin/env bash
#
# rotate-key.sh — move the Groq API key back to the server.
#
# Pushes the key to the `groq-proxy` Edge Function (as the GROQ_API_KEY
# function secret) and strips any copy embedded in the app source so the key
# never ships in the client binary again.
#
# Usage:
#   ./supabase/functions/groq-proxy/rotate-key.sh [gsk_...]
#
# Key value precedence:
#   1. the first argument
#   2. the GROQ_API_KEY environment variable
#   3. the value currently embedded in lib/config/app_credentials.dart
#
# Requires the Supabase CLI, logged in and linked (`supabase link`). Pass
# SUPABASE_PROJECT_REF (or --project-ref) to target a project explicitly.
#
# Redeploying the function is optional — the secret is read at request time.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CREDS_FILE="$REPO_ROOT/lib/config/app_credentials.dart"
FUNCTION_NAME="groq-proxy"

PROJECT_REF="${SUPABASE_PROJECT_REF:-}"

usage() {
  cat <<'EOF'
rotate-key.sh — move the Groq API key back to the server.

Pushes the key to the `groq-proxy` Edge Function (as the GROQ_API_KEY
function secret) and strips any copy embedded in the app source so the key
never ships in the client binary again.

Usage:
  ./supabase/functions/groq-proxy/rotate-key.sh [--project-ref <ref>] [gsk_...]

Key value precedence: argument, then $GROQ_API_KEY, then the value in
lib/config/app_credentials.dart. Requires the Supabase CLI, logged in and
linked (or --project-ref / $SUPABASE_PROJECT_REF).
EOF
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-ref)
      PROJECT_REF="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

KEY="${POSITIONAL[0]:-${GROQ_API_KEY:-}}"

# Fall back to the value embedded in the credentials file (the pre-rotation
# location) so the script works with no arguments.
if [[ -z "$KEY" && -f "$CREDS_FILE" ]]; then
  KEY="$(grep -oE 'gsk_[A-Za-z0-9_-]+' "$CREDS_FILE" | head -n1 || true)"
fi

if [[ -z "$KEY" ]]; then
  echo "error: no Groq key provided and none embedded in $CREDS_FILE" >&2
  echo >&2
  usage >&2
  exit 1
fi

if [[ ! "$KEY" =~ ^gsk_ ]]; then
  echo "error: \"$KEY\" does not look like a Groq key (expected gsk_...)" >&2
  exit 1
fi

# ── 1. Store the key server-side ────────────────────────────────────────────
echo "==> Setting GROQ_API_KEY secret on the '$FUNCTION_NAME' function"
if [[ -n "$PROJECT_REF" ]]; then
  supabase secrets set "GROQ_API_KEY=$KEY" --project-ref "$PROJECT_REF"
else
  supabase secrets set "GROQ_API_KEY=$KEY"
fi

# ── 2. Strip any embedded copy from the Dart credentials file ────────────────
if [[ -f "$CREDS_FILE" ]] && grep -q 'groqApiKey' "$CREDS_FILE"; then
  echo "==> Removing the embedded Groq key from ${CREDS_FILE#"$REPO_ROOT"/}"
  # Drop the Groq section banner (// ── Groq ──), the doc comment block and the
  # `groqApiKey` constant. Relies on the constant being a single statement that
  # ends in `;` — the format this repo has always used.
  perl -0777 -i -pe '
    s{^[ \t]*//\s*──\s*Groq.*\n}{}mg;
    s{(?:^[ \t]*///[^\n]*\n)+^[ \t]*static const String groqApiKey[^;]*;\n?}{}mg;
  ' "$CREDS_FILE"
  perl -0777 -i -pe 's/\n{3,}/\n\n/g' "$CREDS_FILE"
else
  echo "==> No embedded Groq key found in ${CREDS_FILE#"$REPO_ROOT"/} — nothing to remove"
fi

echo
echo "Done. The key now lives only in the '$FUNCTION_NAME' function secret."
echo "Next:"
echo "  * revoke the old key in the Groq console (https://console.groq.com/keys)"
echo "  * rebuild the app — no Groq key is compiled into the binary anymore"
