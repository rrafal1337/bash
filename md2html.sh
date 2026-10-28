#!/usr/bin/env bash
#
# Convert a Markdown/text file to a complete HTML page with UTF-8 charset.
# Usage: md2html.sh SOURCE_FILE
# Output: SOURCE_FILE with the extension replaced by .html, next to the source.

set -euo pipefail

LANG_CODE="pl"   # value for <html lang="...">, change if needed

if [[ $# -ne 1 ]]; then
    echo "Usage: ${0##*/} SOURCE_FILE" >&2
    exit 1
fi

src="$1"

if [[ ! -f "$src" ]]; then
    echo "Error: file not found: $src" >&2
    exit 1
fi

if ! command -v markdown_py >/dev/null 2>&1; then
    echo "Error: markdown_py not found in PATH" >&2
    exit 1
fi

dir="$(dirname -- "$src")"
base="$(basename -- "$src")"
name="${base%.*}"            # file name without extension
out="$dir/$name.html"

# Escape characters special in HTML for use in <title>
title="${name//&/&amp;}"
title="${title//</&lt;}"
title="${title//>/&gt;}"

{
    printf '<!DOCTYPE html>\n'
    printf '<html lang="%s">\n' "$LANG_CODE"
    printf '<head>\n'
    printf '<meta charset="utf-8">\n'
    printf '<title>%s</title>\n' "$title"
    printf '</head>\n'
    printf '<body>\n'
    markdown_py "$src" -e utf-8 -o html
    printf '</body>\n'
    printf '</html>\n'
} > "$out"

echo "Created: $out"

