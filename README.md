# UbiVision Server Setup

**Production-grade, modular Ubuntu 22.04 deployment system with automatic recovery, reboot handling, and comprehensive logging.**

## Features

- **One-line remote installation**: `curl -fsSL https://your-domain.com/install.sh | bash`
- **Automatic resume after failures or reboots**
- **Network failure retry with exponential backoff**
- **Idempotent operations** (safe to run multiple times)
- **Zero manual intervention required**
- **Comprehensive logging and state tracking**
- **Automatic NVIDIA driver version detection**
- **Modular architecture** for easy updates and maintenance

## Quick Start

### Remote Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ubihere/ubivision-server-setup/main/install.sh | bash
```

### Local Installation

```bash
git clone https://github.com/ubihere/ubivision-server-setup.git
cd ubivision-server-setup
./setup
```

## Architecture

```
ubivision-server-setup/
├── install.sh              # Remote installation entry point
├── setup                   # Main executable
├── modules/                # Modular components
│   ├── 00-verify          # System requirements check
│   ├── 10-system          # Core system setup
│   ├── 20-nvidia          # GPU drivers and CUDA
│   ├── 30-docker          # Container runtime
│   ├── 40-network         # Networking (Tailscale, SSH)
│   └── 50-validate        # Final validation
├── lib/                   # Shared utilities
│   ├── bootstrap.sh       # Self-setup functions
│   ├── state.sh           # State management
│   └── utils.sh           # Shared utilities
├── config/
│   └── defaults.env       # Configuration
└── .state/                # Runtime state (auto-created)
```

## Modules

### 00-verify: System Verification
- Ubuntu 22.04 version check
- Hardware requirements validation
- Network connectivity verification
- Permission and access checks
- Pre-installation preparation

### 10-system: Core System Setup
- Hostname configuration
- Storage expansion
- Swap file creation
- Time synchronization
- Essential package installation
- SSH hardening
- System limits configuration

### 20-nvidia: NVIDIA Setup
- Automatic driver detection
- NVIDIA driver installation
- CUDA toolkit installation
- cuDNN installation
- Environment configuration
- **Automatic reboot handling**

### 30-docker: Docker Installation
- Docker Engine installation
- GPU support configuration
- NVIDIA Container Toolkit
- User permissions setup
- Docker Compose installation
- Comprehensive testing

### 40-network: Network Configuration
- Tailscale VPN installation
- SSH security hardening
- Wake-on-LAN configuration
- System watchdog setup
- GitHub SSH key automation
- Firewall configuration

### 50-validate: Final Validation
- Service validation
- GPU functionality testing
- Docker GPU support verification
- Network connectivity testing
- Security settings validation
- Comprehensive reporting

## State Management

The system uses a JSON-based state machine that tracks:
- Module completion status
- Reboot requirements
- Error recovery information
- System information
- Progress tracking

State persists across reboots in `/var/lib/ubivision-server-setup/state.json`

## Commands

```bash
# Start fresh deployment
./setup

# Resume deployment after reboot
./setup --resume

# Show current status
./setup --status

# Reset deployment state
./setup --reset

# Show help
./setup --help
```

## Configuration

Edit `config/defaults.env` to customize:

```bash
# System Configuration
TIMEZONE="America/New_York"
SWAP_SIZE="2G"

# NVIDIA Configuration
NVIDIA_DRIVER_AUTO_DETECT=true
CUDA_VERSION="12.6.0"

# Network Configuration
TAILSCALE_AUTO_CONNECT=true
SSH_PORT=22

# Security Configuration
DISABLE_AUTOMATIC_UPDATES=true
ENABLE_WATCHDOG=true
ENABLE_WAKE_ON_LAN=true
```

## Automatic Recovery

### Reboot Handling
- NVIDIA module automatically triggers reboot when required
- System resumes deployment after reboot via systemd service
- State is preserved across reboots

### Network Failure Recovery
- Exponential backoff retry for network operations
- Automatic reconnection after temporary failures
- Download resume capability

### Error Recovery
- Each module validates its own success
- Failed modules can be retried independently
- Detailed error logging and reporting

## Logging

Comprehensive logging to:
- `/var/log/ubivision-server-setup/deployment.log`
- System journal (`journalctl -u ubivision-server-setup-resume`)
- Console output with color coding

## Validation

Built-in validation ensures:
- All services are running correctly
- NVIDIA drivers are functional
- Docker GPU support is working
- Network connectivity is established
- Security settings are properly configured

## Requirements

### System Requirements
- Ubuntu 22.04 LTS
- 4GB+ RAM
- 50GB+ disk space
- Internet connectivity
- Sudo privileges

### Hardware Requirements
- NVIDIA GPU (optional, auto-detected)
- Network interface with Wake-on-LAN support (optional)

## Troubleshooting

### Check Status
```bash
./setup --status
```

### View Logs
```bash
tail -f /var/log/ubivision-server-setup/deployment.log
journalctl -u ubivision-server-setup-resume -f
```

### Reset and Retry
```bash
./setup --reset
./setup
```

### Manual Module Execution
```bash
# Run individual module
./modules/20-nvidia
```

## Security Features

- SSH hardening with key-based authentication
- Firewall configuration (UFW)
- Automatic security updates disabled for stability
- Secure Boot compatibility warnings
- GitHub SSH key automation with token-based API

## Testing

The system includes comprehensive testing:
- Module-level validation
- Integration testing
- GPU functionality verification
- Network connectivity testing
- Service health checks

## Development

### Adding New Modules
1. Create module file in `modules/` directory
2. Follow naming convention: `NN-name`
3. Update state management in `lib/state.sh`
4. Add validation in `50-validate` module

### Customization
- Modify `config/defaults.env` for configuration
- Extend `lib/utils.sh` for shared functionality
- Update `modules/` for feature additions

## License

This project is licensed under the MIT License.

## Support

For issues and feature requests, please visit:
https://github.com/ubihere/ubivision-server-setup/issues

## Changelog

### v1.0.0
- Initial release with full modular architecture
- Automatic reboot handling
- Comprehensive state management
- Network failure recovery
- Complete NVIDIA GPU support
- Docker with GPU integration
- Tailscale VPN setup
- Full validation suite