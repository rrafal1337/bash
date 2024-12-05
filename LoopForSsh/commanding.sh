#!/bin/bash

ssh_command() {
ssh -o ConnectTimeout=2 -o PasswordAuthentication=no ${1} ${2} | tr '\n' ' '
}

report_entry() {
retdata_ssh_command=$(ssh_command ${1} "hostname -f ; date ; uname -a")
printf "%s|%s\n" "${1}" "${retdata_ssh_command}"
}

# Main
case "${1}" in 
  single)
    report_entry "${2}"
    ;;
  pararell)
    for i in $(eval echo ${2}); do echo "${i}"; done | xargs -P ${3} -I REPL ${0} single REPL
    ;;
  *)
    echo "Run this script with command: ${0} pararell '{a,l,d}serv{1..50}' 32 > report.txt"
    echo "Run this script with command: ${0} single aserv1 > report.txt"
    echo "Syntax: ${0} <single|pararell> '<pattern>' <number_of_processes>"
    ;; 
esac
