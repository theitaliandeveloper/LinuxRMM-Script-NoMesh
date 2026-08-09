#!/bin/bash
# Tactical RMM Agent Unofficial installer
# Original version by ZoLuSs
# Copyright (c) 2022 ZoLuSs (MIT License)
# Modified by The Italian Developer to remove Mesh Agent (unneeded for command line servers)

set -euo pipefail

# === Log Helpers ===
function log_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}
function log_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}
function log_warn() {
    echo -e "\e[33m[WARNING]\e[0m $1"
}
function log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

# === Root Privilege Check ===
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root. Please run with sudo or as the root user."
    exit 1
fi

# === Dependency Check ===
for cmd in wget tar systemctl; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required dependency '$cmd' is not installed."
        exit 1
    fi
done

# === Temporary directory check ===
CLEANUP_FILES=()
CLEANUP_DIRS=()

if [[ -w /tmp ]]; then
    TMPDIR="/tmp"
else
    TMPDIR="$(pwd)/tmp_local"
    if [[ ! -d "$TMPDIR" ]]; then
        mkdir -p "$TMPDIR"
        CLEANUP_DIRS+=("$TMPDIR")
    fi
    if [[ ! -w "$TMPDIR" ]]; then
        log_error "No write permission in /tmp or current directory."
        exit 1
    fi
fi
log_info "Using temporary directory: $TMPDIR"

# === Cleanup Handler ===
function cleanup() {
    log_info "Cleaning up temporary files..."
    for file in "${CLEANUP_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
        fi
    done
    for dir in "${CLEANUP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir"
        fi
    done
}
trap cleanup EXIT

# === Argument Help / Checks ===
if [[ $# -eq 0 ]]; then
    log_error "First argument is empty!"
    echo "Type help for more information"
    exit 1
fi

if [[ "$1" == "help" ]]; then
    echo "More information is available at https://github.com/theitaliandeveloper/LinuxRMM-Script-NoMesh"
    echo ""
    echo "INSTALL arguments:"
    echo "Arg 1: 'install'"
    echo "Arg 2: API URL"
    echo "Arg 3: Client ID"
    echo "Arg 4: Site ID"
    echo "Arg 5: Auth Key"
    echo "Arg 6: Agent Type 'server' or 'workstation'"
    echo ""
    echo "UPDATE arguments:"
    echo "Arg 1: 'update'"
    echo ""
    echo "UNINSTALL arguments:"
    echo "Arg 1: 'uninstall'"
    echo ""
    exit 0
fi

if [[ "$1" != "install" && "$1" != "update" && "$1" != "uninstall" ]]; then
    log_error "First argument can only be 'install', 'update' or 'uninstall'!"
    echo "Type help for more information"
    exit 1
fi

## Detect system architecture
system=$(uname -m)
case "$system" in
    x86_64) system="amd64" ;;
    i386|i686) system="x86" ;;
    aarch64) system="arm64" ;;
    armv6l) system="armv6" ;;
    *) log_error "Unsupported architecture: $system"; exit 1 ;;
esac

## Variables
rmm_url="${2:-}"
rmm_client_id="${3:-}"
rmm_site_id="${4:-}"
rmm_auth="${5:-}"
rmm_agent_type="${6:-}"

# Argument validation for installation
if [[ "$1" == "install" ]]; then
    if [[ -z "$rmm_url" || -z "$rmm_client_id" || -z "$rmm_site_id" || -z "$rmm_auth" || -z "$rmm_agent_type" ]]; then
        log_error "Missing required arguments for 'install' mode!"
        echo "Usage: $0 install <API_URL> <CLIENT_ID> <SITE_ID> <AUTH_KEY> <AGENT_TYPE>"
        exit 1
    fi
    if [[ "$rmm_agent_type" != "server" && "$rmm_agent_type" != "workstation" ]]; then
        log_error "Agent Type must be 'server' or 'workstation', got '$rmm_agent_type'"
        exit 1
    fi
fi

go_version="1.21.6"
go_url_amd64="https://go.dev/dl/go$go_version.linux-amd64.tar.gz"
go_url_x86="https://go.dev/dl/go$go_version.linux-386.tar.gz"
go_url_arm64="https://go.dev/dl/go$go_version.linux-arm64.tar.gz"
go_url_armv6="https://go.dev/dl/go$go_version.linux-armv6l.tar.gz"

