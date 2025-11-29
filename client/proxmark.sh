#!/usr/bin/env bash
#
# Proxmark - Proxmox VE Benchmark Suite
# https://github.com/giovannirco/proxmark
#
# A fast, one-line benchmarking tool for Proxmox VE nodes.
# Run from the Proxmox shell: curl -sL https://proxmark.io/run | bash
#
# Copyright (c) 2024 Giovanni Rco
# Licensed under MIT License
#

set -euo pipefail

# === Version ===
VERSION="1.0.3"

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# === Default Configuration ===
CPU_TIME=${PROXMARK_CPU_TIME:-60}
CPU_SINGLE_TIME=${PROXMARK_CPU_SINGLE_TIME:-30}
MEM_TIME=${PROXMARK_MEM_TIME:-30}
DISK_RUNTIME=${PROXMARK_DISK_RUNTIME:-60}
DISK_SIZE=${PROXMARK_DISK_SIZE:-1G}
DISK_PATH="${PROXMARK_DISK_PATH:-/tmp}"
API_URL="${PROXMARK_API_URL:-https://proxmark.io/api/v1}"
RESULT_DIR="${PROXMARK_RESULT_DIR:-/tmp}"

# === Flags (defaults) ===
QUICK_MODE=false
NO_COLOR=false
NO_UPLOAD=false
FORCE_UPLOAD=false
VERBOSE=false
DEBUG=false
QUIET=false
JSON_ONLY=false
NO_INSTALL=false
HELP=false
SHOW_VERSION=false
TAGS=""
NOTES=""
CUSTOM_OUTPUT=""

# === Derived variables ===
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
RESULT_JSON="${RESULT_DIR}/proxmark-result-${TIMESTAMP}.json"
RUN_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "unknown-$(date +%s)")

# === Helper Functions ===

print_banner() {
  if [[ "$QUIET" == "true" ]] || [[ "$JSON_ONLY" == "true" ]]; then
    return
  fi
  
  echo -e "${CYAN}"
  cat << EOF
╭─────────────────────────────────────────────────────────────────────────────╮
│                                                                             │
│  ██████╗ ██████╗  ██████╗ ██╗  ██╗███╗   ███╗ █████╗ ██████╗ ██╗  ██╗      │
│  ██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝████╗ ████║██╔══██╗██╔══██╗██║ ██╔╝      │
│  ██████╔╝██████╔╝██║   ██║ ╚███╔╝ ██╔████╔██║███████║██████╔╝█████╔╝       │
│  ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗ ██║╚██╔╝██║██╔══██║██╔══██╗██╔═██╗       │
│  ██║     ██║  ██║╚██████╔╝██╔╝ ██╗██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██╗      │
│  ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝      │
│                                                                             │
│                    Proxmox VE Benchmark Suite v${VERSION}                       │
╰─────────────────────────────────────────────────────────────────────────────╯
EOF
  echo -e "${NC}"
}

usage() {
  cat << EOF
${BOLD}Proxmark${NC} - Proxmox VE Benchmark Suite v${VERSION}

${BOLD}USAGE:${NC}
    curl -sL https://proxmark.io/run | bash   # From Proxmox shell
    bash proxmark.sh [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -V, --version       Show version number
    -q, --quiet         Minimal output
    -v, --verbose       Verbose output
    --debug             Debug mode (shows all commands and system info)
    --json              Output JSON only (for scripting)
    --quick             Run quick benchmarks (~2 min instead of ~10 min)
    --no-color          Disable colored output
    --no-upload         Don't upload results to server
    --upload            Force upload results (default: ask)
    --no-install        Don't auto-install missing dependencies

${BOLD}CONFIGURATION:${NC}
    --disk-path PATH    Directory to use for disk benchmarks (default: /tmp)
    --output FILE       Custom output path for JSON results
    --tag TAG           Add a tag to results (can be used multiple times)
    --notes "TEXT"      Add notes to the benchmark result

${BOLD}ENVIRONMENT VARIABLES:${NC}
    PROXMARK_DISK_PATH   Same as --disk-path
    PROXMARK_CPU_TIME    CPU benchmark duration (default: 60)
    PROXMARK_MEM_TIME    Memory benchmark duration (default: 30)
    PROXMARK_DISK_RUNTIME Disk benchmark duration (default: 60)
    PROXMARK_API_URL     API server URL

${BOLD}EXAMPLES:${NC}
    # Benchmark your VM storage
    bash proxmark.sh --disk-path /var/lib/vz

    # Quick benchmark (~2 min)
    bash proxmark.sh --quick

    # Tag your Proxmox node
    bash proxmark.sh --tag "production" --tag "nvme" --notes "New node"

    # JSON output only
    bash proxmark.sh --json --no-upload

${BOLD}MORE INFO:${NC}
    https://github.com/giovannirco/proxmark
    https://proxmark.io

EOF
}

log() {
  if [[ "$QUIET" == "true" ]] || [[ "$JSON_ONLY" == "true" ]]; then
    return
  fi
  echo -e "${BLUE}[proxmark]${NC} $*" >&2
}

log_success() {
  if [[ "$QUIET" == "true" ]] || [[ "$JSON_ONLY" == "true" ]]; then
    return
  fi
  echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
  if [[ "$JSON_ONLY" == "true" ]]; then
    return
  fi
  echo -e "${YELLOW}[!]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_verbose() {
  if [[ "$VERBOSE" == "true" ]] || [[ "$DEBUG" == "true" ]]; then
    echo -e "${DIM}[verbose]${NC} $*" >&2
  fi
}

log_debug() {
  if [[ "$DEBUG" == "true" ]]; then
    echo -e "${DIM}[debug]${NC} $*" >&2
  fi
}

debug_system_info() {
  if [[ "$DEBUG" != "true" ]]; then
    return
  fi
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━ DEBUG INFO ━━━━━━━━━━━━━━━━━━━━${NC}" >&2
  echo -e "${DIM}Shell:${NC} $SHELL (BASH_VERSION: $BASH_VERSION)" >&2
  echo -e "${DIM}User:${NC} $(whoami) (EUID: $EUID)" >&2
  echo -e "${DIM}PWD:${NC} $(pwd)" >&2
  echo -e "${DIM}PATH:${NC} $PATH" >&2
  echo -e "${DIM}OS Release:${NC}" >&2
  cat /etc/os-release 2>/dev/null | head -5 | sed 's/^/  /' >&2
  echo -e "${DIM}Kernel:${NC} $(uname -a)" >&2
  echo -e "${DIM}Disk Path:${NC} $DISK_PATH" >&2
  echo -e "${DIM}Available space:${NC} $(df -h "$DISK_PATH" 2>/dev/null | tail -1)" >&2
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
}

progress_bar() {
  local current=$1
  local total=$2
  local width=40
  local percent=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))
  
  if [[ "$QUIET" == "true" ]] || [[ "$JSON_ONLY" == "true" ]]; then
    return
  fi
  
  printf "\r  ${GREEN}"
  printf "█%.0s" $(seq 1 $filled)
  printf "${DIM}"
  printf "░%.0s" $(seq 1 $empty)
  printf "${NC} %3d%% [%ds]" "$percent" "$current"
}

