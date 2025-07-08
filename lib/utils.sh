#!/bin/bash
# UbiVision Server Setup Utilities
# ===============================

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Ensure log directory exists
ensure_log_dir() {
    if [ -n "${LOG_DIR:-}" ] && [ ! -d "$LOG_DIR" ]; then
        sudo mkdir -p "$LOG_DIR"
        sudo chown -R "$USER:$USER" "$LOG_DIR" 2>/dev/null || true
    fi
}

# Logging functions
log() {
    ensure_log_dir
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_DIR/deployment.log"
}

log_info() {
    ensure_log_dir
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$LOG_DIR/deployment.log"
}

log_warn() {
    ensure_log_dir
    echo -e "${YELLOW}[WARN] $1${NC}" | tee -a "$LOG_DIR/deployment.log"
}

log_error() {
    ensure_log_dir
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_DIR/deployment.log"
}

log_success() {
    ensure_log_dir
    echo -e "${GREEN}[SUCCESS] $1${NC}" | tee -a "$LOG_DIR/deployment.log"
}

# Progress visualization
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    
    printf "\r${CYAN}[%s%s] %d%% %s${NC}" \
        "$(printf "%${filled}s" | tr ' ' '█')" \
        "$(printf "%${empty}s" | tr ' ' '░')" \
        "$percent" \
        "$description"
    
    if [ $current -eq $total ]; then
        echo
    fi
}

# Network retry with exponential backoff
retry_with_backoff() {
    local max_attempts=$1
    local delay=$2
    local exponential=${3:-true}
    shift 3
    
    local attempt=1
    local current_delay=$delay
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt $attempt of $max_attempts: $*"
        
        if "$@"; then
            log_success "Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "All $max_attempts attempts failed"
            return 1
        fi
        
        log_warn "Attempt $attempt failed, retrying in ${current_delay}s..."
        sleep $current_delay
        
        if [ "$exponential" = "true" ]; then
            current_delay=$((current_delay * 2))
        fi
        
        attempt=$((attempt + 1))
    done
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Check sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo privileges. Please run with sudo access."
        exit 1
    fi
}

# Check internet connectivity
check_internet() {
    local test_urls=("google.com" "github.com" "ubuntu.com")
    
    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 3 "$url" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    return 1
}

# Wait for internet connectivity
wait_for_internet() {
    local max_wait=${1:-300}  # 5 minutes default
    local check_interval=10
    local elapsed=0
    
    log_info "Checking internet connectivity..."
    
    while [ $elapsed -lt $max_wait ]; do
        if check_internet; then
            log_success "Internet connectivity confirmed"
            return 0
        fi
        
        log_warn "No internet connectivity, waiting ${check_interval}s... (${elapsed}/${max_wait}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    log_error "Internet connectivity timeout after ${max_wait}s"
    return 1
}

# Download with retry
download_with_retry() {
    local url=$1
    local output=$2
    local max_attempts=${3:-$MAX_RETRIES}
    
    retry_with_backoff $max_attempts $RETRY_DELAY wget -O "$output" "$url" --timeout="$NETWORK_TIMEOUT" --tries=1
}

# Package installation with retry
install_packages() {
    local packages=("$@")
    
    log_info "Installing packages: ${packages[*]}"
    
    # Update package lists first
    retry_with_backoff $MAX_RETRIES $RETRY_DELAY sudo apt-get update -y
    
    # Install packages
    retry_with_backoff $MAX_RETRIES $RETRY_DELAY sudo apt-get install -y "${packages[@]}"
}

# Service management
enable_and_start_service() {
    local service_name=$1
    
    log_info "Enabling and starting service: $service_name"
    
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"
    
    if systemctl is-active --quiet "$service_name"; then
        log_success "Service $service_name is running"
        return 0
    else
        log_error "Service $service_name failed to start"
        return 1
    fi
}

# File backup
backup_file() {
    local file=$1
    local backup_dir="$STATE_DIR/backups"
    
    if [ -f "$file" ]; then
        mkdir -p "$backup_dir"
        cp "$file" "$backup_dir/$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
        log_info "Backed up $file"
    fi
}

