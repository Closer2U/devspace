#!/bin/bash -e

parse(){
cp input.md build
cd build
markdown input.md > body.html
../markdown-toc.sh input.md > _tmp-toc.md
markdown _tmp-toc.md > navigation.html             
rm _tmp-toc.md
echo "</nav>" >> navigation.html                                                           # add </nav> at end of file
sed -i '1 s/^.*$/<nav>/' navigation.html                                                   # replace first line which is Table of Contents with <nav>
NAVIGATION=$(cat navigation.html)
TITEL=$(echo `cat body.html | grep h1` | sed -nE 's/<h1>(.*)<\/h1>/\1/p')

# TODO create title as ascii art and add as pre
# TODO add to header-nav neue Seite und update sie überall

sed -i -e 's@<code>@<div class="code nomargin"><span class="prompt"># </span>@g' body.html # fix fenced code blocks
sed -i -e 's@<\/code>@<\/div>@g' body.html
BODY=$(cat body.html)

cp ../template.html .
mv template.html post.html
awk -i inplace -v input="$NAVIGATION" 'NR == 1, /{{NAVIGATION}}/ { sub(/{{NAVIGATION}}/, input) } 1' post.html
awk -i inplace -v input="$TITEL" 'NR == 1, /{{TITEL}}/ { sub(/{{TITEL}}/, input) } 1' post.html
awk -i inplace -v input="$BODY" 'NR == 1, /{{BODY}}/ { sub(/{{BODY}}/, input) } 1' post.html
rm input.md body.html navigation.html
mv post.html ${TITEL// /_}.html
mv ${TITEL// /_}.html ../output


#TODO tidy post.html > post-tidy.html

}




check_markdown(){
# Markdown conversion with multiple fallbacks
if command -v markdown &> /dev/null; then
    echo "markdown installed"
elif command -v pandoc &> /dev/null; then
    echo "pandoc installed"
else
    echo "Error: Install either 'markdown' or 'pandoc'"
    echo "Debian/Ubuntu: sudo apt install markdown pandoc"
    echo "macOS: brew install markdown pandoc"
    exit 1
fi
}

check_tidy(){
if command -v tidy &> /dev/null; then
    echo "tidy installed"
else
    echo "Error: Prettier for formatting html not installed"
    echo "Debian/Ubuntu: sudo apt install tidy"
    exit 1
fi
}

check_template(){
# Check if a template file exists
TEMPLATE_FILE="template.html"
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template file '$TEMPLATE_FILE' not found." >&2
  exit 1
fi

# Process all Markdown files in the current directory
#cd build
#find . -name "*.${MARKDOWN_EXTENSION}" -print0 | while IFS= read -r -d $'\0' file; do
#  parse "$file"
#done
}

check_markdown
#check_tidy
check_template
parse

