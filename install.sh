#!/bin/bash
# UbiVision Server Setup Remote Installer
# =======================================
# Usage: curl -fsSL https://raw.githubusercontent.com/ubihere/ubivision-server-setup/main/install.sh | bash

set -euo pipefail

# Configuration
REPOSITORY_URL="https://github.com/ubihere/ubivision-server-setup.git"
BRANCH="master"
INSTALL_DIR="/opt/ubivision-server-setup"
TEMP_DIR="/tmp/ubivision-server-setup-install"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
    exit 1
fi

# Check sudo privileges and setup passwordless sudo if needed
if ! sudo -n true 2>/dev/null; then
    log_info "Setting up passwordless sudo for current user..."
    echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER > /dev/null
    
    # Verify sudo is now working
    if ! sudo -n true 2>/dev/null; then
        log_error "Failed to configure passwordless sudo. Please check your sudo configuration."
        exit 1
    fi
    
    log_info "Passwordless sudo configured successfully"
fi

# Banner
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                        UBIVISION SERVER SETUP                               ║
║                         Remote Installation                                  ║
║                                                                              ║
║    Automated Ubuntu 22.04 deployment system with NVIDIA GPU support        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF

echo
log "Starting UbiVision Server Setup remote installation"

# Basic system checks
log_info "Performing system checks..."

# Check Ubuntu version
if ! lsb_release -a 2>/dev/null | grep -q "Ubuntu 22.04"; then
    log_warn "This script is designed for Ubuntu 22.04. Your system:"
    lsb_release -a 2>/dev/null | grep "Description:" || echo "Unknown distribution"
    
    # Check if running in non-interactive mode (e.g., via curl | bash)
    if [[ -t 0 ]]; then
        # Interactive mode - prompt user
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Installation cancelled"
            exit 1
        fi
    else
        # Non-interactive mode - continue with warning
        log_warn "Running in non-interactive mode - continuing on unsupported Ubuntu version"
    fi
fi

# Check internet connectivity
log_info "Checking internet connectivity..."
if ! ping -c 1 google.com >/dev/null 2>&1; then
    log_error "No internet connectivity. Please check your network connection."
    exit 1
fi

# Check for existing installation
if [ -d "$INSTALL_DIR" ]; then
    log_warn "Existing installation found at $INSTALL_DIR"
    
    # Check if running in non-interactive mode (e.g., via curl | bash)
    if [[ -t 0 ]]; then
        # Interactive mode - prompt user
        read -p "Remove existing installation and continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing installation..."
            sudo rm -rf "$INSTALL_DIR"
        else
            log_error "Installation cancelled"
            exit 1
        fi
    else
        # Non-interactive mode - automatically overwrite with warning
        log_warn "Running in non-interactive mode - automatically overwriting existing installation"
        log_info "Removing existing installation..."
        sudo rm -rf "$INSTALL_DIR"
    fi
fi

# Install prerequisites
log_info "Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y git curl wget jq

# Clean up any previous installation attempts
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Clone repository
log_info "Downloading UbiVision Server Setup from $REPOSITORY_URL"
cd "$TEMP_DIR"

# Retry mechanism for git clone
for attempt in {1..3}; do
    if git clone -b "$BRANCH" "$REPOSITORY_URL" .; then
        break
    fi
    
    if [ $attempt -eq 3 ]; then
        log_error "Failed to clone repository after 3 attempts"
        exit 1
    fi
    
    log_warn "Clone attempt $attempt failed, retrying in 5 seconds..."
    sleep 5
done

# Verify repository structure
if [ ! -f "setup" ] || [ ! -d "modules" ] || [ ! -d "lib" ]; then
    log_error "Invalid repository structure"
    exit 1
fi

# Install to system location
log_info "Installing UbiVision Server Setup to $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r . "$INSTALL_DIR/"

# Set permissions
sudo chown -R root:root "$INSTALL_DIR"
sudo chmod +x "$INSTALL_DIR/setup"
sudo chmod +x "$INSTALL_DIR/modules"/* 2>/dev/null || true
sudo chmod +x "$INSTALL_DIR/lib"/*.sh

# Create wrapper script for easy access
cat > /tmp/ubivision-wrapper << EOF
#!/bin/bash
# UbiVision Server Setup Wrapper
cd "$INSTALL_DIR" || { echo "ERROR: Cannot change to $INSTALL_DIR"; exit 1; }
exec ./setup "\$@"
EOF
sudo mv /tmp/ubivision-wrapper /usr/local/bin/ubivision-server-setup
sudo chmod +x /usr/local/bin/ubivision-server-setup

# Create auto-resume service
log_info "Creating auto-resume service..."
sudo tee /etc/systemd/system/ubivision-server-setup-resume.service > /dev/null << 'EOF'
[Unit]
Description=UbiVision Server Setup Auto-Resume
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
WorkingDirectory=/opt/ubivision-server-setup
ExecStart=/opt/ubivision-server-setup/setup --resume
StandardOutput=journal
StandardError=journal
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ubivision-server-setup-resume

# Clean up
rm -rf "$TEMP_DIR"

log_info "Installation completed successfully!"

echo
echo "═══════════════════════════════════════════════════════════════"
echo "                    INSTALLATION COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "UbiVision Server Setup has been installed successfully."
echo
echo "Available commands:"
echo "  ubivision-server-setup              - Start deployment"
echo "  ubivision-server-setup --status     - Show deployment status"
echo "  ubivision-server-setup --resume     - Resume after reboot"
echo "  ubivision-server-setup --reset      - Reset deployment state"
echo "  ubivision-server-setup --help       - Show help"
echo
echo "To start deployment, run:"
echo "  ubivision-server-setup"
echo
echo "═══════════════════════════════════════════════════════════════"

# Only auto-start deployment if running interactively
if [[ -t 0 ]]; then
    echo
    read -p "Start deployment now? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Starting deployment..."
        cd "$INSTALL_DIR"
        exec ./setup
    fi
fi