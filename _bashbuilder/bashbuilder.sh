#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════╗
# ║  bashbuilder — simple bash static site builder       ║
# ║  Usage:  ./bashbuilder.sh            # build all     ║
# ║          ./bashbuilder.sh src/topic/page.md          ║
# ╚══════════════════════════════════════════════════════╝
set -euo pipefail

# ── paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$SCRIPT_DIR/src"       # markdown sources: src/[topic]/file.md
TEMPLATE="$SCRIPT_DIR/template.html"
WORK_DIR="$SCRIPT_DIR/.build"   # temp dir; auto-cleaned

# ── helpers ──────────────────────────────────────────────────────────────────
die()  { echo "Error: $*" >&2; exit 1; }
info() { echo "  → $*"; }

check_deps() {
    # markdown converter: prefer 'markdown', fall back to pandoc
    if command -v markdown &>/dev/null; then
        MD_CMD="markdown"
    elif command -v pandoc &>/dev/null; then
        MD_CMD="pandoc -f markdown -t html"
    else
        die "Install 'markdown' or 'pandoc'.\n  Debian/Ubuntu: sudo apt install markdown\n  macOS:         brew install markdown"
    fi

    command -v python3 &>/dev/null || die "python3 required (for relative path calculation)"
    [[ -f "$TEMPLATE" ]] || die "Template not found: $TEMPLATE"
    [[ -d "$SRC_DIR"  ]] || die "Source directory not found: $SRC_DIR\n  Create it and place your .md files there."
}

# Convert markdown file (or stdin) to HTML
md2html() { $MD_CMD "$@"; }

# Compute relative path from dir $1 to file/dir $2 (both absolute)
relpath() { python3 -c "import os; print(os.path.relpath('$2', '$1'))"; }

# Get last-modified date — git first, then mtime, then today
file_date() {
    local f="$1"
    if command -v git &>/dev/null && git -C "$SITE_ROOT" rev-parse --git-dir &>/dev/null 2>&1; then
        local d
        d=$(git -C "$SITE_ROOT" log -1 --format="%ad" --date=format:"%Y-%m-%d" -- "$f" 2>/dev/null || true)
        [[ -n "$d" ]] && { echo "$d"; return; }
    fi
    # macOS: stat -f %Sm -t %Y-%m-%d; Linux: date -r
    date -r "$f" +"%Y-%m-%d" 2>/dev/null || date +"%Y-%m-%d"
}

# Parse a single front-matter key from a .md file.
# Front matter is the optional block between the first two --- lines.
parse_fm() {
    local file="$1" key="$2"
    awk -v key="$key" '
        /^---/ { fm = 1 - fm; next }
        fm && $0 ~ "^"key":" {
            sub(/^[^:]+:[[:space:]]*/, ""); print; exit
        }
    ' "$file"
}

# Strip front matter, return body markdown
strip_fm() {
    awk '/^---/{ fm = 1 - fm; next } !fm { print }' "$1"
}

# ── site-wide nav builder ────────────────────────────────────────────────────
# Scans all .md sources and builds the <nav> for the header.
# $1 = current source .md (absolute)   $2 = output dir (absolute)
build_site_nav() {
    local current_src="$1"
    local out_dir="$2"
    local nav last_topic="" href title

    nav='<nav id="site-nav">'$'\n'

    # ── index / home ──
    if [[ -f "$SRC_DIR/index.md" ]]; then
        href=$(relpath "$out_dir" "$SITE_ROOT")/index.html
        # clean up accidental double-slashes
        href="${href//\/\///}"
        title=$(parse_fm "$SRC_DIR/index.md" "title")
        [[ -z "$title" ]] && title="home"
        if [[ "$current_src" == "$SRC_DIR/index.md" ]]; then
            nav+="  <span class=\"active\">$title</span>"$'\n'
        else
            nav+="  <a href=\"$href\">$title</a>"$'\n'
        fi
    fi

    # ── topic pages ──
    while IFS= read -r -d '' md; do
        [[ "$md" == "$SRC_DIR/index.md" ]] && continue

        local rel="${md#"$SRC_DIR"/}"   # e.g. arch-usb/intro.md
        local topic="${rel%%/*}"         # arch-usb
        local name="${rel##*/}"          # intro.md
        local slug="${name%.md}"

        local page_out_dir="$SITE_ROOT/posts/$topic"
        href=$(relpath "$out_dir" "$page_out_dir")/$slug.html
        href="${href//\/\///}"

        title=$(parse_fm "$md" "title")
        [[ -z "$title" ]] && title="$slug"

        # separator between topics
        if [[ "$topic" != "$last_topic" ]]; then
            [[ -n "$last_topic" ]] && nav+="  <hr>"$'\n'
            last_topic="$topic"
        fi

        if [[ "$md" == "$current_src" ]]; then
            nav+="  <span class=\"active\">$title</span>"$'\n'
        else
            nav+="  <a href=\"$href\">$title</a>"$'\n'
        fi
    done < <(find "$SRC_DIR" -name "*.md" ! -name "index.md" -print0 | sort -z)

    nav+='</nav>'
    echo "$nav"
}

