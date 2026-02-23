#!/bin/bash
# lib/log.sh — Logging infrastructure for cac_for_linux_distros
#
# Provides: log_init, log_info, log_warn, log_error, log_success,
#           log_section, log_cmd
#
# All functions write color-coded output to the terminal and simultaneously
# append plain-text records to the persistent log file opened by log_init.
# No set -euo pipefail here — inherited from bash/install.sh or bash/uninstall.sh.

# Guard each readonly to allow safe re-sourcing in BATS
# (BATS setup() calls source before each test; re-declaring a readonly is a fatal error).
[[ -v RED     ]] || readonly RED='\033[0;31m'
[[ -v GREEN   ]] || readonly GREEN='\033[0;32m'
[[ -v YELLOW  ]] || readonly YELLOW='\033[1;33m'
[[ -v CYAN    ]] || readonly CYAN='\033[0;36m'
[[ -v MAGENTA ]] || readonly MAGENTA='\033[0;35m'
[[ -v NC      ]] || readonly NC='\033[0m'

_CAC_LOG_FILE=""

log_init() {
    # Create the timestamped log file and write a header.
    # Must be called once before any other log_* function.
    _CAC_LOG_FILE="/var/log/cac_for_linux_distros_$(date +%Y%m%d_%H%M%S).log"
    printf "# cac_for_linux_distros log — %s\n" "$(date)" > "$_CAC_LOG_FILE"
    printf "# User: %s — Running as: %s\n" "${SUDO_USER:-}" "$(whoami)" >> "$_CAC_LOG_FILE"
    printf "\n" >> "$_CAC_LOG_FILE"
    log_info "Log file: $_CAC_LOG_FILE"
}

log_info() {
    printf "${YELLOW}[INFO]  ${NC}%s\n" "$*"
    echo "[INFO]  $*" >> "$_CAC_LOG_FILE"
}

log_warn() {
    printf "${MAGENTA}[WARN]  ${NC}%s\n" "$*"
    echo "[WARN]  $*" >> "$_CAC_LOG_FILE"
}

log_error() {
    printf "${RED}[ERROR] ${NC}%s\n" "$*" >&2
    echo "[ERROR] $*" >> "$_CAC_LOG_FILE"
}

log_success() {
    printf "${GREEN}[OK]    ${NC}%s\n" "$*"
    echo "[OK]    $*" >> "$_CAC_LOG_FILE"
}

log_section() {
    local bar="────────────────────────────────────────"
    printf "${CYAN}%s\n  %s\n%s${NC}\n" "$bar" "$*" "$bar"
    printf "%s\n  %s\n%s\n" "$bar" "$*" "$bar" >> "$_CAC_LOG_FILE"
}

log_cmd() {
    # Runs a command and logs its complete stdout+stderr to the log file.
    # Returns the exit status of the command.
    # Usage: log_cmd command arg1 arg2 ...
    #
    # The || pattern prevents set -e from exiting before s is assigned.
    # Callers that expect success use: if ! log_cmd ...; then ...; fi
    echo "[CMD]   $*" >> "$_CAC_LOG_FILE"
    local s=0
    "$@" >> "$_CAC_LOG_FILE" 2>&1 || s=$?
    echo "[EXIT]  $s" >> "$_CAC_LOG_FILE"
    return "$s"
}
