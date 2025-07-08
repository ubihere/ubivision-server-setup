#!/bin/bash
# UbiVision Server Setup State Management
# =======================================

set -euo pipefail

# State file paths
STATE_FILE="$STATE_DIR/state.json"
LOCK_FILE="$STATE_DIR/deployment.lock"

# Initialize state system
init_state() {
    init_directories
    
    # Create initial state file if it doesn't exist
    if [ ! -f "$STATE_FILE" ]; then
        cat > "$STATE_FILE" << EOF
{
    "version": "1.0",
    "started_at": "$(date -Iseconds)",
    "last_updated": "$(date -Iseconds)",
    "current_module": null,
    "modules": {
        "00-verify": {"status": "pending", "attempts": 0, "last_attempt": null, "completed_at": null},
        "10-system": {"status": "pending", "attempts": 0, "last_attempt": null, "completed_at": null},
        "20-nvidia": {"status": "pending", "attempts": 0, "last_attempt": null, "completed_at": null},
        "30-docker": {"status": "pending", "attempts": 0, "last_attempt": null, "completed_at": null},
        "40-network": {"status": "pending", "attempts": 0, "last_attempt": null, "completed_at": null},
        "50-validate": {"status": "pending", "attempts": 0, "last_attempt": null, "completed_at": null}
    },
    "reboot_required": false,
    "reboot_module": null,
    "system_info": {},
    "errors": []
}
EOF
        log_info "Initialized state file: $STATE_FILE"
    fi
}

# Lock management
acquire_lock() {
    local max_wait=${1:-300}  # 5 minutes default
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        if mkdir "$LOCK_FILE" 2>/dev/null; then
            echo $$ > "$LOCK_FILE/pid"
            log_info "Acquired deployment lock"
            return 0
        fi
        
        # Check if lock is stale (process no longer exists)
        if [ -f "$LOCK_FILE/pid" ]; then
            local lock_pid=$(cat "$LOCK_FILE/pid" 2>/dev/null)
            if ! kill -0 "$lock_pid" 2>/dev/null; then
                log_warn "Removing stale lock (PID $lock_pid)"
                rm -rf "$LOCK_FILE"
                continue
            fi
        fi
        
        log_warn "Waiting for deployment lock... (${waited}/${max_wait}s)"
        sleep 5
        waited=$((waited + 5))
    done
    
    log_error "Failed to acquire deployment lock after ${max_wait}s"
    return 1
}

# Release lock
release_lock() {
    if [ -d "$LOCK_FILE" ]; then
        rm -rf "$LOCK_FILE"
        log_info "Released deployment lock"
    fi
}

# Update state file
update_state() {
    local key=$1
    local value=$2
    
    if [ ! -f "$STATE_FILE" ]; then
        log_error "State file not found: $STATE_FILE"
        return 1
    fi
    
    # Create temporary file for atomic update
    local temp_file=$(mktemp)
    
    # Use jq to update the state file
    if command -v jq >/dev/null 2>&1; then
        jq --arg key "$key" --arg value "$value" --arg timestamp "$(date -Iseconds)" \
           '.last_updated = $timestamp | .[$key] = $value' \
           "$STATE_FILE" > "$temp_file" && mv "$temp_file" "$STATE_FILE"
    else
        # Fallback for systems without jq
        log_warn "jq not available, using basic state update"
        cp "$STATE_FILE" "$temp_file"
        mv "$temp_file" "$STATE_FILE"
    fi
}

# Get state value
get_state() {
    local key=$1
    
    if [ ! -f "$STATE_FILE" ]; then
        return 1
    fi
    
    if command -v jq >/dev/null 2>&1; then
        jq -r ".$key // empty" "$STATE_FILE" 2>/dev/null
    else
        # Fallback - very basic parsing
        grep "\"$key\":" "$STATE_FILE" | cut -d'"' -f4 2>/dev/null
    fi
}

# Set module status
set_module_status() {
    local module=$1
    local status=$2  # pending, running, completed, failed
    local error_msg=${3:-""}
    
    log_info "Setting module $module status to $status"
    
    if [ ! -f "$STATE_FILE" ]; then
        log_error "State file not found: $STATE_FILE"
        return 1
    fi
    
    local temp_file=$(mktemp)
    local timestamp=$(date -Iseconds)
    
    if command -v jq >/dev/null 2>&1; then
        if [ "$status" = "running" ]; then
            jq --arg module "$module" --arg status "$status" --arg timestamp "$timestamp" \
               '.last_updated = $timestamp | .current_module = $module | .modules[$module].status = $status | .modules[$module].last_attempt = $timestamp | .modules[$module].attempts += 1' \
               "$STATE_FILE" > "$temp_file" && mv "$temp_file" "$STATE_FILE"
        elif [ "$status" = "completed" ]; then
            jq --arg module "$module" --arg status "$status" --arg timestamp "$timestamp" \
               '.last_updated = $timestamp | .current_module = null | .modules[$module].status = $status | .modules[$module].completed_at = $timestamp' \
               "$STATE_FILE" > "$temp_file" && mv "$temp_file" "$STATE_FILE"
        elif [ "$status" = "failed" ]; then
            jq --arg module "$module" --arg status "$status" --arg timestamp "$timestamp" --arg error "$error_msg" \
               '.last_updated = $timestamp | .current_module = null | .modules[$module].status = $status | .errors += [{"module": $module, "error": $error, "timestamp": $timestamp}]' \
               "$STATE_FILE" > "$temp_file" && mv "$temp_file" "$STATE_FILE"
        else
            jq --arg module "$module" --arg status "$status" --arg timestamp "$timestamp" \
               '.last_updated = $timestamp | .modules[$module].status = $status' \
               "$STATE_FILE" > "$temp_file" && mv "$temp_file" "$STATE_FILE"
        fi
    else
        # Fallback without jq
        log_warn "jq not available, using basic state update"
        cp "$STATE_FILE" "$temp_file"
        mv "$temp_file" "$STATE_FILE"
    fi
}