# Cleanup temporary files
cleanup_temp_files() {
    local temp_dir="/tmp/deployment-tower"
    
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        log_info "Cleaned up temporary files"
    fi
}

# System information gathering
get_system_info() {
    cat << EOF
{
    "hostname": "$(hostname)",
    "username": "$(whoami)",
    "ubuntu_version": "$(lsb_release -d | cut -f2 | tr -d '"')",
    "kernel_version": "$(uname -r)",
    "architecture": "$(dpkg --print-architecture)",
    "total_ram": "$(free -h | grep "^Mem:" | awk '{print $2}')",
    "disk_size": "$(df -h / | awk 'NR==2 {print $2}')",
    "timezone": "$(timedatectl | grep "Time zone" | awk '{print $3}')",
    "primary_interface": "$(ip route | grep default | awk '{print $5}' | head -n1)",
    "ip_address": "$(ip -4 addr show $(ip route | grep default | awk '{print $5}' | head -n1) | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)",
    "mac_address": "$(ip link show $(ip route | grep default | awk '{print $5}' | head -n1) | grep -oP '(?<=link/ether\s)[a-fA-F0-9:]+' | head -n1)",
    "secure_boot": "$(check_secure_boot)",
    "timestamp": "$(date -Iseconds)"
}
EOF
}

# Check Secure Boot status
check_secure_boot() {
    if [ -d /sys/firmware/efi ]; then
        if command -v mokutil >/dev/null 2>&1; then
            if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
                echo "enabled"
            else
                echo "disabled"
            fi
        else
            echo "unknown"
        fi
    else
        echo "not_applicable"
    fi
}

# Validate command exists
require_command() {
    local cmd=$1
    local package=${2:-$cmd}
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command '$cmd' not found. Install with: sudo apt install $package"
        return 1
    fi
}

# Create systemd service
create_systemd_service() {
    local service_name=$1
    local service_content=$2
    local service_file="/etc/systemd/system/${service_name}.service"
    
    log_info "Creating systemd service: $service_name"
    
    backup_file "$service_file"
    echo "$service_content" | sudo tee "$service_file" >/dev/null
    
    sudo systemctl daemon-reload
    log_success "Created systemd service: $service_name"
}

# GPU validation
validate_gpu() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        if nvidia-smi >/dev/null 2>&1; then
            log_success "GPU validation passed"
            return 0
        else
            log_error "GPU validation failed: nvidia-smi not working"
            return 1
        fi
    else
        log_error "GPU validation failed: nvidia-smi not found"
        return 1
    fi
}

# Docker GPU validation
validate_docker_gpu() {
    if command -v docker >/dev/null 2>&1; then
        if docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
            log_success "Docker GPU validation passed"
            return 0
        else
            log_error "Docker GPU validation failed"
            return 1
        fi
    else
        log_error "Docker GPU validation failed: docker not found"
        return 1
    fi
}

# Initialize directories
init_directories() {
    sudo mkdir -p "$STATE_DIR" "$LOG_DIR" "$STATE_DIR/backups"
    sudo chown -R "$USER:$USER" "$STATE_DIR" "$LOG_DIR"
    chmod 755 "$STATE_DIR" "$LOG_DIR"
}

# Load configuration
load_config() {
    local config_file="${1:-$PWD/config/defaults.env}"
    
    if [ -f "$config_file" ]; then
        source "$config_file"
        log_info "Loaded configuration from $config_file"
    else
        log_warn "Configuration file not found: $config_file"
    fi
}

# Export functions for use in modules
export -f log log_info log_warn log_error log_success
export -f show_progress retry_with_backoff check_not_root check_sudo
export -f check_internet wait_for_internet download_with_retry install_packages
export -f enable_and_start_service backup_file cleanup_temp_files
export -f get_system_info check_secure_boot require_command create_systemd_service
export -f validate_gpu validate_docker_gpu init_directories load_config