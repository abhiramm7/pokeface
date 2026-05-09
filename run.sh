#!/usr/bin/env bash
# Build the Pokéface watch face and load it in the Connect IQ Simulator.
#
# Usage:
#   ./run.sh             # build + sideload once
#   ./run.sh --watch     # rebuild + reload on every source/resource save
#   ./run.sh --art       # regenerate sprite art first
#   ./run.sh --release   # build release (-r), no debug symbols
#   ./run.sh --build     # build only, don't launch simulator
#
# Flags compose: ./run.sh --art --watch

set -euo pipefail

cd "$(dirname "$0")"

# Args.
do_art=0
do_release=0
build_only=0
do_watch=0
for arg in "$@"; do
    case "$arg" in
        --art)     do_art=1 ;;
        --release) do_release=1 ;;
        --build)   build_only=1 ;;
        --watch)   do_watch=1 ;;
        -h|--help)
            awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
            exit 0 ;;
        *)
            echo "Unknown flag: $arg" >&2
            exit 1 ;;
    esac
done

# Java 17 is required by the Garmin SDK.
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"

# Resolve the SDK and developer key.
SDK_BASE="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"
SDK="$(ls -d "$SDK_BASE"/connectiq-sdk-mac-* 2>/dev/null | sort -V | tail -1)"
if [[ -z "$SDK" || ! -x "$SDK/bin/monkeyc" ]]; then
    echo "Connect IQ SDK not found under $SDK_BASE" >&2
    exit 1
fi

KEY="${POKEFACE_KEY:-$HOME/garmin/developer_key.der}"
if [[ ! -f "$KEY" ]]; then
    echo "Developer key not found at $KEY" >&2
    echo "Set POKEFACE_KEY=/path/to/key.der or generate one with:" >&2
    echo "  openssl genrsa -out key.pem 4096 && \\" >&2
    echo "  openssl pkcs8 -topk8 -inform PEM -outform DER -in key.pem -out $KEY -nocrypt" >&2
    exit 1
fi

PRG="bin/Pokeface.prg"
DEVICE="fr265s"

build_and_load() {
    if [[ $do_art -eq 1 ]]; then
        echo "→ Regenerating art..."
        uv run --with pillow python art/build_art.py
    fi

    echo "→ Building $PRG ($([[ $do_release -eq 1 ]] && echo release || echo debug))..."
    mkdir -p bin
    local build_args=(-d "$DEVICE" -f monkey.jungle -o "$PRG" -y "$KEY")
    [[ $do_release -eq 1 ]] && build_args+=(-r)
    if ! "$SDK/bin/monkeyc" "${build_args[@]}"; then
        echo "✗ build failed"
        return 1
    fi
    ls -lh "$PRG" | awk '{print "   " $5 "  " $NF}'

    [[ $build_only -eq 1 ]] && return 0

    if ! pgrep -f "ConnectIQ.app/Contents/MacOS/simulator" > /dev/null; then
        echo "→ Launching simulator..."
        open "$SDK/bin/ConnectIQ.app"
        sleep 4
    fi

    pkill -f "monkeydo.*Pokeface" 2>/dev/null || true
    sleep 1
    echo "→ Sideloading..."
    "$SDK/bin/monkeydo" "$PRG" "$DEVICE" &
    sleep 2
    echo "✓ Loaded."
}

build_and_load

if [[ $do_watch -eq 1 ]]; then
    if ! command -v fswatch > /dev/null; then
        echo "fswatch not installed: brew install fswatch" >&2
        exit 1
    fi
    echo
    echo "👀 Watching source/, resources/, manifest.xml, monkey.jungle..."
    echo "    (Ctrl-C to stop)"
    fswatch -o source resources manifest.xml monkey.jungle 2>/dev/null | while read _; do
        echo
        echo "── Change detected $(date +%H:%M:%S) ──"
        build_and_load || true
    done
fi
