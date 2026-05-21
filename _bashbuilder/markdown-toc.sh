#!/usr/bin/env bash
# markdown-toc.sh — generate a markdown Table of Contents from a .md file
# Usage: ./markdown-toc.sh file.md
# Outputs markdown that can be piped into a markdown converter.

FILE="${1:?No file specified as first argument}"

declare -a TOC
declare -A TOC_MAP
CODE_BLOCK=0
FRONT_MATTER=0
FM_SEEN=0

while IFS= read -r LINE; do

    # Handle front matter (--- delimiters at top of file)
    if [[ "$LINE" == "---" ]]; then
        if [[ $FM_SEEN -eq 0 ]]; then
            FRONT_MATTER=1
            FM_SEEN=1
            continue
        elif [[ $FRONT_MATTER -eq 1 ]]; then
            FRONT_MATTER=0
            continue
        fi
    fi
    [[ $FRONT_MATTER -eq 1 ]] && continue

    # Handle fenced code blocks (skip headings inside them)
    if [[ "$LINE" =~ ^\`\`\` ]]; then
        CODE_BLOCK=$(( (CODE_BLOCK + 1) % 2 ))
        continue
    fi
    [[ $CODE_BLOCK -eq 1 ]] && continue

    # Collect headings (skip "Table of Contents" itself)
    if [[ "$LINE" =~ ^#{1,} ]] && [[ "$LINE" != *"Table of Contents"* ]]; then
        TOC+=("$LINE")
    fi

done < "$FILE"

[[ ${#TOC[@]} -eq 0 ]] && exit 0

echo -e "## Table of Contents\n"

for LINE in "${TOC[@]}"; do
    # Indentation by heading level
    case "$LINE" in
        '#####'*) echo -n "        - " ;;
        '####'*)  echo -n "      - "   ;;
        '###'*)   echo -n "    - "     ;;
        '##'*)    echo -n "  - "       ;;
        '#'*)     echo -n "- "         ;;
    esac

    # Build anchor link
    LINK="$LINE"
    # Strip markdown links [text](url) → [text]
    if grep -qE '\[.*\]\(.*\)' <<< "$LINK"; then
        LINK=$(sed 's/\(\]\)\((.*)\)/\1/' <<< "$LINK")
    fi
    # Remove heading hashes and leading spaces
    LINK=$(sed 's/^#\+[[:space:]]*//' <<< "$LINK")
    # Lowercase, keep alphanumeric/spaces/hyphens, spaces → hyphens
    LINK=$(echo "$LINK" | tr '[:upper:]' '[:lower:]' | tr -dc '[:alnum:] -' | tr ' ' '-' | tr -s '-')

    # Strip hashes from display text
    DISPLAY="${LINE#"${LINE%%[! ]*}"}"   # trim leading spaces
    DISPLAY="${DISPLAY#\#}"
    DISPLAY="${DISPLAY#\#}"
    DISPLAY="${DISPLAY#\#}"
    DISPLAY="${DISPLAY#\#}"
    DISPLAY="${DISPLAY#\#}"
    DISPLAY="${DISPLAY# }"

    # Handle duplicate headings with -N suffix
    INDEX="${TOC_MAP[$LINE]:-}"
    if [[ -n "$INDEX" ]]; then
        INDEX=$(( INDEX + 1 ))
        TOC_MAP[$LINE]=$INDEX
        echo "[$DISPLAY](#${LINK}-${INDEX})"
    else
        TOC_MAP[$LINE]=0
        echo "[$DISPLAY](#${LINK})"
    fi
done
