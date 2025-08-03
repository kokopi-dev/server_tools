#!/bin/bash
# Background backup system
imp() {
    local path=$1
    if [ -f "$path" ]; then
        set -a
        source $path
        set +a
    fi
}
imp ".folder-watch.env"

if [[ -z $WATCH_FOLDERS || -z "$BACKUP_MOUNT_0" ]]; then
    echo "Required env: .folder-watch.env"
    echo "Required variables: WATCH_FOLDERS=(...)"
    echo "  WATCH_FOLDERS=(...)"
    echo "  BACKUP_MOUNT_0=/mnt/..."
    exit 1
fi

# Simple daemon file watcher
# Usage: ./watch.sh [start|stop|status]

PIDFILE="/tmp/folder-watch.pid"
LOGFILE="$HOME/.folder-watch.log"

is_regular_transfer() {
    local filepath="$1"
    local event="$2"
    local filename=$(basename "$filepath")
    
    # Rsync temporary file pattern sample: .filename.5gpact
    if [[ "$filename" =~ ^\.[^.].*\.[a-zA-Z0-9]{6}$ ]]; then
        return 1  # Rsync pattern
    fi
    
    if [[ "$event" == "MOVED_TO" ]] && [[ ! "$filename" =~ ^\. ]]; then
        return 0 # Rsync final pattern
    fi

    # Check for other temporary file patterns
    if [[ "$filename" =~ \.tmp$ ]] || [[ "$filename" =~ \.swp$ ]] || [[ "$filename" =~ ~$ ]]; then
        return 1  # Not regular (temp file)
    fi
    
    return 0  # Regular transfer
}


start_watcher() {
    # Check if already running
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "Watcher is already running (PID: $(cat "$PIDFILE"))"
        return 1
    fi
    
    # Check if inotifywait is available
    if ! command -v inotifywait &> /dev/null; then
        echo "Error: inotifywait not found. Install inotify-tools:"
        echo "  Ubuntu/Debian: sudo apt-get install inotify-tools"
        echo "  Arch:          sudo pacman -S inotify-tools"
        return 1
    fi
    
    # Create directories if they don't exist
    for dir in "${WATCH_FOLDERS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done
    
    echo "Starting watcher in background..."
    echo "Folders: ${WATCH_FOLDERS[*]}"
    echo "Log file: $LOGFILE"
    
    # Start in background
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watcher started"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watching: ${WATCH_FOLDERS[*]}"
        
        inotifywait -m -r -e modify,create,delete,move \
            --format '%T %e %w%f' \
            --timefmt '%Y-%m-%d %H:%M:%S' \
            "${WATCH_FOLDERS[@]}" | while read timestamp event filepath; do
            echo "[$timestamp] $event: $filepath"
        done
    } >> "$LOGFILE" 2>&1 &
    
    # Save PID
    echo $! > "$PIDFILE"
    echo "Watcher started (PID: $!)"
    echo "Use '$0 stop' to stop"
    echo "Use 'tail -f $LOGFILE' to see live events"
}

stop_watcher() {
    if [[ ! -f "$PIDFILE" ]]; then
        echo "No PID file found. Watcher may not be running."
        return 1
    fi
    
    local pid=$(cat "$PIDFILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        echo "Stopping watcher (PID: $pid)..."
        kill "$pid"
        
        # Wait a moment and force kill if needed
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            echo "Force stopping..."
            kill -9 "$pid" 2>/dev/null
        fi
        
        rm -f "$PIDFILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watcher stopped" >> "$LOGFILE"
        echo "Watcher stopped"
    else
        echo "Process not running, cleaning up PID file"
        rm -f "$PIDFILE"
    fi
}

show_status() {
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        local pid=$(cat "$PIDFILE")
        echo "Status: Running (PID: $pid)"
        echo "Folders: ${WATCH_FOLDERS[*]}"
        echo "Log file: $LOGFILE"
        
        if [[ -f "$LOGFILE" ]]; then
            echo
            echo "Recent activity (last 5 lines):"
            tail -5 "$LOGFILE" | sed 's/^/  /'
        fi
    else
        echo "Status: Not running"
        if [[ -f "$PIDFILE" ]]; then
            echo "Cleaning up stale PID file..."
            rm -f "$PIDFILE"
        fi
    fi
}

# Handle no arguments (run interactively)
if [[ $# -eq 0 ]]; then
    echo "Running interactively..."
    echo "Folders: ${WATCH_FOLDERS[*]}"
    echo "Press Ctrl+C to stop"
    echo "========================"
    
    # Create directories if they don't exist
    for dir in "${WATCH_FOLDERS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done
    
    # Check inotifywait
    if ! command -v inotifywait &> /dev/null; then
        echo "Error: inotifywait not found. Install inotify-tools:"
        echo "  Ubuntu/Debian: sudo apt-get install inotify-tools"
        echo "  Arch:          sudo pacman -S inotify-tools"
        exit 1
    fi
    if ! command -v rsync &> /dev/null; then
        echo "Error: rsync not found. Install rsync:"
        echo "  Ubuntu/Debian: sudo apt-get install rsync"
        echo "  Arch:          sudo pacman -S rsync"
        exit 1
    fi
    
    # Main command
    inotifywait -m -r -e modify,create,delete,move \
        --format '%T %e %w%f' \
        --timefmt '%Y-%m-%d_%H:%M:%S' \
        "${WATCH_FOLDERS[@]}" | while read -r timestamp event filepath; do
        # Actions on event
        
        if is_regular_transfer "$filepath" "$event"; then
            if [[ "$event" == "DELETE" ]]; then
                backup_path="$BACKUP_MOUNT_0/backup${filepath}"
                if [ -f "$backup_path" ]; then
                    # TODO remove empty dirs
                    rm "$backup_path"
                    echo "[SUCCESS_REMOVE] - [$timestamp] $event: $filepath -> $backup_path"
                else
                    echo "[FAILED_REMOVE] - [$timestamp] $event: $filepath -> $backup_path"
                fi
            fi
            if [[ "$event" == "MODIFY" || "$event" == "CREATE" || "$event" == "MOVED_TO" ]]; then
                file_dir=$(dirname "$filepath")
                backup_path="$BACKUP_MOUNT_0/backup${file_dir}"
                mkdir -p "$backup_path"
                if rsync -av "$filepath" "$backup_path" &>/dev/null; then
                    echo "[SUCCESS_BACKUP] - [$timestamp] $event: $filepath -> $backup_path"
                else
                    echo "[FAILED_BACKUP] - [$timestamp] $event: $filepath -> $backup_path"
                fi
            fi

        fi
    done
    exit 0
fi

# Handle commands
case "$1" in
    start)
        start_watcher
        ;;
    stop)
        stop_watcher
        ;;
    restart)
        stop_watcher
        sleep 1
        start_watcher
        ;;
    status)
        show_status
        ;;
    logs)
        if [[ -f "$LOGFILE" ]]; then
            tail -f "$LOGFILE"
        else
            echo "No log file found"
        fi
        ;;
    *)
        echo "Usage: $0 [start|stop|restart|status|logs]"
        echo ""
        echo "Commands:"
        echo "  start    - Start watching in background"
        echo "  stop     - Stop the watcher"
        echo "  restart  - Restart the watcher"  
        echo "  status   - Show if running and recent activity"
        echo "  logs     - Follow the log file live"
        echo ""
        echo "Or run without arguments for interactive mode"
        exit 1
        ;;
esac
