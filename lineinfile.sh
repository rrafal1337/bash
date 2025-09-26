#!/bin/bash

# =============================================================================
# Line in File Script - Key-Value Pair Manager
# =============================================================================
#
# This script manages key-value pairs in a configuration file.
# It either updates existing values or adds new key-value pairs.
#
# Similar to Ansible's lineinfile module but in pure bash.
#

# Configuration variables
FILE="your_file.txt" # Target file to modify
KEY="your_key"       # Key to search for
VALUE="your_value"   # Value to set for the key

# Check if the key exists using grep:
# -q : quiet mode (no output)
# ^  : match start of line
# =  : literal equals sign
if grep -q "^$KEY=" "$FILE"; then
  # Key exists - modify the line using sed:
  # -i    : edit file in place
  # s/    : substitute command
  # ^     : match start of line
  # .*    : match any characters until end of line
  # /     : delimiter between search and replace
  sed -i "s/^$KEY=.*/$KEY=$VALUE/" "$FILE"
else
  # Key doesn't exist - append new line:
  # >> : append to file without overwriting
  echo "$KEY=$VALUE" >>"$FILE"
fi
