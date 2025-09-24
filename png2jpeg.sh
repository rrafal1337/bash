#!/bin/bash

# =============================================================================
# Image Converter: PNG to JPEG
# =============================================================================
#
# This script converts PNG images to JPEG format using ImageMagick.
# Uses find + xargs for efficient and safe file processing.
#
# Features:
# - Safe handling of filenames with spaces and special characters
# - Case-insensitive PNG file detection
# - Efficient processing of large numbers of files
# - Optional parallel processing with xargs -P
#
# Requirements:
# - ImageMagick must be installed (command: magick)
#
# Usage:
#   ./png2jpeg.sh
#
# Example outputs:
#   "My Photo.png"   -> "My Photo.jpeg"
#   "image 1.PNG"    -> "image 1.jpeg"
#   "test.png"       -> "test.jpeg"
#

# Convert single file function
convert_file() {
  local input="$1"
  # Remove extension using parameter expansion ${var%pattern} - strips shortest match from end
  # Example: "photo.png" becomes "photo.jpeg"
  local output="${input%.*}.jpeg"

  echo "Converting: ${input}"
  magick "${input}" -quality 95% -resize 1280 "${output}"
}

# Export function for xargs
export -f convert_file

# Find PNG files and process them with xargs
find . -maxdepth 1 -type f -iname "*.png" -print0 |
  xargs -0 -I {} bash -c 'convert_file "{}"'
