#!/bin/bash
# UbiVision Development Environment Test Script
# =============================================
# Comprehensive test suite to verify dev-setup.sh installation

set -euo pipefail

# Script configuration
SCRIPT_VERSION="1.0.0"
TEST_REPORT="/tmp/dev-setup-test-$(date +%Y%m%d-%H%M%S).json"
LOG_FILE="/tmp/dev-setup-test-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Test results array
declare -a TEST_RESULTS=()

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

# Test functions
run_test() {
    local test_name="$1"
    local test_command="$2"
    local test_description="$3"
    local required="${4:-true}"
    
    ((TOTAL_TESTS++))
    
    echo -n "Testing $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED_TESTS++))
        TEST_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"PASS\",\"description\":\"$test_description\"}")
        log_info "✓ $test_name: PASS"
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}FAIL${NC}"
            ((FAILED_TESTS++))
            TEST_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"FAIL\",\"description\":\"$test_description\"}")
            log_error "✗ $test_name: FAIL"
        else
            echo -e "${YELLOW}SKIP${NC}"
            ((SKIPPED_TESTS++))
            TEST_RESULTS+=("{\"name\":\"$test_name\",\"status\":\"SKIP\",\"description\":\"$test_description\"}")
            log_warn "- $test_name: SKIPPED (optional)"
        fi
    fi
}

# Detect system configuration
detect_configuration() {
    log_info "Detecting system configuration..."
    
    # Check for NVIDIA GPU
    HAS_NVIDIA_GPU=false
    if lspci | grep -i nvidia > /dev/null 2>&1; then
        HAS_NVIDIA_GPU=true
        log_info "NVIDIA GPU detected"
    else
        log_info "No NVIDIA GPU detected"
    fi
    
    # Check if Docker should be installed
    EXPECT_DOCKER=true
    
    # Check if Tailscale should be installed
    EXPECT_TAILSCALE=true
    
    log_success "Configuration detection complete"
}

# Test system packages
test_system_packages() {
    log_info "Testing system packages..."
    
    run_test "git" "command -v git" "Git version control system"
    run_test "vim" "command -v vim" "Vim text editor"
    run_test "nano" "command -v nano" "Nano text editor"
    run_test "htop" "command -v htop" "System process monitor"
    run_test "curl" "command -v curl" "HTTP client tool"
    run_test "wget" "command -v wget" "File download utility"
    run_test "jq" "command -v jq" "JSON processor"
    run_test "gcc" "command -v gcc" "GNU C compiler"
    run_test "g++" "command -v g++" "GNU C++ compiler"
    run_test "make" "command -v make" "Build automation tool"
    run_test "magic-wormhole" "command -v wormhole" "Secure file transfer tool"
    run_test "openssh-client" "command -v ssh" "SSH client"
    run_test "net-tools" "command -v netstat" "Network utilities"
}

# Test Git configuration
test_git_config() {
    log_info "Testing Git configuration..."
    
    run_test "git-user-name" "git config --global user.name" "Git user name configured"
    run_test "git-user-email" "git config --global user.email" "Git user email configured"
    run_test "git-default-branch" "[ \"\$(git config --global init.defaultBranch)\" = \"main\" ]" "Git default branch set to main"
    run_test "git-pull-rebase" "[ \"\$(git config --global pull.rebase)\" = \"false\" ]" "Git pull rebase disabled"
}

# Test Python development tools
test_python_dev() {
    log_info "Testing Python development tools..."
    
    run_test "python3" "command -v python3" "Python 3 interpreter"
    run_test "pip3" "command -v pip3" "Python package manager"
    run_test "python3-venv" "python3 -m venv --help" "Python virtual environment support"
    
    # Test pip packages installed for user
    run_test "pip-virtualenv" "pip3 list --user | grep -i virtualenv" "Virtualenv package installed"
    run_test "pip-black" "pip3 list --user | grep -i black" "Black code formatter installed"
    run_test "pip-flake8" "pip3 list --user | grep -i flake8" "Flake8 linter installed"
    
    # Test Python can import key modules
    run_test "python-venv-module" "python3 -c 'import venv'" "Python venv module importable"
    run_test "python-pip-module" "python3 -c 'import pip'" "Python pip module importable"
}

