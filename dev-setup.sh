#!/bin/bash
# UbiVision Development Environment Setup
# ========================================
# Minimal setup for development machines working with UbiVision projects
# Based on the server setup but optimized for development

set -euo pipefail

# Script configuration
SCRIPT_VERSION="2.0.0"
LOG_FILE="/tmp/dev-setup-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration flags
INSTALL_GPU=${INSTALL_GPU:-auto}           # auto, yes, no
INSTALL_DOCKER=${INSTALL_DOCKER:-yes}      # yes, no
INSTALL_CUDA=${INSTALL_CUDA:-auto}         # auto, yes, no
ENABLE_TAILSCALE=${ENABLE_TAILSCALE:-yes} # yes, no

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO] $1${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        log_info "Please run as a regular user with sudo privileges"
        exit 1
    fi
}

# Detect system information
detect_system() {
    log_info "Detecting system configuration..."
    
    # OS detection
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
    fi
    
    # Check for NVIDIA GPU
    HAS_NVIDIA_GPU=false
    if lspci | grep -i nvidia > /dev/null 2>&1; then
        HAS_NVIDIA_GPU=true
    fi
    
    # Auto-configure GPU installation
    if [ "$INSTALL_GPU" = "auto" ]; then
        if [ "$HAS_NVIDIA_GPU" = true ]; then
            INSTALL_GPU=yes
            log_info "NVIDIA GPU detected, will install drivers"
        else
            INSTALL_GPU=no
            log_info "No NVIDIA GPU detected, skipping GPU setup"
        fi
    fi
    
    # Auto-configure CUDA
    if [ "$INSTALL_CUDA" = "auto" ]; then
        INSTALL_CUDA=$INSTALL_GPU
    fi
    
    log_success "System detection complete"
    echo "  OS: $OS_NAME $OS_VERSION"
    echo "  NVIDIA GPU: $HAS_NVIDIA_GPU"
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    
    # Install essential packages (matching server setup)
    local packages=(
        htop
        nano
        vim
        git
        build-essential
        python3-pip
        python3-venv
        magic-wormhole
        openssh-client
        net-tools
        curl
        wget
        jq
        software-properties-common
        apt-transport-https
        ca-certificates
        gnupg
        lsb-release
    )
    
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
    
    log_success "System packages updated"
}

# Configure Git
configure_git() {
    log_info "Configuring Git..."
    
    # Only configure if not already set
    if ! git config --global user.name > /dev/null 2>&1; then
        read -p "Enter your Git user name: " git_name
        git config --global user.name "$git_name"
    fi
    
    if ! git config --global user.email > /dev/null 2>&1; then
        read -p "Enter your Git email: " git_email
        git config --global user.email "$git_email"
    fi
    
    # Set useful defaults
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    
    log_success "Git configured"
}

# Install Python development essentials
install_python_dev() {
    log_info "Installing Python development tools..."
    
    # Basic Python packages
    local python_packages=(
        python3-dev
        python3-pip
        python3-venv
        python3-setuptools
        python3-wheel
        python3-full
        pipx
    )
    
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${python_packages[@]}"
    
    # Install essential Python tools for development using pipx
    pipx install virtualenv
    pipx install black
    pipx install flake8
    
    log_success "Python development tools installed"
}

# Install NVIDIA drivers
install_nvidia_drivers() {
    if [ "$INSTALL_GPU" != "yes" ]; then
        return
    fi
    
    log_info "Installing NVIDIA drivers..."
    
    # Remove old drivers
    sudo apt-get remove --purge -y nvidia-* || true
    sudo apt-get autoremove -y
    
    # Add NVIDIA driver repository
    sudo add-apt-repository ppa:graphics-drivers/ppa -y
    sudo apt-get update
    
    # Install recommended driver
    sudo ubuntu-drivers autoinstall
    
    log_success "NVIDIA drivers installed (reboot required)"
    REBOOT_REQUIRED=true
}

# Install CUDA toolkit
install_cuda() {
    if [ "$INSTALL_CUDA" != "yes" ]; then
        return
    fi
    
    log_info "Installing CUDA toolkit 12.6..."
    
    # CUDA 12.6 installation (matching server setup)
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    rm cuda-keyring_1.1-1_all.deb
    
    sudo apt-get update
    sudo apt-get -y install cuda-toolkit-12-6
    
    # Add CUDA to PATH
    if ! grep -q "/usr/local/cuda/bin" ~/.bashrc; then
        cat >> ~/.bashrc << 'EOF'

# CUDA configuration
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF
    fi
    
    log_success "CUDA toolkit installed"
}

# Install Docker (matching server setup)
install_docker() {
    if [ "$INSTALL_DOCKER" != "yes" ]; then
        return
    fi
    
    log_info "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Install NVIDIA Container Toolkit if GPU is enabled
    if [ "$INSTALL_GPU" = "yes" ]; then
        log_info "Installing NVIDIA Container Toolkit..."
        
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
        
        sudo apt-get update
        sudo apt-get install -y nvidia-container-toolkit
        
        sudo systemctl restart docker
    fi
    
    log_success "Docker installed"
}

# Install Tailscale
install_tailscale() {
    if [ "$ENABLE_TAILSCALE" != "yes" ]; then
        return
    fi
    
    log_info "Installing Tailscale..."
    
    curl -fsSL https://tailscale.com/install.sh | sh
    
    log_success "Tailscale installed"
    log_info "Run 'sudo tailscale up' to connect to your Tailscale network"
}