spinner() {
  local pid=$1
  local message=$2
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  
  if [[ "$QUIET" == "true" ]] || [[ "$JSON_ONLY" == "true" ]]; then
    wait "$pid"
    return
  fi
  
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}%s${NC} %s" "${spin:i++%${#spin}:1}" "$message"
    sleep 0.1
  done
  printf "\r"
}

cleanup() {
  local exit_code=$?
  log_verbose "Cleaning up..."
  
  # Remove any leftover test files
  rm -f "${DISK_PATH}/proxmark-fio-testfile" 2>/dev/null || true
  
  if [[ $exit_code -ne 0 ]]; then
    log_error "Benchmark interrupted or failed (exit code: $exit_code)"
  fi
  
  exit $exit_code
}

trap cleanup EXIT INT TERM

# === Argument Parsing ===

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        HELP=true
        shift
        ;;
      -V|--version)
        SHOW_VERSION=true
        shift
        ;;
      -q|--quiet)
        QUIET=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --debug)
        DEBUG=true
        VERBOSE=true
        set -x
        shift
        ;;
      --json)
        JSON_ONLY=true
        shift
        ;;
      --quick)
        QUICK_MODE=true
        shift
        ;;
      --no-color)
        NO_COLOR=true
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        CYAN=''
        BOLD=''
        DIM=''
        NC=''
        shift
        ;;
      --no-upload)
        NO_UPLOAD=true
        shift
        ;;
      --upload)
        FORCE_UPLOAD=true
        shift
        ;;
      --no-install)
        NO_INSTALL=true
        shift
        ;;
      --disk-path)
        DISK_PATH="$2"
        shift 2
        ;;
      --output)
        CUSTOM_OUTPUT="$2"
        shift 2
        ;;
      --tag)
        if [[ -n "$TAGS" ]]; then
          TAGS="${TAGS},$2"
        else
          TAGS="$2"
        fi
        shift 2
        ;;
      --notes)
        NOTES="$2"
        shift 2
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
  
  # Apply custom output path if specified
  if [[ -n "$CUSTOM_OUTPUT" ]]; then
    RESULT_JSON="$CUSTOM_OUTPUT"
  fi
  
  # Apply quick mode settings
  if [[ "$QUICK_MODE" == "true" ]]; then
    CPU_TIME=20
    CPU_SINGLE_TIME=10
    MEM_TIME=10
    DISK_RUNTIME=20
  fi
}

# === Dependency Management ===

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_PRETTY="${PRETTY_NAME:-$ID}"
  else
    OS_ID="unknown"
    OS_ID_LIKE=""
    OS_PRETTY="Unknown Linux"
  fi
  
  # Detect package manager
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
  else
    PKG_MANAGER="unknown"
  fi
  
  log_verbose "Detected OS: $OS_PRETTY (ID: $OS_ID, pkg manager: $PKG_MANAGER)"
}

run_as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

require_cmd_or_install() {
  local cmd="$1"
  local pkg="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    log_verbose "Found $cmd"
    return 0
  fi
  
  if [[ "$NO_INSTALL" == "true" ]]; then
    log_error "Missing required command: $cmd (package: $pkg)"
    log_error "Run with auto-install or install manually: $pkg"
    exit 1
  fi

  log "Installing $pkg..."
  log_debug "Package manager: $PKG_MANAGER"
  log_debug "Command to install: $cmd from package $pkg"
  
  case "$PKG_MANAGER" in
    apt)
      log_debug "Running: apt-get update"
      # Don't fail on apt-get update errors (e.g., Proxmox enterprise repos without subscription)
      run_as_root apt-get update 2>&1 | grep -v "^Hit:\|^Get:\|^Reading" | head -5 || true
      log_debug "Running: apt-get install -y $pkg"
      if ! run_as_root apt-get install -y "$pkg" 2>&1 | grep -v "^Reading\|^Building\|^Processing\|^Selecting\|^Preparing\|^Unpacking\|^Setting"; then
        log_error "Failed to install $pkg"
        log_error "Try running: apt-get update && apt-get install -y $pkg"
        exit 1
      fi
      ;;
    dnf)
      run_as_root dnf install -y -q "$pkg" || { log_error "Failed to install $pkg"; exit 1; }
      ;;
    yum)
      run_as_root yum install -y -q "$pkg" || { log_error "Failed to install $pkg"; exit 1; }
      ;;
    pacman)
      run_as_root pacman -S --noconfirm "$pkg" || { log_error "Failed to install $pkg"; exit 1; }
      ;;
    *)
      log_error "Package manager not supported. Please install $pkg manually."
      exit 1
      ;;
  esac
  
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Failed to install $pkg - command '$cmd' still not found"
    exit 1
  fi
  
  log_success "Installed $pkg"
}

