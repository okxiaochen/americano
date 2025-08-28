#!/usr/bin/env bash

# americano — prevent macOS from sleeping based on time or process monitoring
# Usage: americano [-d] <time|pid> <value>
#   -d             — also prevent display from sleeping (optional)
#   time <minutes> — prevent sleep for the specified number of minutes
#   pid  <PID>     — prevent sleep while the specified process is running

# Parse optional flag
PREVENT_DISPLAY_SLEEP=false
if [ "$1" == "-d" ]; then
    PREVENT_DISPLAY_SLEEP=true
    shift
fi

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 [-d] <time|pid> <value>"
    echo "  -d             — also prevent display from sleeping (optional)"
    echo "  time <minutes> — prevent sleep for the specified number of minutes"
    echo "  pid  <PID>     — prevent sleep while the specified process is running"
    exit 1
fi

MODE=$1
ARG=$2
CAFFEINATE_PID=""

# Start preventing system sleep
start_prevent_sleep() {
    # -i: prevent idle sleep
    # -m: prevent disk sleep
    # -s: prevent sleep when connected to power
    # -d: prevent display sleep (optional)
    if [ "$PREVENT_DISPLAY_SLEEP" == "true" ]; then
        caffeinate -imsd &
        CAFFEINATE_PID=$!
        echo "▶️ Preventing system and display sleep (caffeinate PID=$CAFFEINATE_PID)"
    else
        caffeinate -ims &
        CAFFEINATE_PID=$!
        echo "▶️ Preventing system sleep, allowing display sleep (caffeinate PID=$CAFFEINATE_PID)"
    fi
}

# Stop preventing system sleep
stop_prevent_sleep() {
    if [[ -n "$CAFFEINATE_PID" ]]; then
        if kill "$CAFFEINATE_PID" 2>/dev/null; then
            echo "⏹ Sleep prevention stopped (killed PID=$CAFFEINATE_PID)"
        else
            echo "⚠️ Failed to stop PID $CAFFEINATE_PID — it may have already exited"
        fi
        CAFFEINATE_PID=""
    fi
}

# Clean up on exit
trap "stop_prevent_sleep; exit" SIGINT SIGTERM SIGHUP

# Check if a given PID is running
check_process() {
    ps -p "$PID" > /dev/null 2>&1
}

# Retrieve the name of a given PID
get_process_name() {
    ps -p "$PID" -o comm= 2>/dev/null
}

if [ "$MODE" == "pid" ]; then
    PID=$ARG
    if ! check_process; then
        echo "❌ Process $PID is not running"
        exit 1
    fi

    PROC_NAME=$(get_process_name)
    start_prevent_sleep
    echo "🔍 Monitoring process $PID ($PROC_NAME) — preventing sleep"

    while check_process; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') — Process $PID ($PROC_NAME) is still running"
        sleep 60
    done

    echo "$(date '+%Y-%m-%d %H:%M:%S') — Process $PID ($PROC_NAME) has exited"
    stop_prevent_sleep
    echo "💤 System sleep behavior restored"

elif [ "$MODE" == "time" ]; then
    MINUTES=$ARG
    SECONDS=$(( MINUTES * 60 ))
    END_TS=$(( $(date +%s) + SECONDS ))

    start_prevent_sleep
    echo "⏱️ Preventing sleep for $MINUTES minutes"

    while true; do
        NOW=$(date +%s)
        if [ "$NOW" -ge "$END_TS" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') — Timer completed"
            stop_prevent_sleep
            echo "💤 System sleep behavior restored"
            exit 0
        fi

        LEFT=$(( (END_TS - NOW) / 60 ))
        echo "$(date '+%Y-%m-%d %H:%M:%S') — $LEFT minutes remaining"
        sleep 60
    done

else
    echo "❗ Invalid mode. Specify 'time' or 'pid'"
    exit 1
fi