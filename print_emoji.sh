#!/bin/bash

# Define Unicode ranges for emoji-related blocks
ranges=(
  "1F600 1F64F"  # Emoticons
  "1F300 1F5FF"  # Misc Symbols and Pictographs
  "1F680 1F6FF"  # Transport and Map Symbols
  "1F900 1F9FF"  # Supplemental Symbols and Pictographs
  "1FA70 1FAFF"  # Symbols and Pictographs Extended-A
  "2600 26FF"    # Miscellaneous Symbols
  "2700 27BF"    # Dingbats
  "1F1E6 1F1FF"  # Regional Indicator Symbols (Flags)
)

# Print header
echo "🧾 Emoji and Emoji-style Unicode Characters:"
echo

# Iterate through each range
for range in "${ranges[@]}"; do
  IFS=' ' read -r start end <<< "$range"

  for codepoint in $(seq $((16#$start)) $((16#$end))); do
    # Convert codepoint to character using printf
    printf "\\U$(printf '%08x' $codepoint) "
  done
  echo -e "\n"
done
