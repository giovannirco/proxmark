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
VERSION="1.0.8"

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
DISK_PATH="${PROXMARK_DISK_PATH:-}"  # Empty = auto-detect
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
ALL_DISKS=false
INTERACTIVE=true
HELP=false
SHOW_VERSION=false
TAGS=""
NOTES=""
CUSTOM_OUTPUT=""
IPERF_SERVER=""

# === Derived variables ===
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
RESULT_JSON="${RESULT_DIR}/proxmark-result-${TIMESTAMP}.json"
LOG_FILE="${RESULT_DIR}/proxmark-${TIMESTAMP}.log"
DEBUG_FILE="${RESULT_DIR}/proxmark-${TIMESTAMP}.debug"
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
    --disk-path PATH    Directory to use for disk benchmarks (default: /var/lib/vz on Proxmox)
    --all-disks         Benchmark all detected storage paths
    --iperf HOST[:PORT] Run network benchmark against iperf3 server (default port: 5201)
    --output FILE       Custom output path for JSON results
    --tag TAG           Add a tag to results (can be used multiple times)
    --notes "TEXT"      Add notes to the benchmark result
    --non-interactive   Don't prompt for additional disks

${BOLD}ENVIRONMENT VARIABLES:${NC}
    PROXMARK_DISK_PATH   Same as --disk-path
    PROXMARK_CPU_TIME    CPU benchmark duration (default: 60)
    PROXMARK_MEM_TIME    Memory benchmark duration (default: 30)
    PROXMARK_DISK_RUNTIME Disk benchmark duration (default: 60)
    PROXMARK_API_URL     API server URL

${BOLD}EXAMPLES:${NC}
    # Standard benchmark (auto-detects /var/lib/vz on Proxmox)
    bash proxmark.sh

    # Quick benchmark (~2 min)
    bash proxmark.sh --quick

    # Benchmark all storage locations
    bash proxmark.sh --all-disks

    # Include network benchmark (requires iperf3 server)
    bash proxmark.sh --iperf 192.168.1.100

    # Tag your Proxmox node
    bash proxmark.sh --tag "production" --tag "nvme" --notes "New node"

    # Non-interactive mode (for scripts)
    curl -sL .../proxmark.sh | bash -s -- --non-interactive

    # Debug mode for troubleshooting
    bash proxmark.sh --debug

${BOLD}MORE INFO:${NC}
    https://github.com/giovannirco/proxmark
    https://proxmark.io

EOF
}

write_log() {
  local level="$1"
  shift
  local msg="$*"
  local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  # Always write to log file if it exists
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "[$ts] [$level] $msg" >> "$LOG_FILE" 2>/dev/null || true
  fi
  
  # Write to debug file if in debug mode
  if [[ "$DEBUG" == "true" ]] && [[ -n "${DEBUG_FILE:-}" ]]; then
    echo "[$ts] [$level] $msg" >> "$DEBUG_FILE" 2>/dev/null || true
  fi
}

log() {
  write_log "INFO" "$*"
  if [[ "$QUIET" == "true" ]] || [[ "$JSON_ONLY" == "true" ]]; then
    return
  fi
  echo -e "${BLUE}[proxmark]${NC} $*" >&2
}

log_success() {
  write_log "OK" "$*"
  if [[ "$QUIET" == "true" ]] || [[ "$JSON_ONLY" == "true" ]]; then
    return
  fi
  echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
  write_log "WARN" "$*"
  if [[ "$JSON_ONLY" == "true" ]]; then
    return
  fi
  echo -e "${YELLOW}[!]${NC} $*" >&2
}

log_error() {
  write_log "ERROR" "$*"
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_verbose() {
  write_log "DEBUG" "$*"
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
      --all-disks)
        ALL_DISKS=true
        shift
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
      --iperf)
        IPERF_SERVER="$2"
        shift 2
        ;;
      --non-interactive)
        INTERACTIVE=false
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
  
  # When running via pipe, disable interactive mode
  if [[ ! -t 0 ]]; then
    INTERACTIVE=false
  fi
  
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
  
  # Auto-detect best disk path
  if [[ -z "$DISK_PATH" ]]; then
    if [[ "$IS_PROXMOX" == "true" ]] && [[ -d /var/lib/vz ]]; then
      # Check if /var/lib/vz is a real storage (not just tmpfs)
      local vz_fs=$(df /var/lib/vz 2>/dev/null | awk 'NR==2 {print $1}')
      if [[ "$vz_fs" != "tmpfs" ]] && [[ -n "$vz_fs" ]]; then
        DISK_PATH="/var/lib/vz"
        log "Auto-detected Proxmox storage: $DISK_PATH"
      else
        DISK_PATH="/tmp"
        log_warning "Could not detect Proxmox storage, using /tmp"
      fi
    else
      DISK_PATH="/tmp"
    fi
  fi
}

