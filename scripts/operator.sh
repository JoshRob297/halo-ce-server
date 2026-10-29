#!/bin/sh
set -eu

HOST="${HALO_CONSOLE_HOST:-127.0.0.1}"
PORT="${HALO_CONSOLE_PORT:-2323}"
if [ -z "${HALO_LOG_FILE:-}" ]; then
    for candidate in \
        "${HOME:-/root}/.local/share/halo-linux/debug.txt" \
        "/opt/halo-server/.local/share/halo-linux/debug.txt" \
        "/opt/halo-server/debug.txt" \
        "/halo/debug.txt"; do
        if [ -f "$candidate" ]; then
            LOG_FILE="$candidate"
            break
        fi
    done
fi
LOG_FILE="${LOG_FILE:-${HOME:-/root}/.local/share/halo-linux/debug.txt}"

usage() {
    cat << 'EOF'
Usage:
  operator.sh kick <name>       # sends: kick <name>
  operator.sh ban <name>        # sends: ban <name>
  operator.sh votekick <name>   # sends: votekick <name>
  operator.sh say <text>        # logs warning (say not yet implemented natively)
  operator.sh status            # reads from server log and prints parsed state
  operator.sh raw <command>     # sends raw command to telnet console
EOF
    exit 1
}

send_command() {
    cmd="$1"
    if command -v socat >/dev/null 2>&1; then
        printf "%s\n" "$cmd" | socat -t 2 - "TCP:${HOST}:${PORT}" 2>/dev/null || {
            echo "Error: failed to connect to console at ${HOST}:${PORT}" >&2
            exit 1
        }
    elif command -v nc >/dev/null 2>&1; then
        if nc -h 2>&1 | grep -q -- "-q"; then
            printf "%s\n" "$cmd" | nc -w 2 -q 1 "$HOST" "$PORT" 2>/dev/null || {
                echo "Error: failed to connect to console at ${HOST}:${PORT}" >&2
                exit 1
            }
        else
            printf "%s\n" "$cmd" | nc -w 2 "$HOST" "$PORT" 2>/dev/null || {
                echo "Error: failed to connect to console at ${HOST}:${PORT}" >&2
                exit 1
            }
        fi
    else
        echo "Error: neither socat nor nc found" >&2
        exit 1
    fi
}

cmd="${1:-}"
case "$cmd" in
    kick)
        [ $# -ge 2 ] || usage
        shift
        send_command "kick $*"
        ;;
    ban)
        [ $# -ge 2 ] || usage
        shift
        send_command "ban $*"
        ;;
    votekick)
        [ $# -ge 2 ] || usage
        shift
        send_command "votekick $*"
        ;;
    say)
        [ $# -ge 2 ] || usage
        shift
        echo "Warning: say is not yet implemented natively by the dedicated server" >&2
        ;;
    raw)
        [ $# -ge 2 ] || usage
        shift
        send_command "$*"
        ;;
    status)
        if [ ! -f "$LOG_FILE" ]; then
            echo "Error: log file not found at $LOG_FILE" >&2
            exit 1
        fi
        # Log format examples:
        #   halo-linux: network test: game 1, slayer on bloodgulch
        #   halo-linux: server: state 1 ..., map levels\test\bloodgulch\bloodgulch, 600 seconds left, 3 players of 16
        game_line=$(grep "network test: game\|network test: hosting" "$LOG_FILE" 2>/dev/null | tail -n 1 || true)
        state_line=$(grep "server: state" "$LOG_FILE" 2>/dev/null | tail -n 1 || true)

        if [ -z "$game_line" ] && [ -z "$state_line" ]; then
            echo "Error: no server state found in log at $LOG_FILE" >&2
            exit 1
        fi

        # Extract variant and map from "game N, variant on map" line
        if [ -n "$game_line" ]; then
            variant=$(printf '%s\n' "$game_line" | sed -n 's/.*network test: game [0-9]*, \([^ ]*\) on .*/\1/p')
            map_name=$(printf '%s\n' "$game_line" | sed -n 's/.*network test: game [0-9]*, [^ ]* on \(.*\)/\1/p' | tr -d '\r')
            if [ -z "$map_name" ]; then
                # hosting line: "network test: hosting bloodgulch"
                map_name=$(printf '%s\n' "$game_line" | sed -n 's/.*network test: hosting \(.*\)/\1/p' | tr -d '\r')
                variant="lobby"
            fi
        fi

        # Extract state and players from "server: state N" line
        if [ -n "$state_line" ]; then
            raw_state=$(printf '%s\n' "$state_line" | sed -n 's/.*server: state \([0-9]\).*/\1/p')
            raw_players=$(printf '%s\n' "$state_line" | sed -n 's/.*, \([0-9]*\) players of.*/\1/p')
            case "$raw_state" in
                0) state="pregame" ;;
                1) state="in_game" ;;
                2) state="postgame" ;;
                *) state="unknown" ;;
            esac
            players="${raw_players:-0}"
        else
            state="starting"
            players="0"
        fi

        printf "map: %s | variant: %s | players: %s | state: %s\n" \
            "${map_name:-unknown}" "${variant:-unknown}" "$players" "$state"
        ;;
    *)
        usage
        ;;
esac
