#!/bin/bash
# UbiVision Server Setup Bootstrap
# ===============================

set -euo pipefail

BOOTSTRAP_VERSION="1.0.0"
REPOSITORY_URL="https://github.com/ubihere/ubivision-server-setup"
INSTALL_DIR="/opt/ubivision-server-setup"
TEMP_DIR="/tmp/ubivision-server-setup-bootstrap"

# Bootstrap self-extraction and setup
bootstrap_self() {
    log_info "Starting UbiVision Server Setup Bootstrap v$BOOTSTRAP_VERSION"
    
    # Clean up any previous bootstrap attempts
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Check if we're running from a pipe (remote installation)
    if [ -t 0 ]; then
        log_info "Running from terminal"
        BOOTSTRAP_MODE="local"
    else
        log_info "Running from pipe (remote installation)"
        BOOTSTRAP_MODE="remote"
    fi
    
    # Extract or clone the deployment tower
    if [ "$BOOTSTRAP_MODE" = "remote" ]; then
        download_deployment_tower
    else
        setup_local_deployment_tower
    fi
    
    # Install deployment tower
    install_deployment_tower
    
    # Create systemd service for auto-resume
    create_resume_service
    
    log_success "Bootstrap completed successfully"
}

# Download server setup from repository
download_deployment_tower() {
    log_info "Downloading UbiVision Server Setup from $REPOSITORY_URL"
    
    # Install git if not present
    if ! command -v git >/dev/null 2>&1; then
        log_info "Installing git..."
        retry_with_backoff 3 5 sudo apt-get update
        retry_with_backoff 3 5 sudo apt-get install -y git
    fi
    
    # Clone repository
    cd "$TEMP_DIR"
    retry_with_backoff 3 5 git clone "$REPOSITORY_URL" .
    
    if [ ! -f "setup" ]; then
        log_error "Invalid UbiVision Server Setup repository structure"
        exit 1
    fi
    
    log_success "Downloaded UbiVision Server Setup successfully"
}

# Setup local deployment tower (when running from local directory)
setup_local_deployment_tower() {
    log_info "Setting up local deployment tower"
    
    # Find the deployment tower directory
    local source_dir="$PWD"
    
    # Check if we're in the deployment tower directory
    if [ ! -f "setup" ] || [ ! -d "modules" ]; then
        log_error "Not in deployment tower directory or missing files"
        exit 1
    fi
    
    # Copy to temp directory
    cp -r . "$TEMP_DIR/"
    
    log_success "Local deployment tower setup completed"
}

# Install server setup to system location
install_deployment_tower() {
    log_info "Installing UbiVision Server Setup to $INSTALL_DIR"
    
    # Create installation directory
    sudo mkdir -p "$INSTALL_DIR"
    
    # Copy files
    sudo cp -r "$TEMP_DIR"/* "$INSTALL_DIR/"
    
    # Set permissions
    sudo chown -R root:root "$INSTALL_DIR"
    sudo chmod +x "$INSTALL_DIR/setup"
    sudo chmod +x "$INSTALL_DIR/modules"/*
    sudo chmod +x "$INSTALL_DIR/lib"/*.sh
    
    # Create symlink for easy access
    sudo ln -sf "$INSTALL_DIR/setup" /usr/local/bin/ubivision-server-setup
    
    log_success "UbiVision Server Setup installed successfully"
}

# Create systemd service for auto-resume after reboot
create_resume_service() {
    log_info "Creating auto-resume service"
    
    local service_content='[Unit]
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
WantedBy=multi-user.target'
    
    create_systemd_service "ubivision-server-setup-resume" "$service_content"
    
    # Enable but don't start (will be started on reboot when needed)
    sudo systemctl enable ubivision-server-setup-resume
    
    log_success "Auto-resume service created and enabled"
}

# Self-extracting script creation
create_self_extracting_installer() {
    local output_file=${1:-"install.sh"}
    
    log_info "Creating self-extracting installer: $output_file"
    
    # Create header
    cat > "$output_file" << 'EOF'
#!/bin/bash
# Deployment Tower Self-Extracting Installer
# Generated automatically - do not edit

set -euo pipefail

# Extract payload
PAYLOAD_LINE=$(awk '/^__PAYLOAD_BEGIN__/{print NR + 1; exit 0; }' "$0")
tail -n +$PAYLOAD_LINE "$0" | base64 -d | tar -xzf - -C /tmp/

# Change to extracted directory
cd /tmp/deployment-tower/

# Run bootstrap
./lib/bootstrap.sh

# Run main setup
./setup

exit 0

__PAYLOAD_BEGIN__
EOF
    
    # Create payload
    tar -czf - . | base64 >> "$output_file"
    
    chmod +x "$output_file"
    
    log_success "Self-extracting installer created: $output_file"
}

# Handle remote installation
handle_remote_installation() {
    log_info "Handling remote installation"
    
    # Check if we're being piped from curl
    if [ -t 0 ]; then
        log_error "This script is designed for remote installation: curl -fsSL https://example.com/install.sh | bash"
        exit 1
    fi
    
    # Install essential packages first
    sudo apt-get update
    sudo apt-get install -y curl wget git jq
    
    # Continue with bootstrap
    bootstrap_self
    
    # Start the main setup
    exec "$INSTALL_DIR/setup"
}

# Create distribution package
create_distribution() {
    local dist_dir="dist"
    local version=${1:-"latest"}
    
    log_info "Creating distribution package"
    
    mkdir -p "$dist_dir"
    
    # Create self-extracting installer
    create_self_extracting_installer "$dist_dir/install.sh"
    
    # Create tarball
    tar -czf "$dist_dir/deployment-tower-$version.tar.gz" \
        --exclude="dist" \
        --exclude=".git" \
        --exclude=".state" \
        .
    
    # Create checksums
    cd "$dist_dir"
    sha256sum * > checksums.txt
    
    log_success "Distribution package created in $dist_dir/"
}

# Export functions
export -f bootstrap_self download_deployment_tower setup_local_deployment_tower
export -f install_deployment_tower create_resume_service create_self_extracting_installer
export -f handle_remote_installation create_distribution