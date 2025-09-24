#!/bin/bash

# =============================================================================
# Remote Host Management Script
# =============================================================================
#
# A lightweight alternative to Ansible for parallel command execution across
# multiple remote hosts using SSH. This script provides a simple and efficient
# way to manage multiple servers simultaneously.
#
# Key Features:
# - Minimal dependencies (requires only SSH and bash)
# - Fast parallel execution
# - Simple to use (no special configuration needed)
# - Uses standard SSH key authentication
# - Optional jump host support
#
# Requirements:
# - Configured SSH access to target hosts (SSH keys)
# - Bash 4+ on local host
# - Sudo privileges on target hosts (if required by executed script)
#
# Use Cases:
# 1. System updates across server farm:
#    ./script_remote.sh --hosts '{web,app,db}serv{1..50}' --processes 32 --script update.sh
#
# 2. Access through jump host:
#    ./script_remote.sh --hosts 'internal-host' --script check.sh --jumpbox gateway.example.com
#
# 3. Generate status report:
#    ./script_remote.sh --hosts 'webserv{1..10}' --script status.sh > report.txt
#

# Function to display help message
show_help() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  --processes <NUM>           Number of parallel processes (required for parallel mode)
  --script <name.sh>          Script to execute (required)
  --hosts <hostname>          Target hosts pattern (required)
  --jumpbox <hostname>        Jump host for SSH connections (optional)
  --help                      Show this help message

Examples:
    ${0} --hosts '{a,l,d}serv{1..50}' --processes 32 --script script_file.sh > report.txt
    ${0} --hosts 'tserv1' --script script_file.sh --jumpbox jumphost.example.com
EOF
}

# Execute SSH command on remote host
# Arguments:
#   $1 - target hostname
#   $2 - script path to execute
#   $3 - optional jump host
ssh_command() {
  local host="${1}"
  local script="${2}"
  local jumpbox="${3:-}"
  local ssh_opts=(-T -o BatchMode=yes -o ConnectTimeout=30
    -o StrictHostKeyChecking=yes -o PasswordAuthentication=no)

  if [[ -n "${jumpbox}" ]]; then
    ssh_opts+=(-J "${jumpbox}")
  fi

  ssh "${ssh_opts[@]}" "${host}" "bash -s" <"${script}"
}

# Generate execution report for a single host
# Output format: "hostname, command_output"
# Arguments:
#   $1 - hostname
#   $2 - script path
#   $3 - optional jump host
report_entry() {
  local host="${1}"
  local script="${2}"
  local jumpbox="${3:-}"

  retdata_ssh_command=$(ssh_command "${host}" "${script}" "${jumpbox}" | tr '\n' ' ')
  printf "%s, %s\n" "${host}" "${retdata_ssh_command}"
}

# Configuration defaults
PROCESSES="4"
SCRIPT=""
HOSTS=""
JUMPBOX=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --processes)
    PROCESSES="$2"
    shift 2
    ;;
  --script)
    SCRIPT="$2"
    shift 2
    ;;
  --hosts)
    HOSTS="$2"
    shift 2
    ;;
  --jumpbox)
    JUMPBOX="$2"
    shift 2
    ;;
  --help)
    show_help
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
done

# Validate required arguments
if [[ -z "${SCRIPT}" ]]; then
  echo "Error: --script is required"
  show_help
  exit 1
fi

if [[ -z "${HOSTS}" ]]; then
  echo "Error: --hosts is required"
  show_help
  exit 1
fi

# Check if script file exists and is readable
if [[ ! -f "${SCRIPT}" ]]; then
  echo "Error: Script file '${SCRIPT}' not found"
  exit 1
fi

if [[ ! -r "${SCRIPT}" ]]; then
  echo "Error: Script file '${SCRIPT}' is not readable"
  exit 1
fi

# Validate processes is a number
if ! [[ "${PROCESSES}" =~ ^[0-9]+$ ]] || [[ "${PROCESSES}" -eq 0 ]]; then
  echo "Error: --processes must be a positive integer"
  exit 1
fi

# Main execution logic
export -f ssh_command report_entry
export JUMPBOX # Required for subshells

# Process hosts in parallel using xargs
for i in $(eval echo ${HOSTS}); do echo "${i}"; done |
  xargs -P "${PROCESSES}" -I {} bash -c "report_entry {} '${SCRIPT}' '${JUMPBOX}'"