check_proxmox() {
  IS_PROXMOX=false
  
  # Check for Proxmox indicators
  if [[ -d /etc/pve ]] || command -v pveversion >/dev/null 2>&1; then
    IS_PROXMOX=true
    log_verbose "Proxmox VE detected"
  else
    log_warning "Proxmox VE not detected - this tool is designed for Proxmox hosts"
    log_warning "Results may not be accurate on non-Proxmox systems"
  fi
  
  # Auto-detect best disk path for Proxmox
  if [[ "$DISK_PATH" == "/tmp" ]] && [[ "$IS_PROXMOX" == "true" ]]; then
    if [[ -d /var/lib/vz ]]; then
      # Check if /var/lib/vz is a real storage (not just tmpfs)
      local vz_fs=$(df /var/lib/vz 2>/dev/null | awk 'NR==2 {print $1}')
      if [[ "$vz_fs" != "tmpfs" ]] && [[ -n "$vz_fs" ]]; then
        DISK_PATH="/var/lib/vz"
        log_verbose "Auto-detected Proxmox storage: $DISK_PATH"
      fi
    fi
  fi
}

check_dependencies() {
  log "Checking dependencies..."
  
  detect_os
  check_proxmox
  
  require_cmd_or_install sysbench sysbench
  require_cmd_or_install fio fio
  require_cmd_or_install jq jq
  
  # Check for libaio (needed for fio with libaio engine)
  if [[ "$PKG_MANAGER" == "apt" ]] && ! dpkg -l 2>/dev/null | grep -q libaio; then
    log_verbose "Installing libaio-dev for fio..."
    run_as_root apt-get install -y libaio-dev >/dev/null 2>&1 || true
  fi
  
  log_success "All dependencies satisfied"
}

# === System Information ===