# ── template injection (multiline-safe) ──────────────────────────────────────
# Replace {{PLACEHOLDER}} in $1 with contents of file $2; write to $3.
inject() {
    local src_file="$1" placeholder="$2" content_file="$3" out_file="$4"
    awk -v ph="{{$placeholder}}" -v cf="$content_file" '
        index($0, ph) {
            while ((getline line < cf) > 0) print line
            close(cf)
            next
        }
        { print }
    ' "$src_file" > "$out_file"
}

# Replace a simple single-line {{PLACEHOLDER}} with a plain string value
inject_str() {
    local file="$1" placeholder="$2" value="$3"
    # Use | as sed delimiter to avoid issues with paths containing /
    sed -i "s|{{$placeholder}}|$value|g" "$file"
}

# ── page builder ─────────────────────────────────────────────────────────────
build_page() {
    local src="$1"
    [[ -f "$src" ]] || die "Source not found: $src"

    local rel="${src#"$SRC_DIR"/}"       # topic/page.md  or  index.md
    local topic="${rel%%/*}"
    local name="${rel##*/}"
    local slug="${name%.md}"

    # Determine output path
    local out_dir out_file
    if [[ "$rel" == "index.md" ]]; then
        out_dir="$SITE_ROOT"
        out_file="$out_dir/index.html"
    else
        out_dir="$SITE_ROOT/posts/$topic"
        out_file="$out_dir/$slug.html"
    fi
    mkdir -p "$out_dir"

    echo "Building: $rel"

    # ── gather content ──
    local body_md title date_updated css_path 
	# hero ## TODO once I managed to fix the hardcoded ArchOS USB heading, add hero to the line above

    body_md=$(strip_fm "$src")

    # Title: front-matter → first h1 in body → slug
    title=$(parse_fm "$src" "title")
    if [[ -z "$title" ]]; then
        title=$(echo "$body_md" | awk '/^# /{sub(/^# +/,""); print; exit}')
    fi
    [[ -z "$title" ]] && title="$slug"

    date_updated=$(file_date "$src")
    css_path=$(relpath "$out_dir" "$SITE_ROOT/css")/main.css
    #TODO generate the "ArchOS" hero that is hardcoded in ASCII font - take $topic as input string
    #hero=$(while read -r LINE; do printf '%s\n' "$LINE"; done < "$SRC_DIR/$topic") 
    #TODO Fix this; this is meant to read the 

    # ── convert markdown → HTML ──
    local body_html toc_md toc_html site_nav_html

    body_html=$(echo "$body_md" | md2html)

    # Transform fenced code blocks (<code> → styled div)
    body_html=$(echo "$body_html" \
        | sed -e 's|<code>|<div class="code nomargin"><span class="prompt"># </span>|g' \
              -e 's|</code>|</div>|g')

    # In-page TOC (from the markdown-toc.sh helper)
    toc_md=$("$SCRIPT_DIR/markdown-toc.sh" "$src")
    toc_html="<nav id=\"toc-nav\">"$'\n'
    toc_html+=$(echo "$toc_md" | md2html)
    toc_html+=$'\n'"</nav>"

    # Site-wide nav
    site_nav_html=$(build_site_nav "$src" "$out_dir")

    # ── write content to temp files ──
    local tmp="$WORK_DIR/$$"
    echo "$body_html"     > "${tmp}_body.html"
    echo "$toc_html"      > "${tmp}_toc.html"
    echo "$site_nav_html" > "${tmp}_sitenav.html"

    # ── inject into template (chained: each pass reads previous output) ──
    cp "$TEMPLATE" "${tmp}_0.html"

    inject "${tmp}_0.html" "SITE_NAV" "${tmp}_sitenav.html" "${tmp}_1.html"
    inject "${tmp}_1.html" "TOC_NAV"  "${tmp}_toc.html"     "${tmp}_2.html"
    inject "${tmp}_2.html" "BODY"     "${tmp}_body.html"    "${tmp}_3.html"

    # Single-line substitutions (title, css path, date) — safe with inject_str
    cp "${tmp}_3.html" "${tmp}_4.html"
    inject_str "${tmp}_4.html" "TITLE"        "$title"
    inject_str "${tmp}_4.html" "CSS_PATH"     "$css_path"
    inject_str "${tmp}_4.html" "DATE_UPDATED" "$date_updated"
    # inject_str "${tmp}_4.html" "HERO" "$hero"

    mv "${tmp}_4.html" "$out_file"

    # clean up temp files for this page
    rm -f "${tmp}"_*.html

    info "→ $out_file"
}

# ── main ─────────────────────────────────────────────────────────────────────
check_deps
mkdir -p "$WORK_DIR"

if [[ $# -eq 0 ]]; then
    # Build everything
    echo "bashbuilder: building all pages..."
    count=0
    while IFS= read -r -d '' f; do
        build_page "$f"
        (( count++ )) || true
    done < <(find "$SRC_DIR" -name "*.md" -print0 | sort -z)
    [[ $count -eq 0 ]] && echo "No .md files found in $SRC_DIR"
    echo "Done — $count page(s) built."
else
    # Build a single file
    # Accept both relative (src/topic/page.md) and absolute paths
    target="$1"
    [[ "$target" != /* ]] && target="$SCRIPT_DIR/$target"
    build_page "$target"
    echo "Done."
fi

rmdir "$WORK_DIR" 2>/dev/null || true
