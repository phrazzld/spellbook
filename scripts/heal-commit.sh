#!/usr/bin/env bash
set -euo pipefail

touch .env

check_output="$(DAGGER_NO_NAG="${DAGGER_NO_NAG:-1}" dagger call check 2>&1 || true)"
gate="$(python3 - <<'PY' "$check_output"
import re
import sys

text = sys.argv[1]
match = re.search(r"^\s*FAIL\s+([a-z0-9-]+)$", text, re.MULTILINE)
print(match.group(1) if match else "")
PY
)"

if [[ -z "$gate" ]]; then
  printf '%s\n' "$check_output"
  exit 0
fi

branch="$(python3 - <<'PY' "$gate"
import re
import sys
from datetime import UTC, datetime

gate = sys.argv[1]
slug = re.sub(r"[^a-z0-9]+", "-", gate.lower()).strip("-")
print(f"heal/{slug}-{datetime.now(UTC).strftime('%Y%m%d%H%M%S')}")
PY
)"

DAGGER_NO_NAG="${DAGGER_NO_NAG:-1}" dagger call --allow-llm all -o . heal "$@"
DAGGER_NO_NAG="${DAGGER_NO_NAG:-1}" dagger call check >/dev/null
git switch -c "$branch"
git add -A
git commit -m "ci: heal $gate"
printf 'Healed %s on %s\n' "$gate" "$branch"