collect_sysinfo() {
  log "Collecting system information..."
  
  HOSTNAME="$(hostname)"
  
  # CPU info
  CPU_MODEL="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//' || echo 'Unknown')"
  CPU_CORES="$(nproc --all)"
  CPU_THREADS="$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "$CPU_CORES")"
  CPU_SOCKETS="$(grep 'physical id' /proc/cpuinfo | sort -u | wc -l)"
  [[ "$CPU_SOCKETS" -eq 0 ]] && CPU_SOCKETS=1
  
  # CPU frequency detection
  CPU_FREQ_MHZ=""
  if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]]; then
    local freq_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0)
    CPU_FREQ_MHZ=$((freq_khz / 1000))
  elif grep -q "cpu MHz" /proc/cpuinfo; then
    CPU_FREQ_MHZ=$(grep -m1 "cpu MHz" /proc/cpuinfo | awk '{printf "%.0f", $4}')
  fi
  
  # Memory info
  MEM_TOTAL_KB="$(grep MemTotal /proc/meminfo | awk '{print $2}')"
  MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))
  MEM_TOTAL_GB=$((MEM_TOTAL_MB / 1024))
  
  # Try to detect memory type and speed (best effort)
  MEM_TYPE="unknown"
  MEM_SPEED=""
  if command -v dmidecode >/dev/null 2>&1; then
    MEM_TYPE=$(run_as_root dmidecode -t memory 2>/dev/null | grep -m1 "Type:" | grep -v "Error" | awk '{print $2}' || echo "unknown")
    MEM_SPEED=$(run_as_root dmidecode -t memory 2>/dev/null | grep -m1 "Speed:" | grep -v "Unknown" | awk '{print $2, $3}' || echo "")
  fi
  
  # Kernel and OS
  KERNEL="$(uname -r)"
  OS="$(grep -m1 '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || uname -s)"
  
  # Virtualization detection
  VIRT_TYPE="bare-metal"
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT_TYPE=$(systemd-detect-virt 2>/dev/null || echo "bare-metal")
  fi
  
  # Proxmox detection - use pveversion command (preferred)
  PROXMOX_VERSION=""
  if command -v pveversion >/dev/null 2>&1; then
    PROXMOX_VERSION=$(pveversion 2>/dev/null | head -1 || echo "")
  fi
  
  # Disk info
  ROOT_DEV="$(df "$DISK_PATH" 2>/dev/null | awk 'NR==2{print $1}')"
  DISK_MODEL=""
  DISK_TYPE="unknown"
  DISK_SIZE_GB=0
  
  if [[ "$ROOT_DEV" == /dev/* ]]; then
    # Strip partition number (handles nvme0n1p1 and sda1 formats)
    if [[ "$ROOT_DEV" =~ nvme ]]; then
      BASE_DEV="$(echo "$ROOT_DEV" | sed 's/p[0-9]*$//')"
      DISK_TYPE="nvme"
    else
      BASE_DEV="$(echo "$ROOT_DEV" | sed 's/[0-9]*$//')"
    fi
    
    DEV_NAME=$(basename "$BASE_DEV")
    
    # Get disk model
    if [[ -e "/sys/block/${DEV_NAME}/device/model" ]]; then
      DISK_MODEL="$(cat "/sys/block/${DEV_NAME}/device/model" 2>/dev/null | tr -d ' \t\n' || echo "")"
    fi
    
    # Get disk size
    if [[ -e "/sys/block/${DEV_NAME}/size" ]]; then
      local sectors=$(cat "/sys/block/${DEV_NAME}/size" 2>/dev/null || echo 0)
      DISK_SIZE_GB=$((sectors * 512 / 1024 / 1024 / 1024))
    fi
    
    # Detect disk type if not already known
    if [[ "$DISK_TYPE" == "unknown" ]]; then
      if [[ -e "/sys/block/${DEV_NAME}/queue/rotational" ]]; then
        local rotational=$(cat "/sys/block/${DEV_NAME}/queue/rotational" 2>/dev/null || echo 1)
        if [[ "$rotational" == "0" ]]; then
          DISK_TYPE="ssd"
        else
          DISK_TYPE="hdd"
        fi
      fi
    fi
  fi
  
  # Build JSON
  SYSINFO_JSON=$(jq -n \
    --arg host "$HOSTNAME" \
    --arg cpu_model "$CPU_MODEL" \
    --argjson cpu_cores "$CPU_CORES" \
    --argjson cpu_threads "$CPU_THREADS" \
    --argjson cpu_sockets "$CPU_SOCKETS" \
    --arg cpu_freq_mhz "${CPU_FREQ_MHZ:-}" \
    --argjson mem_mb "$MEM_TOTAL_MB" \
    --arg mem_type "$MEM_TYPE" \
    --arg mem_speed "${MEM_SPEED:-}" \
    --arg kernel "$KERNEL" \
    --arg os "$OS" \
    --arg virt "$VIRT_TYPE" \
    --argjson is_proxmox "$([[ "${IS_PROXMOX:-false}" == "true" ]] && echo "true" || echo "false")" \
    --arg pve_version "$PROXMOX_VERSION" \
    --arg root_dev "$ROOT_DEV" \
    --arg disk_model "$DISK_MODEL" \
    --arg disk_type "$DISK_TYPE" \
    --argjson disk_size_gb "$DISK_SIZE_GB" \
    --arg disk_path "$DISK_PATH" \
    '{
      hostname: $host,
      cpu_model: $cpu_model,
      cpu_cores: $cpu_cores,
      cpu_threads: $cpu_threads,
      cpu_sockets: $cpu_sockets,
      cpu_freq_mhz: $cpu_freq_mhz,
      mem_total_mb: $mem_mb,
      mem_type: $mem_type,
      mem_speed: $mem_speed,
      kernel: $kernel,
      os: $os,
      virtualization: $virt,
      is_proxmox: $is_proxmox,
      proxmox_version: $pve_version,
      root_device: $root_dev,
      disk_model: $disk_model,
      disk_type: $disk_type,
      disk_size_gb: $disk_size_gb,
      disk_path: $disk_path
    }')
  
  log_success "System info collected"
  log_verbose "Host: $HOSTNAME, CPU: $CPU_MODEL ($CPU_CORES cores), RAM: ${MEM_TOTAL_GB}GB, Disk: $DISK_MODEL ($DISK_TYPE)"
}

# === Benchmarks ===

run_cpu_benchmark() {
  log "Running CPU benchmark (multi-threaded, ${CPU_TIME}s)..."
  
  local threads="$CPU_CORES"
  local out
  
  out="$(sysbench cpu --cpu-max-prime=20000 --threads="$threads" --time="$CPU_TIME" run 2>&1)"
  
  CPU_MULTI_EPS="$(echo "$out" | awk '/events per second/ {print $4}' || echo "0")"
  CPU_MULTI_TOTAL_TIME="$(echo "$out" | awk '/total time:/ {gsub(/s/,""); print $3}' || echo "0")"
  CPU_MULTI_TOTAL_EVENTS="$(echo "$out" | awk '/total number of events:/ {print $5}' || echo "0")"
  CPU_MULTI_LATENCY_AVG="$(echo "$out" | awk '/avg:/ {print $2}' || echo "0")"
  CPU_MULTI_LATENCY_P95="$(echo "$out" | awk '/95th percentile:/ {print $3}' || echo "0")"
  
  log_success "CPU multi-thread: ${CPU_MULTI_EPS} events/sec"
  
  # Single-threaded test
  log "Running CPU benchmark (single-threaded, ${CPU_SINGLE_TIME}s)..."
  
  out="$(sysbench cpu --cpu-max-prime=20000 --threads=1 --time="$CPU_SINGLE_TIME" run 2>&1)"
  
  CPU_SINGLE_EPS="$(echo "$out" | awk '/events per second/ {print $4}' || echo "0")"
  CPU_SINGLE_LATENCY_AVG="$(echo "$out" | awk '/avg:/ {print $2}' || echo "0")"
  
  log_success "CPU single-thread: ${CPU_SINGLE_EPS} events/sec"
}

run_mem_benchmark() {
  log "Running Memory benchmark (write, ${MEM_TIME}s)..."
  
  local threads="$CPU_CORES"
  local out
  
  out="$(sysbench memory \
    --memory-block-size=1K \
    --memory-total-size=1000G \
    --memory-oper=write \
    --time="$MEM_TIME" \
    --threads="$threads" run 2>&1)"
  
  MEM_WRITE_MBS="$(echo "$out" | awk '/transferred/ {gsub(/[()]/,""); print $(NF-1)}' || echo "0")"
  MEM_WRITE_OPS="$(echo "$out" | awk '/Total operations:/ {print $3}' || echo "0")"
  
  log_success "Memory write: ${MEM_WRITE_MBS} MB/s"
  
  # Read test
  log "Running Memory benchmark (read, ${MEM_TIME}s)..."
  
  out="$(sysbench memory \
    --memory-block-size=1K \
    --memory-total-size=1000G \
    --memory-oper=read \
    --time="$MEM_TIME" \
    --threads="$threads" run 2>&1)"
  
  MEM_READ_MBS="$(echo "$out" | awk '/transferred/ {gsub(/[()]/,""); print $(NF-1)}' || echo "0")"
  MEM_READ_OPS="$(echo "$out" | awk '/Total operations:/ {print $3}' || echo "0")"
  
  log_success "Memory read: ${MEM_READ_MBS} MB/s"
}

run_disk_benchmark() {
  log "Running Disk benchmark (random r/w, ${DISK_RUNTIME}s)..."
  
  mkdir -p "$DISK_PATH"
  local filename="${DISK_PATH}/proxmark-fio-testfile"
  
  # Check if benchmarking tmpfs (RAM disk) - warn user
  local disk_fs=$(df "$DISK_PATH" 2>/dev/null | awk 'NR==2 {print $1}')
  local is_tmpfs=false
  if [[ "$disk_fs" == "tmpfs" ]]; then
    is_tmpfs=true
    log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_warning "Disk path '$DISK_PATH' is tmpfs (RAM disk)"
    log_warning "Disk results will measure RAM speed, not actual storage!"
    log_warning "For accurate results, use: --disk-path /var/lib/vz"
    log_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi
  
  # Check disk space
  local available_kb=$(df "$DISK_PATH" | awk 'NR==2 {print $4}')
  local required_kb=2097152  # 2GB
  if [[ $available_kb -lt $required_kb ]]; then
    log_warning "Low disk space. Using smaller test file."
    DISK_SIZE="256M"
  fi
  
  # Determine I/O engine - use sync for tmpfs (libaio may not work)
  local ioengine="libaio"
  if [[ "$is_tmpfs" == "true" ]]; then
    ioengine="sync"
    log_verbose "Using sync engine for tmpfs"
  elif ! modprobe -n libaio 2>/dev/null && [[ ! -e /lib/modules/$(uname -r)/kernel/fs/aio.ko ]]; then
    ioengine="sync"
    log_verbose "libaio not available, falling back to sync engine"
  fi
  
  # Random read/write test
  local out
  local fio_err=""
  
  # Set iodepth based on engine (sync doesn't support high iodepth)
  local iodepth=32
  if [[ "$ioengine" == "sync" ]]; then
    iodepth=1
  fi
  
  log_debug "Running fio with engine=$ioengine, iodepth=$iodepth, file=$filename"
  
  out="$(fio --name=proxmark-randrw \
    --filename="$filename" \
    --rw=randrw \
    --bs=4k \
    --iodepth="$iodepth" \
    --size="$DISK_SIZE" \
    --time_based \
    --runtime="$DISK_RUNTIME" \
    --group_reporting \
    --ioengine="$ioengine" \
    --output-format=json 2>&1)" || fio_err="$?"
  
  log_debug "fio exit code: ${fio_err:-0}"
  
  # Parse JSON output if available
  if echo "$out" | jq -e '.jobs[0]' >/dev/null 2>&1; then
    DISK_RANDRW_IOPS_R=$(echo "$out" | jq -r '.jobs[0].read.iops // 0' | cut -d. -f1)
    DISK_RANDRW_IOPS_W=$(echo "$out" | jq -r '.jobs[0].write.iops // 0' | cut -d. -f1)
    DISK_RANDRW_IOPS_TOTAL=$((DISK_RANDRW_IOPS_R + DISK_RANDRW_IOPS_W))
    DISK_RANDRW_BW_R=$(echo "$out" | jq -r '.jobs[0].read.bw_bytes // 0')
    DISK_RANDRW_BW_W=$(echo "$out" | jq -r '.jobs[0].write.bw_bytes // 0')
    DISK_RANDRW_BW_R_MB=$(awk "BEGIN {printf \"%.2f\", $DISK_RANDRW_BW_R/1024/1024}")
    DISK_RANDRW_BW_W_MB=$(awk "BEGIN {printf \"%.2f\", $DISK_RANDRW_BW_W/1024/1024}")
    DISK_RANDRW_LAT_AVG=$(echo "$out" | jq -r '.jobs[0].read.lat_ns.mean // 0')
    DISK_RANDRW_LAT_AVG_US=$(awk "BEGIN {printf \"%.0f\", $DISK_RANDRW_LAT_AVG/1000}")
    log_debug "Parsed IOPS: read=$DISK_RANDRW_IOPS_R, write=$DISK_RANDRW_IOPS_W"
  else
    log_verbose "fio output parsing failed, output was:"
    log_verbose "$out"
    DISK_RANDRW_IOPS_R=0
    DISK_RANDRW_IOPS_W=0
    DISK_RANDRW_IOPS_TOTAL=0
    DISK_RANDRW_BW_R_MB="0"
    DISK_RANDRW_BW_W_MB="0"
    DISK_RANDRW_LAT_AVG_US=0
  fi
  
  log_success "Disk random r/w: ${DISK_RANDRW_IOPS_TOTAL} IOPS"
  
  # Sequential read test
  log "Running Disk benchmark (sequential read, ${DISK_RUNTIME}s)..."
  
  # Set iodepth for sequential tests
  local seq_iodepth=16
  if [[ "$ioengine" == "sync" ]]; then
    seq_iodepth=1
  fi
  
  out="$(fio --name=proxmark-seqread \
    --filename="$filename" \
    --rw=read \
    --bs=1M \
    --iodepth="$seq_iodepth" \
    --size="$DISK_SIZE" \
    --time_based \
    --runtime="$DISK_RUNTIME" \
    --group_reporting \
    --ioengine="$ioengine" \
    --output-format=json 2>&1)" || true
  
  if echo "$out" | jq -e '.jobs[0]' >/dev/null 2>&1; then
    DISK_SEQ_READ_IOPS=$(echo "$out" | jq -r '.jobs[0].read.iops // 0' | cut -d. -f1)
    local bw_bytes=$(echo "$out" | jq -r '.jobs[0].read.bw_bytes // 0')
    DISK_SEQ_READ_MB=$(awk "BEGIN {printf \"%.2f\", $bw_bytes/1024/1024}")
  else
    log_verbose "Sequential read fio parsing failed"
    DISK_SEQ_READ_IOPS=0
    DISK_SEQ_READ_MB="0"
  fi
  
  log_success "Disk seq read: ${DISK_SEQ_READ_MB} MB/s"
  
  # Sequential write test
  log "Running Disk benchmark (sequential write, ${DISK_RUNTIME}s)..."
  
  out="$(fio --name=proxmark-seqwrite \
    --filename="$filename" \
    --rw=write \
    --bs=1M \
    --iodepth="$seq_iodepth" \
    --size="$DISK_SIZE" \
    --time_based \
    --runtime="$DISK_RUNTIME" \
    --group_reporting \
    --ioengine="$ioengine" \
    --output-format=json 2>&1)" || true
  
  if echo "$out" | jq -e '.jobs[0]' >/dev/null 2>&1; then
    DISK_SEQ_WRITE_IOPS=$(echo "$out" | jq -r '.jobs[0].write.iops // 0' | cut -d. -f1)
    local bw_bytes=$(echo "$out" | jq -r '.jobs[0].write.bw_bytes // 0')
    DISK_SEQ_WRITE_MB=$(awk "BEGIN {printf \"%.2f\", $bw_bytes/1024/1024}")
  else
    log_verbose "Sequential write fio parsing failed"
    DISK_SEQ_WRITE_IOPS=0
    DISK_SEQ_WRITE_MB="0"
  fi
  
  log_success "Disk seq write: ${DISK_SEQ_WRITE_MB} MB/s"
  
  # Cleanup
  rm -f "$filename"
}

# === Score Calculation ===

calculate_scores() {
  log_verbose "Calculating scores..."
  
  # Baselines (mid-range reference hardware)
  local cpu_multi_baseline=10000
  local cpu_single_baseline=1000
  local mem_baseline=5000
  local disk_iops_baseline=50000
  local disk_bw_baseline=1000
  
  # Calculate individual scores
  SCORE_CPU_MULTI=$(awk "BEGIN {printf \"%.0f\", (${CPU_MULTI_EPS:-0} / $cpu_multi_baseline) * 100}")
  SCORE_CPU_SINGLE=$(awk "BEGIN {printf \"%.0f\", (${CPU_SINGLE_EPS:-0} / $cpu_single_baseline) * 100}")
  SCORE_MEMORY=$(awk "BEGIN {printf \"%.0f\", (${MEM_WRITE_MBS:-0} / $mem_baseline) * 100}")
  SCORE_DISK_IOPS=$(awk "BEGIN {printf \"%.0f\", (${DISK_RANDRW_IOPS_TOTAL:-0} / $disk_iops_baseline) * 100}")
  SCORE_DISK_BW=$(awk "BEGIN {printf \"%.0f\", (${DISK_SEQ_READ_MB:-0} / $disk_bw_baseline) * 100}")
  
  # Composite score (weighted)
  # CPU: 25%, Memory: 15%, Disk: 60%
  SCORE_TOTAL=$(awk "BEGIN {
    cpu_score = ($SCORE_CPU_MULTI + $SCORE_CPU_SINGLE) / 2
    disk_score = ($SCORE_DISK_IOPS + $SCORE_DISK_BW) / 2
    total = (cpu_score * 0.25) + ($SCORE_MEMORY * 0.15) + (disk_score * 0.60)
    printf \"%.0f\", total * 10
  }")
  
  log_verbose "Scores - CPU: $SCORE_CPU_MULTI/$SCORE_CPU_SINGLE, Mem: $SCORE_MEMORY, Disk: $SCORE_DISK_IOPS/$SCORE_DISK_BW, Total: $SCORE_TOTAL"
}

# === Output Generation ===

generate_json() {
  # Build tags array
  local tags_json="[]"
  if [[ -n "$TAGS" ]]; then
    tags_json=$(echo "$TAGS" | tr ',' '\n' | jq -R . | jq -s .)
  fi
  
  RESULT_JSON_BODY=$(jq -n \
    --argjson sysinfo "$SYSINFO_JSON" \
    --arg version "$VERSION" \
    --arg run_id "$RUN_UUID" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg disk_path "$DISK_PATH" \
    --argjson quick_mode "$([[ "$QUICK_MODE" == "true" ]] && echo "true" || echo "false")" \
    --arg cpu_multi_eps "${CPU_MULTI_EPS:-0}" \
    --arg cpu_multi_events "${CPU_MULTI_TOTAL_EVENTS:-0}" \
    --arg cpu_multi_lat_avg "${CPU_MULTI_LATENCY_AVG:-0}" \
    --arg cpu_multi_lat_p95 "${CPU_MULTI_LATENCY_P95:-0}" \
    --argjson cpu_threads "$CPU_CORES" \
    --arg cpu_single_eps "${CPU_SINGLE_EPS:-0}" \
    --arg cpu_single_lat_avg "${CPU_SINGLE_LATENCY_AVG:-0}" \
    --arg mem_write_mbs "${MEM_WRITE_MBS:-0}" \
    --arg mem_write_ops "${MEM_WRITE_OPS:-0}" \
    --arg mem_read_mbs "${MEM_READ_MBS:-0}" \
    --arg mem_read_ops "${MEM_READ_OPS:-0}" \
    --argjson disk_randrw_iops_r "${DISK_RANDRW_IOPS_R:-0}" \
    --argjson disk_randrw_iops_w "${DISK_RANDRW_IOPS_W:-0}" \
    --argjson disk_randrw_iops_total "${DISK_RANDRW_IOPS_TOTAL:-0}" \
    --arg disk_randrw_bw_r "${DISK_RANDRW_BW_R_MB:-0}" \
    --arg disk_randrw_bw_w "${DISK_RANDRW_BW_W_MB:-0}" \
    --argjson disk_randrw_lat_us "${DISK_RANDRW_LAT_AVG_US:-0}" \
    --argjson disk_seq_read_iops "${DISK_SEQ_READ_IOPS:-0}" \
    --arg disk_seq_read_mb "${DISK_SEQ_READ_MB:-0}" \
    --argjson disk_seq_write_iops "${DISK_SEQ_WRITE_IOPS:-0}" \
    --arg disk_seq_write_mb "${DISK_SEQ_WRITE_MB:-0}" \
    --argjson score_cpu_multi "${SCORE_CPU_MULTI:-0}" \
    --argjson score_cpu_single "${SCORE_CPU_SINGLE:-0}" \
    --argjson score_memory "${SCORE_MEMORY:-0}" \
    --argjson score_disk_iops "${SCORE_DISK_IOPS:-0}" \
    --argjson score_disk_bw "${SCORE_DISK_BW:-0}" \
    --argjson score_total "${SCORE_TOTAL:-0}" \
    --argjson tags "$tags_json" \
    --arg notes "$NOTES" \
    '{
      version: $version,
      run_id: $run_id,
      timestamp_utc: $timestamp,
      system: $sysinfo,
      config: {
        cpu_time: '"$CPU_TIME"',
        cpu_single_time: '"$CPU_SINGLE_TIME"',
        mem_time: '"$MEM_TIME"',
        disk_runtime: '"$DISK_RUNTIME"',
        disk_path: $disk_path,
        quick_mode: $quick_mode
      },
      benchmarks: {
        cpu: {
          multi_thread: {
            events_per_sec: ($cpu_multi_eps | tonumber),
            total_events: ($cpu_multi_events | tonumber),
            latency_avg_ms: ($cpu_multi_lat_avg | tonumber),
            latency_p95_ms: ($cpu_multi_lat_p95 | tonumber),
            threads: $cpu_threads
          },
          single_thread: {
            events_per_sec: ($cpu_single_eps | tonumber),
            latency_avg_ms: ($cpu_single_lat_avg | tonumber)
          }
        },
        memory: {
          write: {
            mb_per_sec: ($mem_write_mbs | tonumber),
            total_ops: ($mem_write_ops | tonumber)
          },
          read: {
            mb_per_sec: ($mem_read_mbs | tonumber),
            total_ops: ($mem_read_ops | tonumber)
          }
        },
        disk: {
          randrw: {
            iops_read: $disk_randrw_iops_r,
            iops_write: $disk_randrw_iops_w,
            iops_total: $disk_randrw_iops_total,
            bw_read_mb: ($disk_randrw_bw_r | tonumber),
            bw_write_mb: ($disk_randrw_bw_w | tonumber),
            latency_avg_us: $disk_randrw_lat_us
          },
          seq_read: {
            iops: $disk_seq_read_iops,
            bw_mb: ($disk_seq_read_mb | tonumber)
          },
          seq_write: {
            iops: $disk_seq_write_iops,
            bw_mb: ($disk_seq_write_mb | tonumber)
          }
        }
      },
      scores: {
        cpu_multi: $score_cpu_multi,
        cpu_single: $score_cpu_single,
        memory: $score_memory,
        disk_iops: $score_disk_iops,
        disk_bw: $score_disk_bw,
        total: $score_total
      },
      tags: $tags,
      notes: $notes
    }')
  
  echo "$RESULT_JSON_BODY" > "$RESULT_JSON"
}

print_summary() {
  if [[ "$JSON_ONLY" == "true" ]]; then
    cat "$RESULT_JSON"
    return
  fi
  
  if [[ "$QUIET" == "true" ]]; then
    echo "Score: $SCORE_TOTAL | JSON: $RESULT_JSON"
    return
  fi
  
  echo
  echo -e "${CYAN}╭──────────────────────────────────────────────────────────────────────────╮${NC}"
  echo -e "${CYAN}│${NC}${BOLD}                         BENCHMARK RESULTS                                ${NC}${CYAN}│${NC}"
  echo -e "${CYAN}╰──────────────────────────────────────────────────────────────────────────╯${NC}"
  echo
  
  # System info section
  echo -e "${BOLD}${YELLOW}SYSTEM INFORMATION${NC}"
  echo -e "${DIM}────────────────────────────────────────────────────────────────────────────${NC}"
  echo -e "  ${BOLD}Hostname:${NC}     $HOSTNAME"
  echo -e "  ${BOLD}OS:${NC}           $OS"
  echo -e "  ${BOLD}Kernel:${NC}       $KERNEL"
  [[ -n "$PROXMOX_VERSION" ]] && echo -e "  ${BOLD}Proxmox:${NC}      $PROXMOX_VERSION"
  echo
  
  # CPU info section
  echo -e "${BOLD}${YELLOW}CPU${NC}"
  echo -e "${DIM}────────────────────────────────────────────────────────────────────────────${NC}"
  echo -e "  ${BOLD}Model:${NC}        $CPU_MODEL"
  echo -e "  ${BOLD}Cores:${NC}        $CPU_CORES cores / $CPU_THREADS threads"
  echo -e "  ${BOLD}Sockets:${NC}      $CPU_SOCKETS"
  [[ -n "$CPU_FREQ_MHZ" && "$CPU_FREQ_MHZ" != "0" ]] && echo -e "  ${BOLD}Max Freq:${NC}     ${CPU_FREQ_MHZ} MHz"
  echo
  
  # Memory info section
  local mem_gb=$((MEM_TOTAL_MB / 1024))
  echo -e "${BOLD}${YELLOW}MEMORY${NC}"
  echo -e "${DIM}────────────────────────────────────────────────────────────────────────────${NC}"
  echo -e "  ${BOLD}Total:${NC}        ${mem_gb} GB (${MEM_TOTAL_MB} MB)"
  [[ "$MEM_TYPE" != "unknown" && -n "$MEM_TYPE" ]] && echo -e "  ${BOLD}Type:${NC}         $MEM_TYPE"
  [[ -n "$MEM_SPEED" ]] && echo -e "  ${BOLD}Speed:${NC}        $MEM_SPEED"
  echo
  
  # Disk info section
  local disk_model=$(echo "$SYSINFO_JSON" | jq -r '.disk_model // "Unknown"')
  local disk_type=$(echo "$SYSINFO_JSON" | jq -r '.disk_type // "unknown"')
  local disk_size=$(echo "$SYSINFO_JSON" | jq -r '.disk_size_gb // 0')
  echo -e "${BOLD}${YELLOW}STORAGE${NC}"
  echo -e "${DIM}────────────────────────────────────────────────────────────────────────────${NC}"
  echo -e "  ${BOLD}Test Path:${NC}    $DISK_PATH"
  echo -e "  ${BOLD}Device:${NC}       $(echo "$SYSINFO_JSON" | jq -r '.root_device // "Unknown"')"
  [[ -n "$disk_model" && "$disk_model" != "Unknown" && "$disk_model" != "" ]] && echo -e "  ${BOLD}Model:${NC}        $disk_model"
  echo -e "  ${BOLD}Type:${NC}         ${disk_type^^}"
  [[ "$disk_size" -gt 0 ]] && echo -e "  ${BOLD}Size:${NC}         ${disk_size} GB"
  echo
  
  # Benchmark Results section
  echo -e "${BOLD}${YELLOW}BENCHMARK RESULTS${NC}"
  echo -e "${DIM}────────────────────────────────────────────────────────────────────────────${NC}"
  echo
  echo -e "${DIM}┌────────────┬────────────────────────┬──────────────┬─────────┐${NC}"
  echo -e "${DIM}│${NC}${BOLD} Component  ${DIM}│${NC}${BOLD} Metric                 ${DIM}│${NC}${BOLD} Value        ${DIM}│${NC}${BOLD} Score   ${DIM}│${NC}"
  echo -e "${DIM}├────────────┼────────────────────────┼──────────────┼─────────┤${NC}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-22s ${DIM}│${NC} %12s ${DIM}│${NC} ${GREEN}%7s${NC} ${DIM}│${NC}\n" "CPU" "Multi-thread (ev/s)" "${CPU_MULTI_EPS}" "${SCORE_CPU_MULTI}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-22s ${DIM}│${NC} %12s ${DIM}│${NC} ${GREEN}%7s${NC} ${DIM}│${NC}\n" "CPU" "Single-thread (ev/s)" "${CPU_SINGLE_EPS}" "${SCORE_CPU_SINGLE}"
  echo -e "${DIM}├────────────┼────────────────────────┼──────────────┼─────────┤${NC}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-22s ${DIM}│${NC} %12s ${DIM}│${NC} ${GREEN}%7s${NC} ${DIM}│${NC}\n" "Memory" "Write (MB/s)" "${MEM_WRITE_MBS}" "${SCORE_MEMORY}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-22s ${DIM}│${NC} %12s ${DIM}│${NC}         ${DIM}│${NC}\n" "Memory" "Read (MB/s)" "${MEM_READ_MBS}"
  echo -e "${DIM}├────────────┼────────────────────────┼──────────────┼─────────┤${NC}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-22s ${DIM}│${NC} %12s ${DIM}│${NC} ${GREEN}%7s${NC} ${DIM}│${NC}\n" "Disk" "4K Random R/W (IOPS)" "${DISK_RANDRW_IOPS_TOTAL}" "${SCORE_DISK_IOPS}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-22s ${DIM}│${NC} %12s ${DIM}│${NC} ${GREEN}%7s${NC} ${DIM}│${NC}\n" "Disk" "Seq Read (MB/s)" "${DISK_SEQ_READ_MB}" "${SCORE_DISK_BW}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-22s ${DIM}│${NC} %12s ${DIM}│${NC}         ${DIM}│${NC}\n" "Disk" "Seq Write (MB/s)" "${DISK_SEQ_WRITE_MB}"
  echo -e "${DIM}└────────────┴────────────────────────┴──────────────┴─────────┘${NC}"
  echo
  
  # Total score - make it stand out
  echo -e "${CYAN}╭──────────────────────────────────────────────────────────────────────────╮${NC}"
  printf "${CYAN}│${NC}                           ${BOLD}TOTAL SCORE: ${GREEN}%-6s${NC}                           ${CYAN}│${NC}\n" "${SCORE_TOTAL}"
  echo -e "${CYAN}╰──────────────────────────────────────────────────────────────────────────╯${NC}"
  echo
  
  # File paths
  echo -e "${DIM}📁 JSON saved:${NC} $RESULT_JSON"
  echo -e "${DIM}🌐 Result URL:${NC} ${YELLOW}(coming soon - proxmark.io)${NC}"
  echo
}

upload_results() {
  if [[ "$NO_UPLOAD" == "true" ]]; then
    return
  fi
  
  # For now, just log that upload is not yet implemented
  log_verbose "Upload functionality not yet implemented"
  
  # Future implementation:
  # if [[ "$FORCE_UPLOAD" == "true" ]] || ask_upload; then
  #   local response
  #   response=$(curl -s -X POST "$API_URL/results" \
  #     -H "Content-Type: application/json" \
  #     -d "$RESULT_JSON_BODY")
  #   
  #   local result_id=$(echo "$response" | jq -r '.id')
  #   local result_url=$(echo "$response" | jq -r '.url')
  #   echo "Result URL: $result_url"
  # fi
}

# === Main ===

main() {
  parse_args "$@"
  
  if [[ "$HELP" == "true" ]]; then
    usage
    exit 0
  fi
  
  if [[ "$SHOW_VERSION" == "true" ]]; then
    echo "proxmark v$VERSION"
    exit 0
  fi
  
  print_banner
  debug_system_info
  
  check_dependencies
  collect_sysinfo
  
  run_cpu_benchmark
  run_mem_benchmark
  run_disk_benchmark
  
  calculate_scores
  generate_json
  
  print_summary
  upload_results
  
  log_success "Benchmark complete!"
}

main "$@"