function go_install() {
    # Add standard go path if it exists and is not already in PATH
    if [[ -d "/usr/local/go/bin" ]] && [[ ":$PATH:" != *":/usr/local/go/bin:"* ]]; then
        export PATH="$PATH:/usr/local/go/bin"
    fi
    
    if ! command -v go &> /dev/null; then
        log_info "Go not found. Installing Go $go_version..."
        local go_tar="$TMPDIR/golang.tar.gz"
        CLEANUP_FILES+=("$go_tar")
        
        case "$system" in
            amd64) wget -q --show-progress -O "$go_tar" "$go_url_amd64" ;;
            x86) wget -q --show-progress -O "$go_tar" "$go_url_x86" ;;
            arm64) wget -q --show-progress -O "$go_tar" "$go_url_arm64" ;;
            armv6) wget -q --show-progress -O "$go_tar" "$go_url_armv6" ;;
        esac
        
        log_info "Extracting Go..."
        rm -rf /usr/local/go/
        tar -xzf "$go_tar" -C /usr/local/
        rm -f "$go_tar"
        export PATH="$PATH:/usr/local/go/bin"
        log_success "Go installed successfully."
    else
        log_info "Go is already installed: $(go version)"
    fi
}

function agent_compile() {
    log_info "Compiling agent..."
    local agent_tar="$TMPDIR/rmmagent.tar.gz"
    CLEANUP_FILES+=("$agent_tar")
    
    wget -q --show-progress -O "$agent_tar" "https://github.com/amidaware/rmmagent/archive/refs/heads/master.tar.gz"
    
    local compile_dir="$TMPDIR/rmmagent-compile"
    mkdir -p "$compile_dir"
    CLEANUP_DIRS+=("$compile_dir")
    
    tar -xzf "$agent_tar" -C "$compile_dir"
    rm -f "$agent_tar"
    
    local src_dir
    src_dir=$(find "$compile_dir" -maxdepth 2 -type d -name "rmmagent-*" | head -n 1)
    if [[ -z "$src_dir" || ! -d "$src_dir" ]]; then
        log_error "Could not find extracted agent directory."
        exit 1
    fi
    
    (
        cd "$src_dir"
        case "$system" in
            amd64) env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o "$TMPDIR/temp_rmmagent" ;;
            x86) env CGO_ENABLED=0 GOOS=linux GOARCH=386 go build -ldflags "-s -w" -o "$TMPDIR/temp_rmmagent" ;;
            arm64) env CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags "-s -w" -o "$TMPDIR/temp_rmmagent" ;;
            armv6) env CGO_ENABLED=0 GOOS=linux GOARCH=arm go build -ldflags "-s -w" -o "$TMPDIR/temp_rmmagent" ;;
        esac
    )
    CLEANUP_FILES+=("$TMPDIR/temp_rmmagent")
    log_success "Agent compiled successfully."
}

function update_agent() {
    log_info "Stopping tacticalagent service..."
    systemctl stop tacticalagent || true
    
    log_info "Updating agent binary..."
    cp "$TMPDIR/temp_rmmagent" /usr/local/bin/rmmagent
    chmod +x /usr/local/bin/rmmagent
    
    log_info "Starting tacticalagent service..."
    systemctl start tacticalagent
    log_success "Agent updated successfully."
}

function install_agent() {
    log_info "Installing agent binary..."
    cp "$TMPDIR/temp_rmmagent" /usr/local/bin/rmmagent
    chmod +x /usr/local/bin/rmmagent
    
    log_info "Running agent registration..."
    /usr/local/bin/rmmagent -m install -api "$rmm_url" -client-id "$rmm_client_id" -site-id "$rmm_site_id" -agent-type "$rmm_agent_type" -auth "$rmm_auth" -nomesh
    
    log_info "Writing systemd service file..."
    cat << "EOF" > /etc/systemd/system/tacticalagent.service
[Unit]
Description=Tactical RMM Agent
[Service]
Type=simple
ExecStart=/usr/local/bin/rmmagent -m svc
User=root
Group=root
Restart=always
RestartSec=5s
LimitNOFILE=1000000
KillMode=process
[Install]
WantedBy=multi-user.target
EOF
    
    log_info "Starting tacticalagent service..."
    systemctl daemon-reload
    systemctl enable --now tacticalagent
    systemctl start tacticalagent
    log_success "Agent installation completed."
}

function uninstall_agent() {
    log_info "Stopping and disabling tacticalagent service..."
    systemctl stop tacticalagent || true
    systemctl disable tacticalagent || true
    if [[ -f /etc/systemd/system/tacticalagent.service ]]; then
        rm -f /etc/systemd/system/tacticalagent.service
    fi
    systemctl daemon-reload
    
    log_info "Removing agent binary and configuration..."
    rm -f /usr/local/bin/rmmagent
    rm -rf /etc/tacticalagent
    log_success "Agent uninstalled successfully."
}

case "$1" in
    install)
        go_install
        agent_compile
        install_agent
        exit 0
        ;;
    update)
        go_install
        agent_compile
        update_agent
        exit 0
        ;;
    uninstall)
        uninstall_agent
        exit 0
        ;;
esac