# Setup SSH key
setup_ssh() {
    log_info "Setting up SSH..."
    
    # Create SSH directory with correct permissions
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Generate SSH key if not exists
    if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then
        read -p "Generate SSH key for Git? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter email for SSH key: " ssh_email
            ssh-keygen -t ed25519 -C "$ssh_email" -N "" -f ~/.ssh/id_ed25519
            log_info "SSH key generated. Add ~/.ssh/id_ed25519.pub to your Git provider"
        fi
    else
        log_info "SSH key already exists"
    fi
}

# Create development workspace
setup_workspace() {
    log_info "Setting up development workspace..."
    
    # Create standard development directories
    mkdir -p ~/Development/{projects,docker,scripts}
    
    log_success "Workspace created at ~/Development/"
}

# Validate installation
validate_installation() {
    log_info "Validating installation..."
    
    echo
    echo "Installation Summary:"
    echo "===================="
    
    # Check Git
    if command -v git >/dev/null 2>&1; then
        log_success "Git: $(git --version)"
    else
        log_error "Git not installed"
    fi
    
    # Check Python
    if command -v python3 >/dev/null 2>&1; then
        log_success "Python: $(python3 --version)"
    else
        log_error "Python not installed"
    fi
    
    # Check Docker
    if [ "$INSTALL_DOCKER" = "yes" ]; then
        if command -v docker >/dev/null 2>&1; then
            if sudo docker run --rm hello-world >/dev/null 2>&1; then
                log_success "Docker: Working"
            else
                log_warn "Docker: Installed but needs reboot/relogin for group membership"
            fi
        else
            log_error "Docker not installed"
        fi
    fi
    
    # Check GPU
    if [ "$INSTALL_GPU" = "yes" ]; then
        if command -v nvidia-smi >/dev/null 2>&1; then
            if nvidia-smi >/dev/null 2>&1; then
                log_success "NVIDIA GPU: Working"
            else
                log_warn "NVIDIA GPU: Driver installed but needs reboot"
            fi
        else
            log_warn "NVIDIA GPU: Driver installed but nvidia-smi not found (reboot required)"
        fi
    fi
    
    # Check Tailscale
    if [ "$ENABLE_TAILSCALE" = "yes" ]; then
        if command -v tailscale >/dev/null 2>&1; then
            log_success "Tailscale: Installed"
        else
            log_error "Tailscale not installed"
        fi
    fi
}

# Show completion message
show_completion() {
    echo
    echo "════════════════════════════════════════════════════════════════"
    echo "         UBIVISION DEVELOPMENT ENVIRONMENT SETUP COMPLETE"
    echo "════════════════════════════════════════════════════════════════"
    echo
    echo "Installed Components:"
    echo "--------------------"
    echo "✓ Essential system packages"
    echo "✓ Git configuration"
    echo "✓ Python development tools"
    
    [ "$INSTALL_DOCKER" = "yes" ] && echo "✓ Docker and Docker Compose"
    [ "$INSTALL_GPU" = "yes" ] && echo "✓ NVIDIA drivers"
    [ "$INSTALL_CUDA" = "yes" ] && echo "✓ CUDA toolkit 12.6"
    [ "$ENABLE_TAILSCALE" = "yes" ] && echo "✓ Tailscale VPN"
    
    echo
    echo "Next Steps:"
    echo "-----------"
    
    if [ "${REBOOT_REQUIRED:-false}" = true ]; then
        echo "⚠️  IMPORTANT: System reboot required for NVIDIA driver activation"
        echo
    fi
    
    echo "1. Reload shell: source ~/.bashrc"
    
    [ "$INSTALL_DOCKER" = "yes" ] && echo "2. Log out and back in for Docker group membership"
    
    if [ -f ~/.ssh/id_ed25519.pub ] || [ -f ~/.ssh/id_rsa.pub ]; then
        echo "3. Add SSH key to GitHub/GitLab:"
        if [ -f ~/.ssh/id_ed25519.pub ]; then
            echo "   cat ~/.ssh/id_ed25519.pub"
        else
            echo "   cat ~/.ssh/id_rsa.pub"
        fi
    fi
    
    [ "$ENABLE_TAILSCALE" = "yes" ] && echo "4. Connect to Tailscale: sudo tailscale up"
    
    echo
    echo "Workspace: ~/Development/"
    echo "Log file: $LOG_FILE"
    echo
    echo "════════════════════════════════════════════════════════════════"
    
    if [ "${REBOOT_REQUIRED:-false}" = true ]; then
        echo
        read -p "Reboot now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo reboot
        fi
    fi
}

# Main execution
main() {
    check_root
    
    # Header
    clear
    echo "════════════════════════════════════════════════════════════════"
    echo "         UBIVISION DEVELOPMENT ENVIRONMENT SETUP"
    echo "                    Version $SCRIPT_VERSION"
    echo "════════════════════════════════════════════════════════════════"
    echo
    echo "This script will set up your Ubuntu system for UbiVision development."
    echo "It installs only the essential tools needed for the project."
    echo
    echo "Configuration:"
    echo "  INSTALL_GPU=$INSTALL_GPU"
    echo "  INSTALL_DOCKER=$INSTALL_DOCKER"
    echo "  INSTALL_CUDA=$INSTALL_CUDA"
    echo "  ENABLE_TAILSCALE=$ENABLE_TAILSCALE"
    echo
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # Run installation steps
    detect_system
    update_system
    configure_git
    install_python_dev
    install_nvidia_drivers
    install_cuda
    install_docker
    install_tailscale
    setup_ssh
    setup_workspace
    
    # Validate and complete
    validate_installation
    show_completion
}

# Run main function
main "$@"