discover_storage_paths() {
  # Discover all available storage paths for benchmarking
  DISCOVERED_STORAGE=()
  
  # Add current disk path first
  DISCOVERED_STORAGE+=("$DISK_PATH")
  
  # Proxmox storage pools
  if command -v pvesm >/dev/null 2>&1; then
    while IFS= read -r line; do
      local name=$(echo "$line" | awk '{print $1}')
      local type=$(echo "$line" | awk '{print $2}')
      local status=$(echo "$line" | awk '{print $3}')
      
      [[ "$status" != "active" ]] && continue
      
      # Get path for this storage
      local path=""
      case "$type" in
        dir|nfs|cifs|glusterfs)
          path=$(pvesm path "$name" 2>/dev/null | head -1 | sed 's|/images$||' || echo "")
          ;;
        lvmthin|lvm)
          # LVM storage - check if there's a path we can use
          path="/var/lib/vz"  # Default for LVM-backed storage
          ;;
        zfspool)
          # ZFS pool - find mount point
          local dataset=$(pvesm status 2>/dev/null | awk -v n="$name" '$1==n {print $1}')
          path=$(zfs get -H -o value mountpoint "$dataset" 2>/dev/null || echo "")
          ;;
      esac
      
      # Add if valid and not already in list
      if [[ -n "$path" ]] && [[ -d "$path" ]] && [[ ! " ${DISCOVERED_STORAGE[*]} " =~ " $path " ]]; then
        DISCOVERED_STORAGE+=("$path")
      fi
    done < <(pvesm status 2>/dev/null | tail -n +2)
  fi
  
  # Also check common mount points
  for path in /mnt/pve/* /mnt/*; do
    if [[ -d "$path" ]] && [[ ! " ${DISCOVERED_STORAGE[*]} " =~ " $path " ]]; then
      # Check it's not tmpfs and has reasonable space
      local fs=$(df "$path" 2>/dev/null | awk 'NR==2 {print $1}')
      local avail=$(df "$path" 2>/dev/null | awk 'NR==2 {print $4}')
      if [[ "$fs" != "tmpfs" ]] && [[ "${avail:-0}" -gt 2097152 ]]; then  # > 2GB
        DISCOVERED_STORAGE+=("$path")
      fi
    fi
  done
  
  log_verbose "Discovered storage paths: ${DISCOVERED_STORAGE[*]}"
}

prompt_additional_disks() {
  # Initialize the array (even if we skip)
  ADDITIONAL_DISK_PATHS=()
  
  # If non-interactive or only one storage, skip
  if [[ "$INTERACTIVE" != "true" ]] || [[ ${#DISCOVERED_STORAGE[@]} -le 1 ]]; then
    return
  fi
  
  echo
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}Additional storage paths detected:${NC}"
  for i in "${!DISCOVERED_STORAGE[@]}"; do
    if [[ $i -eq 0 ]]; then
      echo -e "  ${GREEN}[0]${NC} ${DISCOVERED_STORAGE[$i]} (already tested)"
    else
      echo -e "  ${CYAN}[$i]${NC} ${DISCOVERED_STORAGE[$i]}"
    fi
  done
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo
  
  read -p "Test additional storage? (enter numbers separated by space, or 'all', or press Enter to skip): " -t 30 response || response=""
  
  if [[ -z "$response" ]]; then
    return
  fi
  
  ADDITIONAL_DISK_PATHS=()
  
  if [[ "$response" == "all" ]]; then
    for i in "${!DISCOVERED_STORAGE[@]}"; do
      [[ $i -gt 0 ]] && ADDITIONAL_DISK_PATHS+=("${DISCOVERED_STORAGE[$i]}")
    done
  else
    for num in $response; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -gt 0 ]] && [[ $num -lt ${#DISCOVERED_STORAGE[@]} ]]; then
        ADDITIONAL_DISK_PATHS+=("${DISCOVERED_STORAGE[$num]}")
      fi
    done
  fi
  
  if [[ ${#ADDITIONAL_DISK_PATHS[@]} -gt 0 ]]; then
    log "Will also benchmark: ${ADDITIONAL_DISK_PATHS[*]}"
  fi
}

check_dependencies() {
  log "Checking dependencies..."
  
  detect_os
  check_proxmox
  
  require_cmd_or_install sysbench sysbench
  require_cmd_or_install fio fio
  require_cmd_or_install jq jq
  require_cmd_or_install lshw lshw
  
  # Check for libaio (needed for fio with libaio engine)
  if [[ "$PKG_MANAGER" == "apt" ]] && ! dpkg -l 2>/dev/null | grep -q libaio; then
    log_verbose "Installing libaio-dev for fio..."
    run_as_root apt-get install -y libaio-dev >/dev/null 2>&1 || true
  fi
  
  log_success "All dependencies satisfied"
}

# === System Information ===

# Measure power consumption over a duration
# Usage: measure_power [duration_seconds]
# Returns: average power in watts
measure_power() {
  local duration=${1:-1}
  
  if [[ -z "$RAPL_ENERGY_FILE" ]] || [[ ! -f "$RAPL_ENERGY_FILE" ]]; then
    echo "0"
    return
  fi
  
  local e1=$(cat "$RAPL_ENERGY_FILE" 2>/dev/null || echo 0)
  sleep "$duration"
  local e2=$(cat "$RAPL_ENERGY_FILE" 2>/dev/null || echo 0)
  
  if [[ $e2 -gt $e1 ]]; then
    # Power = energy / time, energy is in microjoules
    local energy_diff=$((e2 - e1))
    awk "BEGIN {printf \"%.1f\", $energy_diff / ($duration * 1000000)}"
  else
    echo "0"
  fi
}

collect_sysinfo() {
  log "Collecting system information..."
  
  HOSTNAME="$(hostname)"
  
  # CPU info from /proc/cpuinfo (basic)
  CPU_MODEL="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//' || echo 'Unknown')"
  CPU_CORES="$(nproc --all)"
  CPU_THREADS="$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "$CPU_CORES")"
  CPU_SOCKETS="$(grep 'physical id' /proc/cpuinfo | sort -u | wc -l)"
  [[ "$CPU_SOCKETS" -eq 0 ]] && CPU_SOCKETS=1
  
  # Additional CPU info
  CPU_VENDOR=""
  CPU_SOCKET=""
  CPU_ARCH=""
  CPU_CACHE_L1=""
  CPU_CACHE_L2=""
  CPU_CACHE_L3=""
  
  # Use lshw for detailed CPU info
  if command -v lshw >/dev/null 2>&1; then
    local lshw_cpu
    lshw_cpu=$(run_as_root lshw -C cpu 2>/dev/null || echo "")
    local lshw_cache
    lshw_cache=$(run_as_root lshw -C memory 2>/dev/null | grep -A5 "cache" || echo "")
    
    if [[ -n "$lshw_cpu" ]]; then
      # Extract vendor
      CPU_VENDOR=$(echo "$lshw_cpu" | grep "vendor:" | head -1 | sed 's/.*vendor: //' | sed 's/\[.*\]//' | xargs)
      
      # Extract socket type (slot)
      CPU_SOCKET=$(echo "$lshw_cpu" | grep "slot:" | head -1 | sed 's/.*slot: //')
      
      # Extract architecture (width)
      local width=$(echo "$lshw_cpu" | grep "width:" | head -1 | sed 's/.*width: //')
      [[ -n "$width" ]] && CPU_ARCH="$width"
    fi
    
    # Extract cache info from lshw memory output
    if [[ -n "$lshw_cache" ]]; then
      CPU_CACHE_L1=$(run_as_root lshw -C memory 2>/dev/null | grep -A3 "L1" | grep "size:" | head -1 | sed 's/.*size: //')
      CPU_CACHE_L2=$(run_as_root lshw -C memory 2>/dev/null | grep -A3 "L2" | grep "size:" | head -1 | sed 's/.*size: //')
      CPU_CACHE_L3=$(run_as_root lshw -C memory 2>/dev/null | grep -A3 "L3" | grep "size:" | head -1 | sed 's/.*size: //')
    fi
  fi
  
  # Fallback vendor detection from /proc/cpuinfo
  if [[ -z "$CPU_VENDOR" ]]; then
    local vendor_id=$(grep -m1 'vendor_id' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')
    case "$vendor_id" in
      GenuineIntel) CPU_VENDOR="Intel" ;;
      AuthenticAMD) CPU_VENDOR="AMD" ;;
      *) CPU_VENDOR="$vendor_id" ;;
    esac
  fi
  
  # CPU frequency detection (base and max/boost)
  CPU_FREQ_BASE_MHZ=""
  CPU_FREQ_MAX_MHZ=""
  CPU_FREQ_CURRENT_MHZ=""
  CPU_TDP_WATTS=""
  POWER_IDLE_WATTS=""
  POWER_LOAD_WATTS=""
  
  # Try to get base frequency from cpufreq
  if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/base_frequency ]]; then
    local base_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/base_frequency 2>/dev/null || echo 0)
    CPU_FREQ_BASE_MHZ=$((base_khz / 1000))
  fi
  
  # Try lshw for base frequency (shown as "size" = current, "capacity" = max)
  if [[ -z "$CPU_FREQ_BASE_MHZ" || "$CPU_FREQ_BASE_MHZ" == "0" ]] && command -v lshw >/dev/null 2>&1; then
    local lshw_cpu=$(run_as_root lshw -C cpu 2>/dev/null || echo "")
    if [[ -n "$lshw_cpu" ]]; then
      # lshw shows "clock: 100MHz" which is the base clock, and "capacity: 4367MHz" for max
      # The "size" field shows current frequency
      local lshw_size=$(echo "$lshw_cpu" | grep "size:" | head -1 | sed 's/.*size: //' | grep -oE '[0-9]+')
      local lshw_capacity=$(echo "$lshw_cpu" | grep "capacity:" | head -1 | sed 's/.*capacity: //' | grep -oE '[0-9]+')
      
      # Current frequency
      [[ -n "$lshw_size" ]] && CPU_FREQ_CURRENT_MHZ="$lshw_size"
      # Max frequency from capacity
      [[ -n "$lshw_capacity" ]] && CPU_FREQ_MAX_MHZ="$lshw_capacity"
    fi
  fi
  
  # Fallback: use min freq as base approximation
  if [[ -z "$CPU_FREQ_BASE_MHZ" || "$CPU_FREQ_BASE_MHZ" == "0" ]]; then
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq ]]; then
      local min_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null || echo 0)
      # Only use if it's reasonable (> 800 MHz)
      if [[ $min_khz -gt 800000 ]]; then
        CPU_FREQ_BASE_MHZ=$((min_khz / 1000))
      fi
    fi
  fi
  
  # Try to extract base frequency from CPU model name (e.g., "@ 3.50GHz")
  if [[ -z "$CPU_FREQ_BASE_MHZ" || "$CPU_FREQ_BASE_MHZ" == "0" ]]; then
    local model_freq=$(echo "$CPU_MODEL" | grep -oE '@[[:space:]]*[0-9]+\.[0-9]+GHz' | grep -oE '[0-9]+\.[0-9]+')
    if [[ -n "$model_freq" ]]; then
      CPU_FREQ_BASE_MHZ=$(awk "BEGIN {printf \"%.0f\", $model_freq * 1000}")
    fi
  fi
  
  # Get max/boost frequency if not already set
  if [[ -z "$CPU_FREQ_MAX_MHZ" || "$CPU_FREQ_MAX_MHZ" == "0" ]]; then
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]]; then
      local max_khz=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0)
      CPU_FREQ_MAX_MHZ=$((max_khz / 1000))
    elif grep -q "cpu MHz" /proc/cpuinfo; then
      CPU_FREQ_MAX_MHZ=$(grep -m1 "cpu MHz" /proc/cpuinfo | awk '{printf "%.0f", $4}')
    fi
  fi
  
  # CPU TDP from RAPL (Running Average Power Limit)
  # Intel: /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw
  # AMD: Similar path or via /sys/devices/system/cpu/cpufreq/*/energy_performance_preference
  if [[ -f /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw ]]; then
    local tdp_uw=$(cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_max_power_uw 2>/dev/null || echo 0)
    if [[ $tdp_uw -gt 0 ]]; then
      CPU_TDP_WATTS=$((tdp_uw / 1000000))
    fi
  elif [[ -f /sys/class/powercap/intel-rapl:0/constraint_0_max_power_uw ]]; then
    local tdp_uw=$(cat /sys/class/powercap/intel-rapl:0/constraint_0_max_power_uw 2>/dev/null || echo 0)
    if [[ $tdp_uw -gt 0 ]]; then
      CPU_TDP_WATTS=$((tdp_uw / 1000000))
    fi
  fi
  
  # Detect RAPL energy file for power measurement
  RAPL_ENERGY_FILE=""
  if [[ -f /sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj ]]; then
    RAPL_ENERGY_FILE="/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj"
  elif [[ -f /sys/class/powercap/intel-rapl:0/energy_uj ]]; then
    RAPL_ENERGY_FILE="/sys/class/powercap/intel-rapl:0/energy_uj"
  fi
  
  # Measure idle power
  if [[ -n "$RAPL_ENERGY_FILE" ]]; then
    POWER_IDLE_WATTS=$(measure_power 1)
    log_verbose "Idle power: ${POWER_IDLE_WATTS}W"
  fi
  
  log_verbose "CPU: vendor=$CPU_VENDOR, socket=$CPU_SOCKET, arch=$CPU_ARCH, base=${CPU_FREQ_BASE_MHZ}MHz, max=${CPU_FREQ_MAX_MHZ}MHz, tdp=${CPU_TDP_WATTS}W"
  log_verbose "CPU cache: L1=$CPU_CACHE_L1, L2=$CPU_CACHE_L2, L3=$CPU_CACHE_L3"
  
  # Memory info
  MEM_TOTAL_KB="$(grep MemTotal /proc/meminfo | awk '{print $2}')"
  MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))
  MEM_TOTAL_GB=$((MEM_TOTAL_MB / 1024))
  
  # Memory detection using lshw (preferred) or dmidecode fallback
  MEM_TYPE="unknown"
  MEM_SPEED=""
  MEM_CHANNELS=""
  MEM_SLOTS_USED=0
  MEM_SLOTS_TOTAL=0
  MEM_ECC=""
  MEM_FORM_FACTOR=""
  MEM_BANKS=()  # Array to store per-bank info
  MEM_BANKS_JSON="[]"
  
  if command -v lshw >/dev/null 2>&1; then
    local lshw_mem
    lshw_mem=$(run_as_root lshw -C memory 2>/dev/null || echo "")
    
    if [[ -n "$lshw_mem" ]]; then
      # Parse memory banks from lshw output
      local bank_idx=0
      local in_bank=false
      local bank_desc="" bank_product="" bank_vendor="" bank_slot="" bank_size="" bank_clock=""
      
      while IFS= read -r line; do
        # Check for new section (bank, cache, memory, firmware)
        if echo "$line" | grep -q "^\s*\*-"; then
          # Save previous bank if exists and was valid
          if [[ "$in_bank" == true ]] && [[ -n "$bank_size" ]] && [[ "$bank_size" != "[empty]" ]]; then
            MEM_BANKS+=("$bank_slot|$bank_size|$bank_vendor|$bank_product|$bank_clock")
            MEM_SLOTS_USED=$((MEM_SLOTS_USED + 1))
          fi
          
          # Check if this is a new bank section
          if echo "$line" | grep -q "^\s*\*-bank"; then
            in_bank=true
            bank_desc="" bank_product="" bank_vendor="" bank_slot="" bank_size="" bank_clock=""
            MEM_SLOTS_TOTAL=$((MEM_SLOTS_TOTAL + 1))
          else
            # Not a bank section (cache, firmware, etc.) - stop parsing as bank
            in_bank=false
          fi
        elif [[ "$in_bank" == true ]]; then
          if echo "$line" | grep -q "description:"; then
            bank_desc=$(echo "$line" | sed 's/.*description: //')
            # Extract form factor and type from description
            if echo "$bank_desc" | grep -qi "SODIMM"; then
              MEM_FORM_FACTOR="SODIMM"
            elif echo "$bank_desc" | grep -qi "DIMM"; then
              MEM_FORM_FACTOR="DIMM"
            fi
            if echo "$bank_desc" | grep -qi "DDR5"; then
              MEM_TYPE="DDR5"
            elif echo "$bank_desc" | grep -qi "DDR4"; then
              MEM_TYPE="DDR4"
            elif echo "$bank_desc" | grep -qi "DDR3"; then
              MEM_TYPE="DDR3"
            fi
            # Check for ECC/Unbuffered
            if echo "$bank_desc" | grep -qi "Unbuffered"; then
              MEM_ECC="Non-ECC"
            elif echo "$bank_desc" | grep -qi "Registered\|ECC"; then
              MEM_ECC="ECC"
            fi
          elif echo "$line" | grep -q "product:"; then
            bank_product=$(echo "$line" | sed 's/.*product: //')
          elif echo "$line" | grep -q "vendor:"; then
            bank_vendor=$(echo "$line" | sed 's/.*vendor: //')
          elif echo "$line" | grep -q "slot:"; then
            bank_slot=$(echo "$line" | sed 's/.*slot: //')
          elif echo "$line" | grep -q "size:"; then
            bank_size=$(echo "$line" | sed 's/.*size: //')
          elif echo "$line" | grep -q "clock:"; then
            bank_clock=$(echo "$line" | sed 's/.*clock: //' | awk '{print $1}')
            [[ -z "$MEM_SPEED" ]] && MEM_SPEED="${bank_clock}"
          fi
        fi
      done <<< "$lshw_mem"
      
      # Save last bank if we ended while still in a bank section
      if [[ "$in_bank" == true ]] && [[ -n "$bank_size" ]] && [[ "$bank_size" != "[empty]" ]] && [[ ! "$bank_slot" =~ [Cc]ache ]]; then
        MEM_BANKS+=("$bank_slot|$bank_size|$bank_vendor|$bank_product|$bank_clock")
        MEM_SLOTS_USED=$((MEM_SLOTS_USED + 1))
      fi
      
      # Build JSON array for memory banks
      if [[ ${#MEM_BANKS[@]} -gt 0 ]]; then
        MEM_BANKS_JSON="["
        for i in "${!MEM_BANKS[@]}"; do
          IFS='|' read -r slot size vendor product clock <<< "${MEM_BANKS[$i]}"
          [[ $i -gt 0 ]] && MEM_BANKS_JSON+=","
          MEM_BANKS_JSON+="{\"slot\":\"$slot\",\"size\":\"$size\",\"vendor\":\"$vendor\",\"product\":\"$product\",\"speed\":\"$clock\"}"
        done
        MEM_BANKS_JSON+="]"
      fi
    fi
  fi
  
  # Fallback to dmidecode if lshw didn't provide enough info
  if [[ "$MEM_TYPE" == "unknown" ]] && command -v dmidecode >/dev/null 2>&1; then
    local dmi_out
    dmi_out=$(run_as_root dmidecode -t memory 2>/dev/null || echo "")
    if [[ -n "$dmi_out" ]]; then
      MEM_TYPE=$(echo "$dmi_out" | grep -E "^\s*Type:" | grep -v "Error" | grep -v "Unknown" | head -1 | awk '{print $2}' || echo "unknown")
      [[ -z "$MEM_TYPE" ]] && MEM_TYPE="unknown"
      
      if [[ -z "$MEM_SPEED" ]]; then
        MEM_SPEED=$(echo "$dmi_out" | grep -E "^\s*Configured Memory Speed:" | grep -v "Unknown" | head -1 | awk '{print $4}' || echo "")
        [[ -z "$MEM_SPEED" ]] && MEM_SPEED=$(echo "$dmi_out" | grep -E "^\s*Speed:" | grep -v "Unknown" | head -1 | awk '{print $2}' || echo "")
      fi
      
      if [[ -z "$MEM_ECC" ]]; then
        local ecc_type=$(echo "$dmi_out" | grep -E "^\s*Error Correction Type:" | head -1 | awk '{print $4}' || echo "")
        if [[ "$ecc_type" == "Single-bit" ]] || [[ "$ecc_type" == "Multi-bit" ]]; then
          MEM_ECC="ECC"
        elif [[ "$ecc_type" == "None" ]]; then
          MEM_ECC="Non-ECC"
        fi
      fi
      
      if [[ $MEM_SLOTS_TOTAL -eq 0 ]]; then
        MEM_SLOTS_TOTAL=$(echo "$dmi_out" | grep -c "Memory Device" || echo 0)
        MEM_SLOTS_USED=$(echo "$dmi_out" | grep -E "^\s*Size:" | grep -v "No Module" | grep -v "Unknown" | wc -l || echo 0)
      fi
    fi
  fi
  
  # Determine channel configuration
  if [[ $MEM_SLOTS_USED -eq 1 ]]; then
    MEM_CHANNELS="Single Channel"
  elif [[ $MEM_SLOTS_USED -eq 2 ]]; then
    MEM_CHANNELS="Dual Channel"
  elif [[ $MEM_SLOTS_USED -eq 3 ]]; then
    MEM_CHANNELS="Triple Channel"
  elif [[ $MEM_SLOTS_USED -eq 4 ]]; then
    MEM_CHANNELS="Quad Channel"
  elif [[ $MEM_SLOTS_USED -eq 6 ]]; then
    MEM_CHANNELS="Hexa Channel"
  elif [[ $MEM_SLOTS_USED -eq 8 ]]; then
    MEM_CHANNELS="Octa Channel"
  elif [[ $MEM_SLOTS_USED -gt 8 ]]; then
    MEM_CHANNELS="${MEM_SLOTS_USED}-DIMM"
  fi
  
  # Add MT/s suffix if just a number
  if [[ -n "$MEM_SPEED" ]] && [[ "$MEM_SPEED" =~ ^[0-9]+$ ]]; then
    MEM_SPEED="${MEM_SPEED}MHz"
  fi
  
  log_verbose "Memory detection: type=$MEM_TYPE, form=$MEM_FORM_FACTOR, speed=$MEM_SPEED, slots=${MEM_SLOTS_USED}/${MEM_SLOTS_TOTAL}, channels=$MEM_CHANNELS, ecc=$MEM_ECC"
  log_verbose "Memory banks: ${MEM_BANKS[*]}"
  
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
  PVE_NODE_NAME=""
  PVE_CLUSTER_NAME=""
  PVE_CLUSTER_NODES=0
  PVE_SUBSCRIPTION=""
  PVE_VM_COUNT=0
  PVE_CT_COUNT=0
  PVE_STORAGE_INFO=""
  
  if command -v pveversion >/dev/null 2>&1; then
    PROXMOX_VERSION=$(pveversion 2>/dev/null | head -1 || echo "")
    
    # Get node name
    PVE_NODE_NAME=$(hostname -s 2>/dev/null || hostname)
    
    # Cluster info
    if command -v pvecm >/dev/null 2>&1; then
      local cluster_status=$(pvecm status 2>/dev/null || echo "")
      if [[ -n "$cluster_status" ]] && ! echo "$cluster_status" | grep -q "does not exist"; then
        PVE_CLUSTER_NAME=$(echo "$cluster_status" | grep -m1 "Name:" | awk '{print $2}' || echo "")
        PVE_CLUSTER_NODES=$(echo "$cluster_status" | grep -m1 "Nodes:" | awk '{print $2}' || echo 0)
      fi
    fi
    
    # Subscription status
    if command -v pvesubscription >/dev/null 2>&1; then
      local sub_status=$(pvesubscription get 2>/dev/null | grep -m1 "status" || echo "")
      if echo "$sub_status" | grep -qi "active"; then
        PVE_SUBSCRIPTION="active"
      elif echo "$sub_status" | grep -qi "notfound"; then
        PVE_SUBSCRIPTION="none"
      else
        PVE_SUBSCRIPTION="unknown"
      fi
    fi
    
    # Count VMs and containers
    if command -v qm >/dev/null 2>&1; then
      PVE_VM_COUNT=$(qm list 2>/dev/null | tail -n +2 | wc -l || echo 0)
    fi
    if command -v pct >/dev/null 2>&1; then
      PVE_CT_COUNT=$(pct list 2>/dev/null | tail -n +2 | wc -l || echo 0)
    fi
    
    # Storage info
    if command -v pvesm >/dev/null 2>&1; then
      PVE_STORAGE_INFO=$(pvesm status 2>/dev/null | tail -n +2 | awk '{printf "%s(%s) ", $1, $2}' || echo "")
    fi
    
    log_verbose "Proxmox info: node=$PVE_NODE_NAME, cluster=$PVE_CLUSTER_NAME, nodes=$PVE_CLUSTER_NODES, VMs=$PVE_VM_COUNT, CTs=$PVE_CT_COUNT"
  fi
  
  # Disk info - detect the physical device underlying the mount
  ROOT_DEV="$(df "$DISK_PATH" 2>/dev/null | awk 'NR==2{print $1}')"
  DISK_MODEL=""
  DISK_TYPE="unknown"
  DISK_SIZE_GB=0
  PHYSICAL_DEV=""
  
  # Resolve the actual physical device
  if [[ "$ROOT_DEV" == /dev/mapper/* ]]; then
    # LVM or device-mapper - need to resolve /dev/mapper/name to dm-X first
    # /dev/mapper/pve-root is a symlink to /dev/dm-X
    local real_dev=$(readlink -f "$ROOT_DEV" 2>/dev/null)
    local dm_name=$(basename "$real_dev" 2>/dev/null)
    log_verbose "Resolving LVM: $ROOT_DEV -> $real_dev ($dm_name)"
    
    if [[ "$dm_name" == dm-* ]] && [[ -d "/sys/block/$dm_name/slaves" ]]; then
      # Get first slave device (the physical volume)
      local slave=$(ls "/sys/block/$dm_name/slaves" 2>/dev/null | head -1)
      log_verbose "Found slave device: $slave"
      if [[ -n "$slave" ]]; then
        # Recursively check if slave is also a dm device
        while [[ -d "/sys/block/$slave/slaves" ]] && [[ -n "$(ls /sys/block/$slave/slaves 2>/dev/null)" ]]; do
          slave=$(ls "/sys/block/$slave/slaves" 2>/dev/null | head -1)
          log_verbose "Following chain to: $slave"
        done
        PHYSICAL_DEV="/dev/$slave"
      fi
    fi
    
    # Try lsblk as fallback
    if [[ -z "$PHYSICAL_DEV" || "$PHYSICAL_DEV" == "/dev/" ]] && command -v lsblk >/dev/null 2>&1; then
      local pkname=$(lsblk -no PKNAME "$ROOT_DEV" 2>/dev/null | grep -v '^$' | tail -1)
      if [[ -n "$pkname" ]]; then
        PHYSICAL_DEV="/dev/$pkname"
        log_verbose "lsblk found parent: $pkname"
      fi
    fi
    
    # Try dmsetup as another fallback
    if [[ -z "$PHYSICAL_DEV" || "$PHYSICAL_DEV" == "/dev/" ]] && command -v dmsetup >/dev/null 2>&1; then
      local deps=$(run_as_root dmsetup deps "$ROOT_DEV" 2>/dev/null | grep -oE '\([0-9]+, [0-9]+\)' | head -1)
      if [[ -n "$deps" ]]; then
        local major=$(echo "$deps" | grep -oE '[0-9]+' | head -1)
        local minor=$(echo "$deps" | grep -oE '[0-9]+' | tail -1)
        # Find device with this major:minor
        local dev_path=$(ls -la /dev 2>/dev/null | awk -v maj="$major" -v min="$minor" '$5==maj"," && $6==min {print "/dev/"$10}' | head -1)
        if [[ -n "$dev_path" ]]; then
          PHYSICAL_DEV="$dev_path"
          log_verbose "dmsetup found device: $dev_path (major:$major minor:$minor)"
        fi
      fi
    fi
    
    log_verbose "LVM device $ROOT_DEV -> physical device: ${PHYSICAL_DEV:-unknown}"
  elif [[ "$ROOT_DEV" == /dev/* ]]; then
    PHYSICAL_DEV="$ROOT_DEV"
  fi
  
  if [[ -n "$PHYSICAL_DEV" ]]; then
    # Strip partition number (handles nvme0n1p1 and sda1 formats)
    if [[ "$PHYSICAL_DEV" =~ nvme ]]; then
      BASE_DEV="$(echo "$PHYSICAL_DEV" | sed 's/p[0-9]*$//')"
      DISK_TYPE="nvme"
    else
      BASE_DEV="$(echo "$PHYSICAL_DEV" | sed 's/[0-9]*$//')"
    fi
    
    DEV_NAME=$(basename "$BASE_DEV")
    log_verbose "Base device: $BASE_DEV ($DEV_NAME)"
    
    # Get disk model
    if [[ -e "/sys/block/${DEV_NAME}/device/model" ]]; then
      DISK_MODEL="$(cat "/sys/block/${DEV_NAME}/device/model" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "")"
    fi
    # Try nvme id-ctrl for NVMe devices
    if [[ -z "$DISK_MODEL" ]] && [[ "$DISK_TYPE" == "nvme" ]] && command -v nvme >/dev/null 2>&1; then
      DISK_MODEL=$(run_as_root nvme id-ctrl "$BASE_DEV" 2>/dev/null | grep -m1 "^mn " | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//' || echo "")
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
    
    log_verbose "Disk detection: model=$DISK_MODEL, type=$DISK_TYPE, size=${DISK_SIZE_GB}GB"
  fi
  
  # Build JSON
  SYSINFO_JSON=$(jq -n \
    --arg host "$HOSTNAME" \
    --arg cpu_model "$CPU_MODEL" \
    --arg cpu_vendor "${CPU_VENDOR:-}" \
    --arg cpu_socket "${CPU_SOCKET:-}" \
    --arg cpu_arch "${CPU_ARCH:-}" \
    --argjson cpu_cores "$CPU_CORES" \
    --argjson cpu_threads "$CPU_THREADS" \
    --argjson cpu_sockets "$CPU_SOCKETS" \
    --arg cpu_freq_base_mhz "${CPU_FREQ_BASE_MHZ:-}" \
    --arg cpu_freq_max_mhz "${CPU_FREQ_MAX_MHZ:-}" \
    --arg cpu_tdp_watts "${CPU_TDP_WATTS:-}" \
    --arg power_idle_watts "${POWER_IDLE_WATTS:-}" \
    --arg power_load_watts "${POWER_LOAD_WATTS:-}" \
    --arg cpu_cache_l1 "${CPU_CACHE_L1:-}" \
    --arg cpu_cache_l2 "${CPU_CACHE_L2:-}" \
    --arg cpu_cache_l3 "${CPU_CACHE_L3:-}" \
    --argjson mem_mb "$MEM_TOTAL_MB" \
    --arg mem_type "$MEM_TYPE" \
    --arg mem_form "${MEM_FORM_FACTOR:-}" \
    --arg mem_speed "${MEM_SPEED:-}" \
    --arg mem_channels "${MEM_CHANNELS:-}" \
    --argjson mem_slots_used "${MEM_SLOTS_USED:-0}" \
    --argjson mem_slots_total "${MEM_SLOTS_TOTAL:-0}" \
    --arg mem_ecc "${MEM_ECC:-}" \
    --argjson mem_banks "$MEM_BANKS_JSON" \
    --arg kernel "$KERNEL" \
    --arg os "$OS" \
    --arg virt "$VIRT_TYPE" \
    --argjson is_proxmox "$([[ "${IS_PROXMOX:-false}" == "true" ]] && echo "true" || echo "false")" \
    --arg pve_version "$PROXMOX_VERSION" \
    --arg pve_node "${PVE_NODE_NAME:-}" \
    --arg pve_cluster "${PVE_CLUSTER_NAME:-}" \
    --argjson pve_cluster_nodes "${PVE_CLUSTER_NODES:-0}" \
    --arg pve_subscription "${PVE_SUBSCRIPTION:-}" \
    --argjson pve_vm_count "${PVE_VM_COUNT:-0}" \
    --argjson pve_ct_count "${PVE_CT_COUNT:-0}" \
    --arg pve_storage "${PVE_STORAGE_INFO:-}" \
    --arg root_dev "$ROOT_DEV" \
    --arg disk_model "$DISK_MODEL" \
    --arg disk_type "$DISK_TYPE" \
    --argjson disk_size_gb "$DISK_SIZE_GB" \
    --arg disk_path "$DISK_PATH" \
    '{
      hostname: $host,
      cpu: {
        model: $cpu_model,
        vendor: $cpu_vendor,
        socket: $cpu_socket,
        architecture: $cpu_arch,
        cores: $cpu_cores,
        threads: $cpu_threads,
        sockets: $cpu_sockets,
        freq_base_mhz: $cpu_freq_base_mhz,
        freq_max_mhz: $cpu_freq_max_mhz,
        tdp_watts: $cpu_tdp_watts,
        cache: {
          l1: $cpu_cache_l1,
          l2: $cpu_cache_l2,
          l3: $cpu_cache_l3
        }
      },
      power: {
        idle_watts: $power_idle_watts,
        load_watts: $power_load_watts
      },
      memory: {
        total_mb: $mem_mb,
        type: $mem_type,
        form_factor: $mem_form,
        speed: $mem_speed,
        channels: $mem_channels,
        slots_used: $mem_slots_used,
        slots_total: $mem_slots_total,
        ecc: $mem_ecc,
        banks: $mem_banks
      },
      kernel: $kernel,
      os: $os,
      virtualization: $virt,
      is_proxmox: $is_proxmox,
      proxmox: {
        version: $pve_version,
        node_name: $pve_node,
        cluster_name: $pve_cluster,
        cluster_nodes: $pve_cluster_nodes,
        subscription: $pve_subscription,
        vm_count: $pve_vm_count,
        ct_count: $pve_ct_count,
        storage: $pve_storage
      },
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
  
  # Start power measurement in background during CPU benchmark
  local power_samples=()
  local power_pid=""
  if [[ -n "$RAPL_ENERGY_FILE" && -f "$RAPL_ENERGY_FILE" ]]; then
    # Sample power every 5 seconds during the test
    (
      local sample_interval=5
      local e_prev=$(cat "$RAPL_ENERGY_FILE" 2>/dev/null || echo 0)
      sleep $sample_interval
      while true; do
        local e_now=$(cat "$RAPL_ENERGY_FILE" 2>/dev/null || echo 0)
        if [[ $e_now -gt $e_prev ]]; then
          local diff=$((e_now - e_prev))
          local power=$(awk "BEGIN {printf \"%.1f\", $diff / ($sample_interval * 1000000)}")
          echo "$power" >> /tmp/proxmark-power-samples.txt
        fi
        e_prev=$e_now
        sleep $sample_interval
      done
    ) &
    power_pid=$!
  fi
  
  out="$(sysbench cpu --cpu-max-prime=20000 --threads="$threads" --time="$CPU_TIME" run 2>&1)"
  
  # Stop power measurement and calculate average
  if [[ -n "$power_pid" ]]; then
    kill "$power_pid" 2>/dev/null || true
    wait "$power_pid" 2>/dev/null || true
    
    if [[ -f /tmp/proxmark-power-samples.txt ]]; then
      POWER_LOAD_WATTS=$(awk '{ sum += $1; count++ } END { if (count > 0) printf "%.1f", sum/count; else print "0" }' /tmp/proxmark-power-samples.txt)
      rm -f /tmp/proxmark-power-samples.txt
      log_verbose "CPU load power: ${POWER_LOAD_WATTS}W (avg over test)"
    fi
  fi
  
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
  
  # Memory latency test (smaller block, random access pattern)
  log "Running Memory benchmark (latency, ${MEM_TIME}s)..."
  
  local lat_time=$((MEM_TIME / 2))
  [[ $lat_time -lt 5 ]] && lat_time=5
  
  out="$(sysbench memory \
    --memory-block-size=64 \
    --memory-total-size=100G \
    --memory-oper=read \
    --memory-access-mode=rnd \
    --time="$lat_time" \
    --threads=1 run 2>&1)"
  
  log_verbose "Sysbench latency output: $out"
  
  # Extract latency from sysbench output - try multiple patterns
  local lat_avg_ms=""
  
  # Pattern 1: Look for "avg:" line after "Latency (ms):"
  lat_avg_ms=$(echo "$out" | grep -A4 "Latency" | grep "avg:" | awk '{print $NF}' | head -1)
  
  # Pattern 2: Try awk on the whole output
  if [[ -z "$lat_avg_ms" || "$lat_avg_ms" == "0.00" ]]; then
    lat_avg_ms=$(echo "$out" | awk '/avg:/ {print $NF}' | head -1)
  fi
  
  # Pattern 3: Calculate from throughput - sysbench shows "X MiB/sec" or "X.XX MiB transferred"
  # Latency (ns) ≈ block_size / (throughput_bytes_per_sec)
  if [[ -z "$lat_avg_ms" || "$lat_avg_ms" == "0.00" || "$lat_avg_ms" == "0" ]]; then
    # Get MiB/sec from output
    local mib_per_sec=$(echo "$out" | grep -oE '[0-9]+\.[0-9]+ MiB/sec' | awk '{print $1}' | head -1)
    if [[ -n "$mib_per_sec" ]] && [[ "$mib_per_sec" != "0" ]]; then
      # block_size = 64 bytes, throughput in bytes/sec = MiB/sec * 1048576
      # time_per_op_ns = 64 / (mib_per_sec * 1048576) * 1e9
      # time_per_op_ms = 64 / (mib_per_sec * 1048576) * 1000
      lat_avg_ms=$(awk "BEGIN {printf \"%.6f\", 64 / ($mib_per_sec * 1048576) * 1000}")
    fi
  fi
  
  # Fallback: use total time / total operations
  if [[ -z "$lat_avg_ms" || "$lat_avg_ms" == "0" ]]; then
    local total_ops=$(echo "$out" | grep "Total operations:" | awk '{print $3}')
    local total_time=$(echo "$out" | grep "total time:" | awk '{print $3}' | sed 's/s//')
    if [[ -n "$total_ops" && -n "$total_time" && "$total_ops" != "0" ]]; then
      lat_avg_ms=$(awk "BEGIN {if ($total_ops > 0) printf \"%.6f\", ($total_time * 1000) / $total_ops; else print \"0\"}")
    fi
  fi
  
  # Ensure we have a valid number
  if [[ -z "$lat_avg_ms" ]] || ! [[ "$lat_avg_ms" =~ ^[0-9.]+$ ]]; then
    lat_avg_ms="0"
  fi
  
  MEM_LATENCY_MS="$lat_avg_ms"
  if [[ "$lat_avg_ms" != "0" ]]; then
    MEM_LATENCY_NS=$(awk "BEGIN {printf \"%.0f\", $lat_avg_ms * 1000000}")
  else
    MEM_LATENCY_NS="0"
  fi
  
  log_success "Memory latency: ${lat_avg_ms} ms avg"
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

run_network_benchmark() {
  # Only run if iperf server is specified
  if [[ -z "$IPERF_SERVER" ]]; then
    NET_BW_MBPS="0"
    NET_LATENCY_MS="0"
    SCORE_NET_BW=0
    SCORE_NET_LATENCY=0
    return
  fi
  
  # Parse server:port
  local server="${IPERF_SERVER%:*}"
  local port="${IPERF_SERVER##*:}"
  [[ "$port" == "$server" ]] && port="5201"  # Default port
  
  # Check if iperf3 is available
  if ! command -v iperf3 >/dev/null 2>&1; then
    log "Installing iperf3 for network benchmark..."
    run_as_root apt-get install -y iperf3 >/dev/null 2>&1 || {
      log_warning "Could not install iperf3, skipping network benchmark"
      NET_BW_MBPS="0"
      NET_LATENCY_MS="0"
      SCORE_NET_BW=0
      SCORE_NET_LATENCY=0
      return
    }
  fi
  
  local duration=$((DISK_RUNTIME / 3))
  [[ $duration -lt 10 ]] && duration=10
  
  log "Running Network benchmark (iperf3 to $server:$port, ${duration}s)..."
  
  # Run iperf3 test
  local out
  out=$(iperf3 -c "$server" -p "$port" -t "$duration" -J 2>&1) || {
    log_warning "iperf3 failed to connect to $server:$port"
    NET_BW_MBPS="0"
    NET_LATENCY_MS="0"
    SCORE_NET_BW=0
    SCORE_NET_LATENCY=0
    return
  }
  
  # Parse results
  if echo "$out" | jq -e '.end' >/dev/null 2>&1; then
    # Bandwidth in Mbps
    local bw_bps=$(echo "$out" | jq -r '.end.sum_sent.bits_per_second // 0')
    NET_BW_MBPS=$(awk "BEGIN {printf \"%.2f\", $bw_bps / 1000000}")
    
    # Retransmits (as a proxy for network quality)
    local retransmits=$(echo "$out" | jq -r '.end.sum_sent.retransmits // 0')
    
    log_success "Network bandwidth: ${NET_BW_MBPS} Mbps (retransmits: $retransmits)"
    
    # Score: 1 Mbps = 1 point
    SCORE_NET_BW=$(awk "BEGIN {printf \"%.0f\", $NET_BW_MBPS}")
  else
    log_warning "Failed to parse iperf3 output"
    NET_BW_MBPS="0"
    SCORE_NET_BW=0
  fi
  
  # Latency test (ping)
  log "Running Network latency test..."
  local ping_out
  ping_out=$(ping -c 10 -q "$server" 2>&1) || true
  NET_LATENCY_MS=$(echo "$ping_out" | awk -F'/' '/avg/ {print $5}' || echo "0")
  
  if [[ -n "$NET_LATENCY_MS" && "$NET_LATENCY_MS" != "0" ]]; then
    log_success "Network latency: ${NET_LATENCY_MS} ms"
    # Score: inverse of latency (lower latency = higher score)
    SCORE_NET_LATENCY=$(awk "BEGIN {if ($NET_LATENCY_MS > 0) printf \"%.0f\", 10000 / $NET_LATENCY_MS; else print 0}")
  else
    NET_LATENCY_MS="0"
    SCORE_NET_LATENCY=0
  fi
}

# === Score Calculation ===
# Proxmark Score System (larger scale like Geekbench)
# Scores are based on performance per unit, scaled for readability
# Higher = better

calculate_scores() {
  log_verbose "Calculating scores..."
  
  # CPU Scores - based on events/second
  # ~1000 e/s single-thread = 1000 points (typical modern CPU)
  SCORE_CPU_MULTI=$(awk "BEGIN {printf \"%.0f\", ${CPU_MULTI_EPS:-0}}")
  SCORE_CPU_SINGLE=$(awk "BEGIN {printf \"%.0f\", ${CPU_SINGLE_EPS:-0}}")
  
  # Memory Scores - based on MB/s
  # Scaled: 1 MB/s = 1 point
  SCORE_MEM_WRITE=$(awk "BEGIN {printf \"%.0f\", ${MEM_WRITE_MBS:-0}}")
  SCORE_MEM_READ=$(awk "BEGIN {printf \"%.0f\", ${MEM_READ_MBS:-0}}")
  
  # Memory Latency Score (if available) - inverse, lower is better
  # Convert to score where higher = better
  if [[ -n "${MEM_LATENCY_NS:-}" ]] && [[ "${MEM_LATENCY_NS:-0}" -gt 0 ]]; then
    SCORE_MEM_LATENCY=$(awk "BEGIN {printf \"%.0f\", 10000000 / ${MEM_LATENCY_NS}}")
  else
    SCORE_MEM_LATENCY=0
  fi
  
  # Disk Scores
  # IOPS: 1 IOPS = 1 point (4K random is typically 10K-500K)
  SCORE_DISK_RAND_IOPS=$(awk "BEGIN {printf \"%.0f\", ${DISK_RANDRW_IOPS_TOTAL:-0}}")
  SCORE_DISK_SEQ_READ_IOPS=$(awk "BEGIN {printf \"%.0f\", ${DISK_SEQ_READ_IOPS:-0}}")
  SCORE_DISK_SEQ_WRITE_IOPS=$(awk "BEGIN {printf \"%.0f\", ${DISK_SEQ_WRITE_IOPS:-0}}")
  
  # Bandwidth: 1 MB/s = 10 points (makes sequential scores comparable to IOPS)
  SCORE_DISK_RAND_BW=$(awk "BEGIN {printf \"%.0f\", (${DISK_RANDRW_BW_R_MB:-0} + ${DISK_RANDRW_BW_W_MB:-0}) * 10}")
  SCORE_DISK_SEQ_READ_BW=$(awk "BEGIN {printf \"%.0f\", ${DISK_SEQ_READ_MB:-0} * 10}")
  SCORE_DISK_SEQ_WRITE_BW=$(awk "BEGIN {printf \"%.0f\", ${DISK_SEQ_WRITE_MB:-0} * 10}")
  
  # Disk Latency Score (if available) - inverse, lower is better
  if [[ -n "${DISK_RANDRW_LAT_AVG_US:-}" ]] && [[ "${DISK_RANDRW_LAT_AVG_US:-0}" -gt 0 ]]; then
    SCORE_DISK_LATENCY=$(awk "BEGIN {printf \"%.0f\", 1000000 / ${DISK_RANDRW_LAT_AVG_US}}")
  else
    SCORE_DISK_LATENCY=0
  fi
  
  # Network Scores (if iperf was run)
  SCORE_NET_BW=${SCORE_NET_BW:-0}
  SCORE_NET_LATENCY=${SCORE_NET_LATENCY:-0}
  
  # Category Subtotals
  SCORE_CPU_TOTAL=$(awk "BEGIN {printf \"%.0f\", ($SCORE_CPU_MULTI + $SCORE_CPU_SINGLE)}")
  SCORE_MEM_TOTAL=$(awk "BEGIN {printf \"%.0f\", ($SCORE_MEM_WRITE + $SCORE_MEM_READ) / 100 + $SCORE_MEM_LATENCY}")
  SCORE_DISK_TOTAL=$(awk "BEGIN {printf \"%.0f\", $SCORE_DISK_RAND_IOPS + ($SCORE_DISK_SEQ_READ_BW + $SCORE_DISK_SEQ_WRITE_BW) / 10}")
  
  # Total Score (weighted for Proxmox workloads)
  # CPU: 20%, Memory: 20%, Disk: 60%
  SCORE_TOTAL=$(awk "BEGIN {
    cpu = ($SCORE_CPU_MULTI + $SCORE_CPU_SINGLE)
    mem = ($SCORE_MEM_WRITE + $SCORE_MEM_READ) / 100
    disk = $SCORE_DISK_RAND_IOPS + ($SCORE_DISK_SEQ_READ_BW + $SCORE_DISK_SEQ_WRITE_BW) / 20
    total = (cpu * 0.20) + (mem * 0.20) + (disk * 0.60)
    printf \"%.0f\", total
  }")
  
  log_verbose "Scores - CPU: $SCORE_CPU_MULTI/$SCORE_CPU_SINGLE, Mem: $SCORE_MEM_WRITE/$SCORE_MEM_READ"
  log_verbose "Scores - Disk IOPS: $SCORE_DISK_RAND_IOPS, BW: $SCORE_DISK_SEQ_READ_BW/$SCORE_DISK_SEQ_WRITE_BW"
  log_verbose "Total Score: $SCORE_TOTAL"
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
    --arg mem_latency_ms "${MEM_LATENCY_MS:-0}" \
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
    --argjson score_mem_write "${SCORE_MEM_WRITE:-0}" \
    --argjson score_mem_read "${SCORE_MEM_READ:-0}" \
    --argjson score_mem_latency "${SCORE_MEM_LATENCY:-0}" \
    --argjson score_disk_rand_iops "${SCORE_DISK_RAND_IOPS:-0}" \
    --argjson score_disk_seq_read "${SCORE_DISK_SEQ_READ_BW:-0}" \
    --argjson score_disk_seq_write "${SCORE_DISK_SEQ_WRITE_BW:-0}" \
    --argjson score_cpu_total "${SCORE_CPU_TOTAL:-0}" \
    --argjson score_mem_total "${SCORE_MEM_TOTAL:-0}" \
    --argjson score_disk_total "${SCORE_DISK_TOTAL:-0}" \
    --argjson score_total "${SCORE_TOTAL:-0}" \
    --arg net_bw_mbps "${NET_BW_MBPS:-0}" \
    --arg net_latency_ms "${NET_LATENCY_MS:-0}" \
    --argjson score_net_bw "${SCORE_NET_BW:-0}" \
    --argjson score_net_latency "${SCORE_NET_LATENCY:-0}" \
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
          },
          latency_ms: ($mem_latency_ms | tonumber)
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
        },
        network: {
          bandwidth_mbps: ($net_bw_mbps | tonumber),
          latency_ms: ($net_latency_ms | tonumber)
        }
      },
      scores: {
        cpu: {
          multi_thread: $score_cpu_multi,
          single_thread: $score_cpu_single,
          total: $score_cpu_total
        },
        memory: {
          write: $score_mem_write,
          read: $score_mem_read,
          latency: $score_mem_latency,
          total: $score_mem_total
        },
        disk: {
          random_iops: $score_disk_rand_iops,
          seq_read: $score_disk_seq_read,
          seq_write: $score_disk_seq_write,
          total: $score_disk_total
        },
        network: {
          bandwidth: $score_net_bw,
          latency: $score_net_latency
        },
        proxmark_score: $score_total
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
  if [[ -n "$PROXMOX_VERSION" ]]; then
    echo -e "  ${BOLD}Proxmox:${NC}      $PROXMOX_VERSION"
    if [[ -n "$PVE_CLUSTER_NAME" ]]; then
      echo -e "  ${BOLD}Cluster:${NC}      $PVE_CLUSTER_NAME ($PVE_CLUSTER_NODES nodes)"
    fi
    if [[ $PVE_VM_COUNT -gt 0 ]] || [[ $PVE_CT_COUNT -gt 0 ]]; then
      echo -e "  ${BOLD}Workloads:${NC}    $PVE_VM_COUNT VMs, $PVE_CT_COUNT containers"
    fi
    if [[ -n "$PVE_STORAGE_INFO" ]]; then
      echo -e "  ${BOLD}Storage:${NC}      $PVE_STORAGE_INFO"
    fi
  fi
  echo
  
  # CPU info section
  echo -e "${BOLD}${YELLOW}CPU${NC}"
  echo -e "${DIM}────────────────────────────────────────────────────────────────────────────${NC}"
  echo -e "  ${BOLD}Model:${NC}        $CPU_MODEL"
  [[ -n "$CPU_VENDOR" ]] && echo -e "  ${BOLD}Vendor:${NC}       $CPU_VENDOR"
  echo -e "  ${BOLD}Cores:${NC}        $CPU_CORES cores / $CPU_THREADS threads"
  echo -e "  ${BOLD}Sockets:${NC}      $CPU_SOCKETS"
  [[ -n "$CPU_SOCKET" ]] && echo -e "  ${BOLD}Socket:${NC}       $CPU_SOCKET"
  [[ -n "$CPU_ARCH" ]] && echo -e "  ${BOLD}Architecture:${NC} $CPU_ARCH"
  
  # Frequency info - show base and max on same line if both available
  if [[ -n "$CPU_FREQ_BASE_MHZ" && "$CPU_FREQ_BASE_MHZ" != "0" ]] && [[ -n "$CPU_FREQ_MAX_MHZ" && "$CPU_FREQ_MAX_MHZ" != "0" ]]; then
    echo -e "  ${BOLD}Frequency:${NC}    ${CPU_FREQ_BASE_MHZ} MHz base / ${CPU_FREQ_MAX_MHZ} MHz boost"
  elif [[ -n "$CPU_FREQ_BASE_MHZ" && "$CPU_FREQ_BASE_MHZ" != "0" ]]; then
    echo -e "  ${BOLD}Base Freq:${NC}    ${CPU_FREQ_BASE_MHZ} MHz"
  elif [[ -n "$CPU_FREQ_MAX_MHZ" && "$CPU_FREQ_MAX_MHZ" != "0" ]]; then
    echo -e "  ${BOLD}Max Freq:${NC}     ${CPU_FREQ_MAX_MHZ} MHz"
  fi
  
  # Power information
  if [[ -n "$POWER_IDLE_WATTS" && "$POWER_IDLE_WATTS" != "0" ]] || [[ -n "$POWER_LOAD_WATTS" && "$POWER_LOAD_WATTS" != "0" ]]; then
    local power_info=""
    if [[ -n "$CPU_TDP_WATTS" && "$CPU_TDP_WATTS" != "0" ]]; then
      power_info="TDP: ${CPU_TDP_WATTS}W"
    fi
    if [[ -n "$POWER_IDLE_WATTS" && "$POWER_IDLE_WATTS" != "0" ]]; then
      [[ -n "$power_info" ]] && power_info+=", "
      power_info+="Idle: ${POWER_IDLE_WATTS}W"
    fi
    if [[ -n "$POWER_LOAD_WATTS" && "$POWER_LOAD_WATTS" != "0" ]]; then
      [[ -n "$power_info" ]] && power_info+=", "
      power_info+="Load: ${POWER_LOAD_WATTS}W"
    fi
    echo -e "  ${BOLD}Power:${NC}        $power_info"
  fi
  
  # Cache info
  if [[ -n "$CPU_CACHE_L1" || -n "$CPU_CACHE_L2" || -n "$CPU_CACHE_L3" ]]; then
    local cache_info=""
    [[ -n "$CPU_CACHE_L1" ]] && cache_info+="L1: $CPU_CACHE_L1"
    [[ -n "$CPU_CACHE_L2" ]] && cache_info+="${cache_info:+, }L2: $CPU_CACHE_L2"
    [[ -n "$CPU_CACHE_L3" ]] && cache_info+="${cache_info:+, }L3: $CPU_CACHE_L3"
    echo -e "  ${BOLD}Cache:${NC}        $cache_info"
  fi
  echo
  
  # Memory info section
  local mem_gb=$((MEM_TOTAL_MB / 1024))
  echo -e "${BOLD}${YELLOW}MEMORY${NC}"
  echo -e "${DIM}────────────────────────────────────────────────────────────────────────────${NC}"
  echo -e "  ${BOLD}Total:${NC}        ${mem_gb} GB (${MEM_TOTAL_MB} MB)"
  if [[ "$MEM_TYPE" != "unknown" && -n "$MEM_TYPE" ]]; then
    local mem_type_display="$MEM_TYPE"
    [[ -n "$MEM_FORM_FACTOR" ]] && mem_type_display="$MEM_FORM_FACTOR $MEM_TYPE"
    [[ -n "$MEM_ECC" ]] && mem_type_display="$mem_type_display $MEM_ECC"
    echo -e "  ${BOLD}Type:${NC}         $mem_type_display"
  fi
  [[ -n "$MEM_SPEED" ]] && echo -e "  ${BOLD}Speed:${NC}        $MEM_SPEED"
  [[ -n "$MEM_CHANNELS" ]] && echo -e "  ${BOLD}Config:${NC}       $MEM_CHANNELS (${MEM_SLOTS_USED}/${MEM_SLOTS_TOTAL} slots)"
  
  # Show per-bank details if available
  if [[ ${#MEM_BANKS[@]} -gt 0 ]]; then
    echo -e "  ${BOLD}Banks:${NC}"
    for bank_info in "${MEM_BANKS[@]}"; do
      IFS='|' read -r slot size vendor product clock <<< "$bank_info"
      local bank_detail="    ${slot}: ${size}"
      [[ -n "$vendor" && "$vendor" != "Unknown" ]] && bank_detail+=" ($vendor"
      [[ -n "$product" && "$product" != "Unknown" ]] && bank_detail+=" $product"
      [[ -n "$vendor" && "$vendor" != "Unknown" ]] && bank_detail+=")"
      [[ -n "$clock" ]] && bank_detail+=" @ ${clock}"
      echo -e "$bank_detail"
    done
  fi
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
  
  # Calculate combined MB/s for random r/w
  local randrw_total_mb=$(awk "BEGIN {printf \"%.2f\", ${DISK_RANDRW_BW_R_MB:-0} + ${DISK_RANDRW_BW_W_MB:-0}}")
  
  echo -e "${DIM}┌────────────┬─────────────────────┬──────────────┬──────────────┬──────────┐${NC}"
  echo -e "${DIM}│${NC}${BOLD} Component  ${DIM}│${NC}${BOLD} Test                ${DIM}│${NC}${BOLD} IOPS         ${DIM}│${NC}${BOLD} Throughput   ${DIM}│${NC}${BOLD} Score    ${DIM}│${NC}"
  echo -e "${DIM}├────────────┼─────────────────────┼──────────────┼──────────────┼──────────┤${NC}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC}              ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "CPU" "Multi-thread" "${CPU_MULTI_EPS} e/s" "${SCORE_CPU_MULTI}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC}              ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "CPU" "Single-thread" "${CPU_SINGLE_EPS} e/s" "${SCORE_CPU_SINGLE}"
  echo -e "${DIM}├────────────┼─────────────────────┼──────────────┼──────────────┼──────────┤${NC}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC}              ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "Memory" "Write" "${MEM_WRITE_MBS} MB/s" "${SCORE_MEM_WRITE}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC}              ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "Memory" "Read" "${MEM_READ_MBS} MB/s" "${SCORE_MEM_READ}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC}              ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "Memory" "Latency" "${MEM_LATENCY_MS:-0} ms" "${SCORE_MEM_LATENCY}"
  echo -e "${DIM}├────────────┼─────────────────────┼──────────────┼──────────────┼──────────┤${NC}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC} %12s ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "Disk" "4K Random R/W" "${DISK_RANDRW_IOPS_TOTAL}" "${randrw_total_mb} MB/s" "${SCORE_DISK_RAND_IOPS}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC} %12s ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "Disk" "Sequential Read" "${DISK_SEQ_READ_IOPS:-0}" "${DISK_SEQ_READ_MB} MB/s" "${SCORE_DISK_SEQ_READ_BW}"
  printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC} %12s ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "Disk" "Sequential Write" "${DISK_SEQ_WRITE_IOPS:-0}" "${DISK_SEQ_WRITE_MB} MB/s" "${SCORE_DISK_SEQ_WRITE_BW}"
  
  # Network section (only if iperf was run)
  if [[ -n "$IPERF_SERVER" ]] && [[ "${NET_BW_MBPS:-0}" != "0" ]]; then
    echo -e "${DIM}├────────────┼─────────────────────┼──────────────┼──────────────┼──────────┤${NC}"
    printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC}              ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "Network" "Bandwidth" "${NET_BW_MBPS} Mbps" "${SCORE_NET_BW}"
    printf "${DIM}│${NC} %-10s ${DIM}│${NC} %-19s ${DIM}│${NC}              ${DIM}│${NC} %10s   ${DIM}│${NC} ${GREEN}%8s${NC} ${DIM}│${NC}\n" "Network" "Latency" "${NET_LATENCY_MS} ms" "${SCORE_NET_LATENCY}"
  fi
  
  echo -e "${DIM}└────────────┴─────────────────────┴──────────────┴──────────────┴──────────┘${NC}"
  echo
  
  # Category subtotals
  echo -e "${DIM}Category Scores: CPU: ${SCORE_CPU_TOTAL:-0} | Memory: ${SCORE_MEM_TOTAL:-0} | Disk: ${SCORE_DISK_TOTAL:-0}${NC}"
  echo
  
  # Total score - make it stand out
  echo -e "${CYAN}╭──────────────────────────────────────────────────────────────────────────╮${NC}"
  printf "${CYAN}│${NC}                         ${BOLD}PROXMARK SCORE: ${GREEN}%-8s${NC}                        ${CYAN}│${NC}\n" "${SCORE_TOTAL}"
  echo -e "${CYAN}╰──────────────────────────────────────────────────────────────────────────╯${NC}"
  echo
  
  # File paths
  echo -e "${DIM}📁 JSON saved:${NC} $RESULT_JSON"
  echo -e "${DIM}📋 Log file:${NC} $LOG_FILE"
  if [[ "$DEBUG" == "true" ]]; then
    echo -e "${DIM}🔍 Debug file:${NC} $DEBUG_FILE"
  fi
  echo -e "${DIM}🌐 Result URL:${NC} ${YELLOW}(coming soon - proxmark.io)${NC}"
  echo
  
  # Write summary to log file for later reference
  write_summary_to_log
}

write_summary_to_log() {
  local randrw_total_mb=$(awk "BEGIN {printf \"%.2f\", ${DISK_RANDRW_BW_R_MB:-0} + ${DISK_RANDRW_BW_W_MB:-0}}")
  
  local randrw_total_mb=$(awk "BEGIN {printf \"%.2f\", ${DISK_RANDRW_BW_R_MB:-0} + ${DISK_RANDRW_BW_W_MB:-0}}")
  
  {
    echo ""
    echo "=========================================="
    echo "BENCHMARK RESULTS SUMMARY"
    echo "=========================================="
    echo ""
    echo "SYSTEM INFORMATION"
    echo "----------------------------------------"
    echo "  Hostname:     $HOSTNAME"
    echo "  OS:           $OS"
    echo "  Kernel:       $KERNEL"
    if [[ -n "$PROXMOX_VERSION" ]]; then
      echo "  Proxmox:      $PROXMOX_VERSION"
      [[ -n "$PVE_CLUSTER_NAME" ]] && echo "  Cluster:      $PVE_CLUSTER_NAME ($PVE_CLUSTER_NODES nodes)"
      [[ $PVE_VM_COUNT -gt 0 || $PVE_CT_COUNT -gt 0 ]] && echo "  Workloads:    $PVE_VM_COUNT VMs, $PVE_CT_COUNT containers"
      [[ -n "$PVE_STORAGE_INFO" ]] && echo "  Storage:      $PVE_STORAGE_INFO"
    fi
    echo ""
    echo "CPU"
    echo "----------------------------------------"
    echo "  Model:        $CPU_MODEL"
    echo "  Cores:        $CPU_CORES cores / $CPU_THREADS threads"
    echo "  Sockets:      $CPU_SOCKETS"
    [[ -n "$CPU_FREQ_BASE_MHZ" && "$CPU_FREQ_BASE_MHZ" != "0" ]] && echo "  Base Freq:    ${CPU_FREQ_BASE_MHZ} MHz"
    [[ -n "$CPU_FREQ_MAX_MHZ" && "$CPU_FREQ_MAX_MHZ" != "0" ]] && echo "  Max Freq:     ${CPU_FREQ_MAX_MHZ} MHz"
    echo ""
    echo "MEMORY"
    echo "----------------------------------------"
    echo "  Total:        $((MEM_TOTAL_MB / 1024)) GB (${MEM_TOTAL_MB} MB)"
    if [[ "$MEM_TYPE" != "unknown" && -n "$MEM_TYPE" ]]; then
      local log_mem_type="$MEM_TYPE"
      [[ -n "$MEM_ECC" ]] && log_mem_type="$MEM_TYPE $MEM_ECC"
      echo "  Type:         $log_mem_type"
    fi
    [[ -n "$MEM_SPEED" ]] && echo "  Speed:        $MEM_SPEED"
    [[ -n "$MEM_CHANNELS" ]] && echo "  Config:       $MEM_CHANNELS (${MEM_SLOTS_USED}/${MEM_SLOTS_TOTAL} slots)"
    echo ""
    echo "STORAGE"
    echo "----------------------------------------"
    echo "  Test Path:    $DISK_PATH"
    echo "  Device:       $ROOT_DEV"
    [[ -n "$DISK_MODEL" ]] && echo "  Model:        $DISK_MODEL"
    echo "  Type:         ${DISK_TYPE^^}"
    [[ $DISK_SIZE_GB -gt 0 ]] && echo "  Size:         ${DISK_SIZE_GB} GB"
    echo ""
    echo "BENCHMARK RESULTS"
    echo "----------------------------------------"
    printf "  %-22s %12s %12s %8s\n" "Test" "IOPS" "Throughput" "Score"
    echo "  ----------------------------------------------------------------"
    printf "  %-22s %12s %12s %8s\n" "CPU Multi-thread" "-" "${CPU_MULTI_EPS} e/s" "$SCORE_CPU_MULTI"
    printf "  %-22s %12s %12s %8s\n" "CPU Single-thread" "-" "${CPU_SINGLE_EPS} e/s" "$SCORE_CPU_SINGLE"
    printf "  %-22s %12s %12s %8s\n" "Memory Write" "-" "${MEM_WRITE_MBS} MB/s" "$SCORE_MEM_WRITE"
    printf "  %-22s %12s %12s %8s\n" "Memory Read" "-" "${MEM_READ_MBS} MB/s" "$SCORE_MEM_READ"
    printf "  %-22s %12s %12s %8s\n" "Memory Latency" "-" "${MEM_LATENCY_MS:-0} ms" "$SCORE_MEM_LATENCY"
    printf "  %-22s %12s %12s %8s\n" "Disk 4K Random R/W" "$DISK_RANDRW_IOPS_TOTAL" "${randrw_total_mb} MB/s" "$SCORE_DISK_RAND_IOPS"
    printf "  %-22s %12s %12s %8s\n" "Disk Seq Read" "${DISK_SEQ_READ_IOPS:-0}" "${DISK_SEQ_READ_MB} MB/s" "$SCORE_DISK_SEQ_READ_BW"
    printf "  %-22s %12s %12s %8s\n" "Disk Seq Write" "${DISK_SEQ_WRITE_IOPS:-0}" "${DISK_SEQ_WRITE_MB} MB/s" "$SCORE_DISK_SEQ_WRITE_BW"
    if [[ -n "$IPERF_SERVER" ]] && [[ "${NET_BW_MBPS:-0}" != "0" ]]; then
      printf "  %-22s %12s %12s %8s\n" "Network Bandwidth" "-" "${NET_BW_MBPS} Mbps" "$SCORE_NET_BW"
      printf "  %-22s %12s %12s %8s\n" "Network Latency" "-" "${NET_LATENCY_MS} ms" "$SCORE_NET_LATENCY"
    fi
    echo ""
    echo "Category Scores: CPU: ${SCORE_CPU_TOTAL:-0} | Memory: ${SCORE_MEM_TOTAL:-0} | Disk: ${SCORE_DISK_TOTAL:-0}"
    echo ""
    echo "=========================================="
    echo "PROXMARK SCORE: $SCORE_TOTAL"
    echo "=========================================="
    echo ""
    echo "JSON saved: $RESULT_JSON"
    echo "Log file:   $LOG_FILE"
    echo ""
  } >> "$LOG_FILE" 2>/dev/null || true
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

init_logging() {
  # Initialize log file with header
  {
    echo "=========================================="
    echo "Proxmark v$VERSION - Benchmark Log"
    echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Run ID: $RUN_UUID"
    echo "=========================================="
  } > "$LOG_FILE" 2>/dev/null || true
  
  # Initialize debug file if in debug mode
  if [[ "$DEBUG" == "true" ]]; then
    {
      echo "=========================================="
      echo "Proxmark v$VERSION - Debug Log"
      echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "Run ID: $RUN_UUID"
      echo "=========================================="
      echo ""
      echo "=== System Information ==="
      echo "Hostname: $(hostname)"
      echo "Kernel: $(uname -r)"
      echo "OS: $(cat /etc/os-release 2>/dev/null | head -5)"
      echo ""
      echo "=== CPU Info ==="
      head -30 /proc/cpuinfo 2>/dev/null || true
      echo ""
      echo "=== Memory Info ==="
      cat /proc/meminfo 2>/dev/null | head -20 || true
      echo ""
      echo "=== Block Devices ==="
      lsblk 2>/dev/null || true
      echo ""
      echo "=== Disk Free ==="
      df -h 2>/dev/null || true
      echo ""
      echo "=== Mount Points ==="
      mount 2>/dev/null | grep -E '^/dev' || true
      echo ""
      echo "=== DMI Memory ==="
      dmidecode -t memory 2>/dev/null | head -50 || echo "(dmidecode not available or no permission)"
      echo ""
      echo "=========================================="
      echo ""
    } > "$DEBUG_FILE" 2>/dev/null || true
  fi
}

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
  
  # Initialize logging first
  init_logging
  
  print_banner
  debug_system_info
  
  check_dependencies
  collect_sysinfo
  
  # Discover available storage paths
  discover_storage_paths
  
  run_cpu_benchmark
  run_mem_benchmark
  run_disk_benchmark
  run_network_benchmark
  
  calculate_scores
  generate_json
  
  print_summary
  
  # Prompt for additional disks if available and interactive
  if [[ "$ALL_DISKS" == "true" ]]; then
    # Benchmark all discovered storage
    for path in "${DISCOVERED_STORAGE[@]:1}"; do
      echo
      log "Benchmarking additional storage: $path"
      DISK_PATH="$path"
      run_disk_benchmark
    done
  else
    prompt_additional_disks
    
    # Benchmark additional paths if user selected any
    if [[ ${#ADDITIONAL_DISK_PATHS[@]} -gt 0 ]]; then
      for path in "${ADDITIONAL_DISK_PATHS[@]}"; do
        echo
        log "Benchmarking additional storage: $path"
        DISK_PATH="$path"
        run_disk_benchmark
        # TODO: Store results per disk
      done
    fi
  fi
  
  upload_results
  
  log_success "Benchmark complete!"
}

main "$@"