# Get module status
get_module_status() {
    local module=$1
    
    if [ ! -f "$STATE_FILE" ]; then
        echo "unknown"
        return 1
    fi
    
    if command -v jq >/dev/null 2>&1; then
        jq -r ".modules[\"$module\"].status // \"unknown\"" "$STATE_FILE" 2>/dev/null
    else
        echo "unknown"
    fi
}

# Check if module is completed
is_module_completed() {
    local module=$1
    local status=$(get_module_status "$module")
    
    [ "$status" = "completed" ]
}

# Get next pending module
get_next_module() {
    local modules=("00-verify" "10-system" "20-nvidia" "30-docker" "40-network" "50-validate")
    
    for module in "${modules[@]}"; do
        local status=$(get_module_status "$module")
        if [ "$status" = "pending" ]; then
            echo "$module"
            return 0
        fi
    done
    
    return 1
}

# Set reboot requirement
set_reboot_required() {
    local module=$1
    local required=${2:-true}
    
    log_info "Setting reboot requirement: $required (module: $module)"
    
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq --arg module "$module" --arg required "$required" --arg timestamp "$(date -Iseconds)" \
           '.last_updated = $timestamp | .reboot_required = ($required | test("true")) | .reboot_module = $module' \
           "$STATE_FILE" > "$temp_file" && mv "$temp_file" "$STATE_FILE"
    fi
}

# Check if reboot is required
is_reboot_required() {
    if command -v jq >/dev/null 2>&1; then
        local required=$(jq -r '.reboot_required // false' "$STATE_FILE" 2>/dev/null)
        [ "$required" = "true" ]
    else
        return 1
    fi
}

# Get reboot module
get_reboot_module() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.reboot_module // empty' "$STATE_FILE" 2>/dev/null
    fi
}

# Clear reboot requirement
clear_reboot_required() {
    log_info "Clearing reboot requirement"
    
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        jq --arg timestamp "$(date -Iseconds)" \
           '.last_updated = $timestamp | .reboot_required = false | .reboot_module = null' \
           "$STATE_FILE" > "$temp_file" && mv "$temp_file" "$STATE_FILE"
    fi
}

# Update system info
update_system_info() {
    log_info "Updating system information"
    
    if command -v jq >/dev/null 2>&1; then
        local temp_file=$(mktemp)
        local system_info=$(get_system_info)
        
        jq --argjson sysinfo "$system_info" --arg timestamp "$(date -Iseconds)" \
           '.last_updated = $timestamp | .system_info = $sysinfo' \
           "$STATE_FILE" > "$temp_file" && mv "$temp_file" "$STATE_FILE"
    fi
}

# Get deployment progress
get_progress() {
    local modules=("00-verify" "10-system" "20-nvidia" "30-docker" "40-network" "50-validate")
    local completed=0
    
    for module in "${modules[@]}"; do
        if is_module_completed "$module"; then
            completed=$((completed + 1))
        fi
    done
    
    local total=${#modules[@]}
    local percent=$((completed * 100 / total))
    
    echo "$completed/$total ($percent%)"
}

# Show deployment status
show_status() {
    if [ ! -f "$STATE_FILE" ]; then
        log_error "No deployment state found"
        return 1
    fi
    
    local progress=$(get_progress)
    local current_module=$(get_state "current_module")
    local started_at=$(get_state "started_at")
    local last_updated=$(get_state "last_updated")
    
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    DEPLOYMENT STATUS"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "Progress: $progress"
    echo "Started: $started_at"
    echo "Last Updated: $last_updated"
    echo "Current Module: ${current_module:-"None"}"
    echo
    echo "Module Status:"
    echo "-------------"
    
    local modules=("00-verify" "10-system" "20-nvidia" "30-docker" "40-network" "50-validate")
    for module in "${modules[@]}"; do
        local status=$(get_module_status "$module")
        local symbol="○"
        local color="$NC"
        
        case "$status" in
            "completed") symbol="✓"; color="$GREEN" ;;
            "running") symbol="▶"; color="$YELLOW" ;;
            "failed") symbol="✗"; color="$RED" ;;
            "pending") symbol="○"; color="$BLUE" ;;
        esac
        
        echo -e "  ${color}${symbol} ${module}: ${status}${NC}"
    done
    
    # Show reboot status
    if is_reboot_required; then
        local reboot_module=$(get_reboot_module)
        echo -e "\n${YELLOW}⚠ Reboot required after module: $reboot_module${NC}"
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════"
}

# Reset deployment state
reset_state() {
    log_warn "Resetting deployment state"
    
    if [ -f "$STATE_FILE" ]; then
        backup_file "$STATE_FILE"
        rm -f "$STATE_FILE"
    fi
    
    if [ -d "$LOCK_FILE" ]; then
        rm -rf "$LOCK_FILE"
    fi
    
    init_state
}

# Trap to ensure lock is released
trap 'release_lock' EXIT

# Export functions
export -f init_state acquire_lock release_lock update_state get_state
export -f set_module_status get_module_status is_module_completed get_next_module
export -f set_reboot_required is_reboot_required get_reboot_module clear_reboot_required
export -f update_system_info get_progress show_status reset_state