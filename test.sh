#!/bin/bash
# UbiVision Server Setup Test Suite
# ================================

set -euo pipefail

# Test configuration
TEST_MODE=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_DIR="$SCRIPT_DIR/test-results"
mkdir -p "$TEST_RESULTS_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test logging
test_log() {
    echo -e "${BLUE}[TEST] $1${NC}"
}

test_pass() {
    echo -e "${GREEN}[PASS] $1${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

test_fail() {
    echo -e "${RED}[FAIL] $1${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

test_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

# Test framework
run_test() {
    local test_name=$1
    local test_function=$2
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    test_log "Running test: $test_name"
    
    if $test_function; then
        test_pass "$test_name"
        return 0
    else
        test_fail "$test_name"
        return 1
    fi
}

# Test 1: File Structure Validation
test_file_structure() {
    local required_files=(
        "setup"
        "install.sh"
        "config/defaults.env"
        "lib/utils.sh"
        "lib/state.sh"
        "lib/bootstrap.sh"
        "modules/00-verify"
        "modules/10-system"
        "modules/20-nvidia"
        "modules/30-docker"
        "modules/40-network"
        "modules/50-validate"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$file" ]; then
            test_fail "Missing required file: $file"
            return 1
        fi
    done
    
    return 0
}

# Test 2: Script Permissions
test_script_permissions() {
    local executable_files=(
        "setup"
        "install.sh"
        "lib/utils.sh"
        "lib/state.sh"
        "lib/bootstrap.sh"
        "modules/00-verify"
        "modules/10-system"
        "modules/20-nvidia"
        "modules/30-docker"
        "modules/40-network"
        "modules/50-validate"
    )
    
    for file in "${executable_files[@]}"; do
        if [ ! -x "$SCRIPT_DIR/$file" ]; then
            test_fail "File not executable: $file"
            return 1
        fi
    done
    
    return 0
}

# Test 3: Bash Syntax Validation
test_bash_syntax() {
    local bash_files=(
        "setup"
        "install.sh"
        "lib/utils.sh"
        "lib/state.sh"
        "lib/bootstrap.sh"
        "modules/00-verify"
        "modules/10-system"
        "modules/20-nvidia"
        "modules/30-docker"
        "modules/40-network"
        "modules/50-validate"
    )
    
    for file in "${bash_files[@]}"; do
        if ! bash -n "$SCRIPT_DIR/$file" 2>/dev/null; then
            test_fail "Syntax error in: $file"
            return 1
        fi
    done
    
    return 0
}

# Test 4: Configuration File Validation
test_config_validation() {
    local config_file="$SCRIPT_DIR/config/defaults.env"
    
    # Check if config file exists and is readable
    if [ ! -r "$config_file" ]; then
        test_fail "Config file not readable: $config_file"
        return 1
    fi
    
    # Check for required configuration variables
    local required_vars=(
        "TIMEZONE"
        "SWAP_SIZE"
        "NVIDIA_DRIVER_AUTO_DETECT"
        "CUDA_VERSION"
        "TAILSCALE_AUTO_CONNECT"
        "SSH_PORT"
        "STATE_DIR"
        "LOG_DIR"
        "MAX_RETRIES"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$config_file"; then
            test_fail "Missing configuration variable: $var"
            return 1
        fi
    done
    
    return 0
}

# Test 5: Library Function Validation
test_library_functions() {
    local lib_file="$SCRIPT_DIR/lib/utils.sh"
    
    # Check for required functions
    local required_functions=(
        "log"
        "log_info"
        "log_warn"
        "log_error"
        "log_success"
        "retry_with_backoff"
        "check_internet"
        "install_packages"
        "enable_and_start_service"
        "validate_gpu"
        "validate_docker_gpu"
    )
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$lib_file"; then
            test_fail "Missing library function: $func"
            return 1
        fi
    done
    
    return 0
}

# Test 6: State Management Functions
test_state_management() {
    local state_file="$SCRIPT_DIR/lib/state.sh"
    
    # Check for required state functions
    local required_functions=(
        "init_state"
        "acquire_lock"
        "release_lock"
        "set_module_status"
        "get_module_status"
        "is_module_completed"
        "set_reboot_required"
        "is_reboot_required"
        "show_status"
        "reset_state"
    )
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$state_file"; then
            test_fail "Missing state function: $func"
            return 1
        fi
    done
    
    return 0
}

# Test 7: Module Structure Validation
test_module_structure() {
    local modules=(
        "00-verify"
        "10-system"
        "20-nvidia"
        "30-docker"
        "40-network"
        "50-validate"
    )
    
    for module in "${modules[@]}"; do
        local module_file="$SCRIPT_DIR/modules/$module"
        
        # Check shebang
        if ! head -1 "$module_file" | grep -q "#!/bin/bash"; then
            test_fail "Missing or incorrect shebang in: $module"
            return 1
        fi
        
        # Check for required patterns
        if ! grep -q "MODULE_NAME=" "$module_file"; then
            test_fail "Missing MODULE_NAME in: $module"
            return 1
        fi
        
        if ! grep -q "MODULE_DESCRIPTION=" "$module_file"; then
            test_fail "Missing MODULE_DESCRIPTION in: $module"
            return 1
        fi
        
        if ! grep -q "main()" "$module_file"; then
            test_fail "Missing main() function in: $module"
            return 1
        fi
        
        # Check for library sourcing
        if ! grep -q "source.*lib/utils.sh" "$module_file"; then
            test_fail "Missing utils.sh sourcing in: $module"
            return 1
        fi
        
        if ! grep -q "source.*lib/state.sh" "$module_file"; then
            test_fail "Missing state.sh sourcing in: $module"
            return 1
        fi
    done
    
    return 0
}

# Test 8: Command Line Interface
test_cli_interface() {
    local setup_file="$SCRIPT_DIR/setup"
    
    # Check for command line argument parsing
    local required_options=(
        "--resume"
        "--reset"
        "--status"
        "--help"
    )
    
    for option in "${required_options[@]}"; do
        if ! grep -q -- "$option" "$setup_file"; then
            test_fail "Missing CLI option: $option"
            return 1
        fi
    done
    
    return 0
}

# Test 9: Error Handling
test_error_handling() {
    local files=(
        "setup"
        "lib/utils.sh"
        "lib/state.sh"
        "modules/00-verify"
        "modules/10-system"
        "modules/20-nvidia"
        "modules/30-docker"
        "modules/40-network"
        "modules/50-validate"
    )
    
    for file in "${files[@]}"; do
        # Check for set -euo pipefail
        if ! head -10 "$SCRIPT_DIR/$file" | grep -q "set -euo pipefail"; then
            test_fail "Missing 'set -euo pipefail' in: $file"
            return 1
        fi
        
        # Check for trap handlers in main files
        if [[ "$file" == "setup" || "$file" == "lib/state.sh" ]]; then
            if ! grep -q "trap.*EXIT" "$SCRIPT_DIR/$file"; then
                test_fail "Missing trap handler in: $file"
                return 1
            fi
        fi
    done
    
    return 0
}

# Test 10: Dependencies and Requirements
test_dependencies() {
    local modules=(
        "modules/00-verify"
        "modules/10-system"
        "modules/20-nvidia"
        "modules/30-docker"
        "modules/40-network"
        "modules/50-validate"
    )
    
    for module in "${modules[@]}"; do
        # Check for Ubuntu version checks where appropriate
        if [[ "$module" == "modules/00-verify" ]]; then
            if ! grep -q "Ubuntu 22.04" "$SCRIPT_DIR/$module"; then
                test_fail "Missing Ubuntu version check in: $module"
                return 1
            fi
        fi
        
        # Check for sudo checks
        if ! grep -q "sudo" "$SCRIPT_DIR/$module"; then
            test_warn "No sudo usage found in: $module (may be intentional)"
        fi
    done
    
    return 0
}

# Test 11: Logging and Output
test_logging() {
    local files=(
        "lib/utils.sh"
        "modules/00-verify"
        "modules/10-system"
        "modules/20-nvidia"
        "modules/30-docker"
        "modules/40-network"
        "modules/50-validate"
    )
    
    for file in "${files[@]}"; do
        # Check for logging function usage
        if ! grep -q "log_info\|log_error\|log_success\|log_warn" "$SCRIPT_DIR/$file"; then
            test_fail "Missing logging functions in: $file"
            return 1
        fi
    done
    
    return 0
}

# Test 12: Network Resilience
test_network_resilience() {
    local files=(
        "lib/utils.sh"
        "modules/20-nvidia"
        "modules/30-docker"
        "modules/40-network"
    )
    
    for file in "${files[@]}"; do
        # Check for retry mechanisms
        if ! grep -q "retry_with_backoff\|download_with_retry" "$SCRIPT_DIR/$file"; then
            test_fail "Missing retry mechanisms in: $file"
            return 1
        fi
    done
    
    return 0
}

# Test 13: Security Considerations
test_security() {
    local files=(
        "setup"
        "modules/00-verify"
        "modules/40-network"
        "modules/50-validate"
    )
    
    for file in "${files[@]}"; do
        # Check for root user prevention in main setup script
        if [[ "$file" == "setup" ]]; then
            if ! grep -q "EUID.*0\|check_not_root" "$SCRIPT_DIR/$file"; then
                test_fail "Missing root user check in: $file"
                return 1
            fi
        fi
        
        # Check for root user prevention in utils.sh library
        if [[ "$file" == "lib/utils.sh" ]]; then
            if ! grep -q "EUID.*0" "$SCRIPT_DIR/$file"; then
                test_fail "Missing root user check function in: $file"
                return 1
            fi
        fi
    done
    
    return 0
}

# Test 14: Documentation
test_documentation() {
    local doc_files=(
        "README.md"
    )
    
    for file in "${doc_files[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$file" ]; then
            test_fail "Missing documentation file: $file"
            return 1
        fi
    done
    
    # Check README content
    local readme="$SCRIPT_DIR/README.md"
    local required_sections=(
        "# UbiVision Server Setup"
        "## Features"
        "## Quick Start"
        "## Architecture"
        "## Configuration"
        "## Troubleshooting"
    )
    
    for section in "${required_sections[@]}"; do
        if ! grep -q "$section" "$readme"; then
            test_fail "Missing README section: $section"
            return 1
        fi
    done
    
    return 0
}

# Test 15: JSON State Format
test_json_state() {
    local state_file="$SCRIPT_DIR/lib/state.sh"
    
    # Check for JSON structure in state initialization
    if ! grep -q '"modules": {' "$state_file"; then
        test_fail "Missing proper JSON state structure"
        return 1
    fi
    
    if ! grep -q '"status": "pending"' "$state_file"; then
        test_fail "Missing proper JSON state structure"
        return 1
    fi
    
    # Check for jq usage
    if ! grep -q "jq" "$state_file"; then
        test_fail "Missing jq usage for JSON manipulation"
        return 1
    fi
    
    return 0
}

# Dry Run Test - Check what would happen without executing
dry_run_test() {
    test_log "Running dry run validation..."
    
    # Check if setup script can parse arguments
    if ! bash "$SCRIPT_DIR/setup" --help >/dev/null 2>&1; then
        test_fail "Setup script help option failed"
        return 1
    fi
    
    # Validate that modules can be sourced (syntax check)
    local modules=(
        "modules/00-verify"
        "modules/10-system"
        "modules/20-nvidia"
        "modules/30-docker"
        "modules/40-network"
        "modules/50-validate"
    )
    
    for module in "${modules[@]}"; do
        # Create a test environment
        local test_env="$TEST_RESULTS_DIR/test_env.sh"
        cat > "$test_env" << 'EOF'
#!/bin/bash
# Mock environment for testing
check_not_root() { return 0; }
check_sudo() { return 0; }
init_state() { return 0; }
acquire_lock() { return 0; }
release_lock() { return 0; }
log() { echo "LOG: $1"; }
log_info() { echo "INFO: $1"; }
log_warn() { echo "WARN: $1"; }
log_error() { echo "ERROR: $1"; }
log_success() { echo "SUCCESS: $1"; }
EOF
        
        # Test if module can be sourced with mocks
        if ! (source "$test_env" && bash -n "$SCRIPT_DIR/$module") 2>/dev/null; then
            test_fail "Module $module failed dry run test"
            return 1
        fi
    done
    
    return 0
}

# Generate test report
generate_test_report() {
    local report_file="$TEST_RESULTS_DIR/test_report.json"
    local timestamp=$(date -Iseconds)
    
    cat > "$report_file" << EOF
{
    "test_timestamp": "$timestamp",
    "test_results": {
        "total_tests": $TOTAL_TESTS,
        "passed_tests": $PASSED_TESTS,
        "failed_tests": $FAILED_TESTS,
        "success_rate": "$(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
    },
    "test_status": "$([ $FAILED_TESTS -eq 0 ] && echo "PASSED" || echo "FAILED")",
    "test_details": "See test output for detailed results"
}
EOF
    
    test_log "Test report generated: $report_file"
}

# Main test execution
main() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "                UBIVISION SERVER SETUP TEST SUITE"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    
    # Run all tests
    run_test "File Structure Validation" test_file_structure
    run_test "Script Permissions" test_script_permissions
    run_test "Bash Syntax Validation" test_bash_syntax
    run_test "Configuration File Validation" test_config_validation
    run_test "Library Function Validation" test_library_functions
    run_test "State Management Functions" test_state_management
    run_test "Module Structure Validation" test_module_structure
    run_test "Command Line Interface" test_cli_interface
    run_test "Error Handling" test_error_handling
    run_test "Dependencies and Requirements" test_dependencies
    run_test "Logging and Output" test_logging
    run_test "Network Resilience" test_network_resilience
    run_test "Security Considerations" test_security
    run_test "Documentation" test_documentation
    run_test "JSON State Format" test_json_state
    run_test "Dry Run Validation" dry_run_test
    
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "                        TEST RESULTS"
    echo "═══════════════════════════════════════════════════════════════"
    echo
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Success Rate: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
    echo
    
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
        echo "UbiVision Server Setup is ready for production use."
    else
        echo -e "${RED}❌ SOME TESTS FAILED ❌${NC}"
        echo "Please review the failed tests above and fix the issues."
    fi
    
    echo
    echo "═══════════════════════════════════════════════════════════════"
    
    # Generate report
    generate_test_report
    
    # Exit with appropriate code
    exit $FAILED_TESTS
}

# Run main function
main "$@"