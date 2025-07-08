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