# Test Docker installation
test_docker() {
    if [ "$EXPECT_DOCKER" = false ]; then
        log_info "Docker not expected to be installed, skipping tests"
        return
    fi
    
    log_info "Testing Docker installation..."
    
    run_test "docker-command" "command -v docker" "Docker command available"
    run_test "docker-compose" "docker compose version" "Docker Compose plugin available"
    run_test "docker-buildx" "docker buildx version" "Docker Buildx plugin available"
    
    # Test Docker daemon
    run_test "docker-daemon" "docker info" "Docker daemon running"
    
    # Test Docker hello-world (may require sudo if user not in docker group yet)
    if groups | grep -q docker; then
        run_test "docker-hello-world" "docker run --rm hello-world" "Docker can run containers"
    else
        run_test "docker-hello-world-sudo" "sudo docker run --rm hello-world" "Docker can run containers (with sudo)"
    fi
    
    # Test user in docker group
    run_test "docker-group" "groups | grep -q docker" "User in docker group"
    
    # Test Docker service enabled
    run_test "docker-service-enabled" "systemctl is-enabled docker" "Docker service enabled"
    run_test "docker-service-active" "systemctl is-active docker" "Docker service active"
}

# Test NVIDIA/CUDA installation
test_gpu_cuda() {
    if [ "$HAS_NVIDIA_GPU" = false ]; then
        log_info "No NVIDIA GPU detected, skipping GPU/CUDA tests"
        return
    fi
    
    log_info "Testing NVIDIA/CUDA installation..."
    
    run_test "nvidia-smi" "command -v nvidia-smi" "NVIDIA system management interface"
    run_test "nvidia-smi-output" "nvidia-smi" "NVIDIA driver working" "false"
    
    # Test CUDA toolkit
    run_test "nvcc" "command -v nvcc" "CUDA compiler" "false"
    run_test "cuda-path" "[ -d /usr/local/cuda ]" "CUDA installation directory" "false"
    
    # Test CUDA in PATH
    run_test "cuda-in-path" "echo \$PATH | grep -q cuda" "CUDA in PATH environment" "false"
    
    # Test NVIDIA Container Toolkit (if Docker is installed)
    if [ "$EXPECT_DOCKER" = true ] && command -v docker > /dev/null 2>&1; then
        run_test "nvidia-docker" "docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi" "NVIDIA Docker integration" "false"
    fi
}

# Test Tailscale installation
test_tailscale() {
    if [ "$EXPECT_TAILSCALE" = false ]; then
        log_info "Tailscale not expected to be installed, skipping tests"
        return
    fi
    
    log_info "Testing Tailscale installation..."
    
    run_test "tailscale" "command -v tailscale" "Tailscale command available"
    run_test "tailscaled" "command -v tailscaled" "Tailscale daemon available"
    run_test "tailscale-service" "systemctl list-unit-files | grep -q tailscaled" "Tailscale service installed"
}

# Test SSH configuration
test_ssh_config() {
    log_info "Testing SSH configuration..."
    
    run_test "ssh-directory" "[ -d ~/.ssh ]" "SSH directory exists"
    run_test "ssh-permissions" "[ \"\$(stat -c %a ~/.ssh)\" = \"700\" ]" "SSH directory has correct permissions"
    
    # Test for SSH keys (either RSA or ed25519)
    if [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ]; then
        run_test "ssh-key-exists" "[ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ]" "SSH key exists"
        
        if [ -f ~/.ssh/id_ed25519 ]; then
            run_test "ssh-key-permissions" "[ \"\$(stat -c %a ~/.ssh/id_ed25519)\" = \"600\" ]" "SSH private key permissions"
            run_test "ssh-pub-key" "[ -f ~/.ssh/id_ed25519.pub ]" "SSH public key exists"
        elif [ -f ~/.ssh/id_rsa ]; then
            run_test "ssh-key-permissions" "[ \"\$(stat -c %a ~/.ssh/id_rsa)\" = \"600\" ]" "SSH private key permissions"
            run_test "ssh-pub-key" "[ -f ~/.ssh/id_rsa.pub ]" "SSH public key exists"
        fi
    else
        run_test "ssh-key-exists" "false" "SSH key exists" "false"
    fi
}

