#!/usr/bin/env bash
set -euo pipefail

# Safe JSON state updates for .state/environment.json via jq.
# Usage:
#   update-state.sh set <jq-path> <value>
#   update-state.sh append-blocker <description>
#   update-state.sh clear-blockers
#   update-state.sh append-history <json-object>
#   update-state.sh init
#   update-state.sh show

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_FILE="$REPO_ROOT/.state/environment.json"
HISTORY_FILE="$REPO_ROOT/.state/history.jsonl"
TEMPLATE_FILE="$REPO_ROOT/.state/environment.json.template"

ensure_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        if [[ -f "$TEMPLATE_FILE" ]]; then
            cp "$TEMPLATE_FILE" "$STATE_FILE"
            echo "Initialized state from template"
        else
            echo "Error: No state file and no template found" >&2
            exit 1
        fi
    fi
}

case "${1:-help}" in
    init)
        if [[ -f "$STATE_FILE" ]]; then
            echo "State file already exists: $STATE_FILE"
            exit 0
        fi
        cp "$TEMPLATE_FILE" "$STATE_FILE"
        echo "Initialized .state/environment.json"
        ;;

    set)
        ensure_state
        local_path="${2:?Usage: update-state.sh set <jq-path> <value>}"
        local_value="${3:?Usage: update-state.sh set <jq-path> <value>}"
        tmp=$(mktemp)
        jq --arg v "$local_value" ".$local_path = \$v" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
        echo "Set .$local_path = $local_value"
        ;;

    set-json)
        ensure_state
        local_path="${2:?Usage: update-state.sh set-json <jq-path> <json-value>}"
        local_value="${3:?Usage: update-state.sh set-json <jq-path> <json-value>}"
        tmp=$(mktemp)
        jq --argjson v "$local_value" ".$local_path = \$v" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
        echo "Set .$local_path = $local_value"
        ;;

    set-timestamp)
        ensure_state
        local_path="${2:?Usage: update-state.sh set-timestamp <jq-path>}"
        tmp=$(mktemp)
        jq --arg v "$(date -u +%Y-%m-%dT%H:%M:%SZ)" ".$local_path = \$v" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
        echo "Set .$local_path to current UTC time"
        ;;

    append-blocker)
        ensure_state
        desc="${2:?Usage: update-state.sh append-blocker <description>}"
        tmp=$(mktemp)
        jq --arg d "$desc" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '.blockers += [{"description": $d, "added": $t, "resolved": false}]' \
            "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
        echo "Added blocker: $desc"
        ;;

    clear-blockers)
        ensure_state
        tmp=$(mktemp)
        jq '.blockers = []' "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
        echo "Cleared all blockers"
        ;;

    append-history)
        ensure_state
        entry="${2:?Usage: update-state.sh append-history '<json>'}"
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        echo "$entry" | jq -c --arg ts "$ts" '. + {ts: $ts}' >> "$HISTORY_FILE"
        echo "Appended history entry"
        ;;

    show)
        ensure_state
        jq . "$STATE_FILE"
        ;;

    history)
        if [[ -f "$HISTORY_FILE" ]]; then
            cat "$HISTORY_FILE"
        else
            echo "No history yet"
        fi
        ;;

    help|*)
        echo "Usage: update-state.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  init                          Initialize state from template"
        echo "  set <path> <value>            Set a string value (jq path without leading dot)"
        echo "  set-json <path> <json>        Set a JSON value"
        echo "  set-timestamp <path>          Set a path to current UTC timestamp"
        echo "  append-blocker <description>  Add a blocker"
        echo "  clear-blockers                Remove all blockers"
        echo "  append-history <json>         Append to history.jsonl"
        echo "  show                          Display current state"
        echo "  history                       Display operation history"
        ;;
esac
