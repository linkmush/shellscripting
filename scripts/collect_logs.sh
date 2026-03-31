#!/usr/bin/env bash
# collect_logs.sh
# Samla systemdata och kör grundläggande härdningskontroller (icke-destruktivt)

set -euo pipefail
IFS=$'\n\t'

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR=""
DEFAULT_OUT="submission/out-${TIMESTAMP}"
VERBOSE=0

usage() {
  cat <<EOF
Usage: $0 [-o output_dir] [-a] [-v] [-h]
  -o DIR   Output directory (default: ${DEFAULT_OUT})
  -a       Run all checks and collect common logs
  -v       Verbose
  -h       This help
EOF
}

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${OUT_DIR}/run.log"; }
die() { log "ERROR: $*"; exit 1; }

collect_file_if_exists() {
  local src="$1" dstdir="$2"
  if [ -e "$src" ]; then
    mkdir -p "$dstdir"
    cp -a "$src" "$dstdir/" || log "Could not copy $src"
  fi
}

collect_logs() {
  log "Collecting logs to ${OUT_DIR}/logs"
  mkdir -p "${OUT_DIR}/logs"

  collect_file_if_exists /var/log/auth.log "${OUT_DIR}/logs"
  collect_file_if_exists /var/log/secure "${OUT_DIR}/logs"
  collect_file_if_exists /var/log/syslog "${OUT_DIR}/logs"
  collect_file_if_exists /var/log/messages "${OUT_DIR}/logs"

  if command -v dmesg >/dev/null 2>&1; then
    dmesg > "${OUT_DIR}/logs/dmesg.txt" || true
  fi

  # Paketlista (best-effort)
  if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -l > "${OUT_DIR}/packages-dpkg.txt" || true
  elif command -v rpm >/dev/null 2>&1; then
    rpm -qa > "${OUT_DIR}/packages-rpm.txt" || true
  fi

  uname -a > "${OUT_DIR}/system-uname.txt" || true
  ps aux > "${OUT_DIR}/ps-aux.txt" || true
}

check_ssh_root_login() {
  local cfg=/etc/ssh/sshd_config
  if [ -f "$cfg" ]; then
    local val
    val=$(grep -Ei '^\s*PermitRootLogin' "$cfg" | awk '{print $2}' || true)
    echo "PermitRootLogin: ${val:-(not-set)}" > "${OUT_DIR}/checks/ssh_root_login.txt"
  fi
}

check_world_writable() {
  find / -xdev -type f -perm -0002 -printf '%p\n' 2>/dev/null | head -n 500 > "${OUT_DIR}/checks/world_writable.txt" || true
}

count_suid_files() {
  find / -xdev -type f -perm -4000 -ls 2>/dev/null | wc -l > "${OUT_DIR}/checks/suid_count.txt" || true
}

check_pending_updates() {
  mkdir -p "${OUT_DIR}/checks"
  if command -v apt >/dev/null 2>&1; then
    apt list --upgradable 2>/dev/null > "${OUT_DIR}/checks/apt_upgradable.txt" || true
  elif command -v yum >/dev/null 2>&1; then
    yum check-update > "${OUT_DIR}/checks/yum_check_update.txt" || true
  elif command -v zypper >/dev/null 2>&1; then
    zypper list-updates > "${OUT_DIR}/checks/zypper_updates.txt" || true
  else
    echo "No known package manager found (apt/yum/zypper)" > "${OUT_DIR}/checks/package_manager_unknown.txt"
  fi
}

run_cis_basic_checks() {
  log "Running basic CIS-like checks"
  mkdir -p "${OUT_DIR}/checks"
  check_ssh_root_login
  check_world_writable
  count_suid_files
  check_pending_updates
}

archive_results() {
  local outtar="${OUT_DIR}.tar.gz"
  tar -czf "$outtar" -C "$(dirname "$OUT_DIR")" "$(basename "$OUT_DIR")" || die "Could not create archive"
  log "Created archive: $outtar"
}

# Parse args
ALL=0
while getopts ":o:avh" opt; do
  case ${opt} in
    o) OUT_DIR="$OPTARG" ;;
    a) ALL=1 ;;
    v) VERBOSE=1 ;;
    h) usage; exit 0 ;;
    :) die "Option -$OPTARG requires an argument." ;;
    \?) die "Invalid option: -$OPTARG" ;;
  esac
done
shift $((OPTIND -1))

OUT_DIR=${OUT_DIR:-$DEFAULT_OUT}
mkdir -p "${OUT_DIR}"
log "Output directory: ${OUT_DIR}"

# Run
collect_logs
run_cis_basic_checks
archive_results
log "Finished. Results in ${OUT_DIR}"

exit 0
