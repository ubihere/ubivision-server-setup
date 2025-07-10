# UbiVision Server Setup

Automated Ubuntu 22.04 server deployment system with NVIDIA GPU support, Docker, and network configuration.

## Installation

### Remote Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ubihere/ubivision-server-setup/master/install.sh | bash
```

### Local Installation

```bash
git clone https://github.com/ubihere/ubivision-server-setup.git
cd ubivision-server-setup
./setup
```

## Usage

```bash
# Start deployment
ubivision-server-setup

# Resume after reboot
ubivision-server-setup --resume

# Check status
ubivision-server-setup --status

# Reset state
ubivision-server-setup --reset

# Show help
ubivision-server-setup --help
```

## What It Installs

### System Configuration
- Hostname and timezone setup
- Storage expansion and swap configuration
- Time synchronization (chrony)
- Essential packages and security limits
- SSH hardening

### NVIDIA Support (if GPU detected)
- Automatic driver detection and installation
- CUDA toolkit installation
- cuDNN installation
- Automatic reboot handling

### Docker
- Docker Engine with GPU support
- NVIDIA Container Toolkit
- Docker Compose
- User permissions configuration

### Network & Security
- Tailscale VPN
- GitHub SSH key automation
- Wake-on-LAN configuration
- System watchdog
- UFW firewall configuration

### Validation
- Service health checks
- GPU functionality testing
- Docker GPU verification
- Network connectivity testing
- Security validation

## Configuration

Edit `config/defaults.env` before installation:

```bash
# System
TIMEZONE="America/New_York"
SWAP_SIZE="2G"

# NVIDIA
NVIDIA_DRIVER_AUTO_DETECT=true
CUDA_VERSION="12.6.0"

# Network
TAILSCALE_AUTO_CONNECT=true
SSH_PORT=22

# Security
DISABLE_AUTOMATIC_UPDATES=true
ENABLE_WATCHDOG=true
ENABLE_WAKE_ON_LAN=true
```

## Requirements

- Ubuntu 22.04 LTS
- 4GB+ RAM
- 50GB+ disk space
- Internet connectivity
- Sudo privileges
- NVIDIA GPU (optional)

## State Management

The system tracks deployment progress in `/var/lib/ubivision-server-setup/state.json` and automatically resumes after reboots or failures.

## Logging

Logs are written to:
- `/var/log/ubivision-server-setup/deployment.log`
- System journal: `journalctl -u ubivision-server-setup-resume`

## Troubleshooting

### View Status
```bash
ubivision-server-setup --status
```

### View Logs
```bash
tail -f /var/log/ubivision-server-setup/deployment.log
```

### Reset and Retry
```bash
ubivision-server-setup --reset
ubivision-server-setup
```

### Manual Module Execution
```bash
./modules/20-nvidia  # Run specific module
```

## Architecture

The system uses 6 modular components:

1. **00-verify** - System requirements check
2. **10-system** - Core system configuration
3. **20-nvidia** - GPU drivers and CUDA
4. **30-docker** - Container runtime
5. **40-network** - Network and security setup
6. **50-validate** - Final validation

Each module can run independently and includes automatic retry mechanisms.

## License

MIT License