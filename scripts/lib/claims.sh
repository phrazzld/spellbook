#!/usr/bin/env bash
# Atomic claim protocol for agent coordination.
# Claims use git refs: refs/claims/<id> with atomic CAS via git update-ref.
# Source this file, then call claim_acquire/claim_release/claim_check.
#
# Usage:
#   source scripts/lib/claims.sh
#   claim_acquire "abc1234"   # returns 0 on success, 1 if already claimed
#   claim_check  "abc1234"    # returns 0 if claimed, 1 if free
#   claim_release "abc1234"   # returns 0 on success
#   claim_list                # prints all active claim IDs

CLAIMS_REF_PREFIX="refs/claims"

# Acquire a claim. Uses CAS: fails if ref already exists.
# Args: <id>
# Returns: 0 on success, 1 if already claimed
claim_acquire() {
  local id="$1"
  local oid
  oid="$(git rev-parse HEAD)"
  # Null OID asserts ref does not exist (canonical create-if-absent CAS)
  local null_oid="0000000000000000000000000000000000000000"
  if git update-ref "${CLAIMS_REF_PREFIX}/${id}" "$oid" "$null_oid" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Release a claim. Atomic — single git update-ref -d call.
# Args: <id>
# Returns: 0 on success, 1 if not claimed
claim_release() {
  local id="$1"
  git update-ref -d "${CLAIMS_REF_PREFIX}/${id}" 2>/dev/null
}

# Check if an id is claimed.
# Args: <id>
# Returns: 0 if claimed, 1 if free
claim_check() {
  local id="$1"
  git rev-parse --verify "${CLAIMS_REF_PREFIX}/${id}" &>/dev/null
}

# List all active claims.
# Prints: one ref per line
claim_list() {
  git for-each-ref "${CLAIMS_REF_PREFIX}/" --format='%(refname:short)'
}