# Test workspace setup
test_workspace() {
    log_info "Testing workspace setup..."
    
    run_test "development-dir" "[ -d ~/Development ]" "Development directory exists"
    run_test "projects-dir" "[ -d ~/Development/projects ]" "Projects directory exists"
    run_test "docker-dir" "[ -d ~/Development/docker ]" "Docker directory exists"
    run_test "scripts-dir" "[ -d ~/Development/scripts ]" "Scripts directory exists"
}

# Test environment configuration
test_environment() {
    log_info "Testing environment configuration..."
    
    # Test CUDA environment variables if CUDA is installed
    if command -v nvcc > /dev/null 2>&1; then
        run_test "cuda-path-env" "echo \$PATH | grep -q /usr/local/cuda/bin" "CUDA bin in PATH" "false"
        run_test "cuda-lib-env" "echo \$LD_LIBRARY_PATH | grep -q /usr/local/cuda/lib64" "CUDA libraries in LD_LIBRARY_PATH" "false"
    fi
}

# Generate test report
generate_report() {
    log_info "Generating test report..."
    
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)
    local os_info=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
    
    cat > "$TEST_REPORT" << EOF
{
    "test_run": {
        "timestamp": "$timestamp",
        "hostname": "$hostname",
        "os": "$os_info",
        "script_version": "$SCRIPT_VERSION"
    },
    "summary": {
        "total_tests": $TOTAL_TESTS,
        "passed": $PASSED_TESTS,
        "failed": $FAILED_TESTS,
        "skipped": $SKIPPED_TESTS,
        "success_rate": $(( PASSED_TESTS * 100 / TOTAL_TESTS ))
    },
    "system_info": {
        "has_nvidia_gpu": $HAS_NVIDIA_GPU,
        "expect_docker": $EXPECT_DOCKER,
        "expect_tailscale": $EXPECT_TAILSCALE
    },
    "results": [
        $(IFS=','; echo "${TEST_RESULTS[*]}")
    ]
}
EOF
    
    log_success "Test report generated: $TEST_REPORT"
}

# Show test summary
show_summary() {
    echo
    echo "════════════════════════════════════════════════════════════════"
    echo "           UBIVISION DEVELOPMENT ENVIRONMENT TEST RESULTS"
    echo "════════════════════════════════════════════════════════════════"
    echo
    echo "Test Summary:"
    echo "-------------"
    echo "Total Tests:  $TOTAL_TESTS"
    echo "Passed:       $PASSED_TESTS"
    echo "Failed:       $FAILED_TESTS"
    echo "Skipped:      $SKIPPED_TESTS"
    echo
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "All critical tests passed! ✓"
        echo
        echo "Your development environment appears to be properly configured."
    else
        log_error "$FAILED_TESTS critical tests failed! ✗"
        echo
        echo "Please review the failed tests and re-run dev-setup.sh if needed."
        echo "Check the log file for details: $LOG_FILE"
    fi
    
    if [ $SKIPPED_TESTS -gt 0 ]; then
        log_warn "$SKIPPED_TESTS optional tests were skipped"
        echo "This is normal if certain components weren't installed (e.g., GPU drivers)"
    fi
    
    echo
    echo "Reports:"
    echo "--------"
    echo "Detailed log: $LOG_FILE"
    echo "JSON report:  $TEST_REPORT"
    echo
    echo "════════════════════════════════════════════════════════════════"
    
    # Exit with appropriate code
    if [ $FAILED_TESTS -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Main execution
main() {
    # Header
    clear
    echo "════════════════════════════════════════════════════════════════"
    echo "         UBIVISION DEVELOPMENT ENVIRONMENT TEST SUITE"
    echo "                    Version $SCRIPT_VERSION"
    echo "════════════════════════════════════════════════════════════════"
    echo
    echo "This script will test the installation performed by dev-setup.sh"
    echo
    
    # Initialize test report
    TEST_RESULTS=()
    
    # Run all test suites
    detect_configuration
    test_system_packages
    test_git_config
    test_python_dev
    test_docker
    test_gpu_cuda
    test_tailscale
    test_ssh_config
    test_workspace
    test_environment
    
    # Generate report and show summary
    generate_report
    show_summary
}

# Run main function
main "$@"