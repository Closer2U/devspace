---
title: The Readme
topic: bashbuilder
---

# BashSSG

`bashbuilder.sh` - A simple bash static site generator. No config files, no dependencies
beyond `markdown` (or `pandoc`) and `python3`.

> [!WARNING]
> 🚧 WiP: website for dev stuff (https://closer2u.github.io/devspace)

> [!IMPORTANT] Creds
> Original theme found on [mags.zone](https://mags.zone)


> Shoutout for this awesome design!

<br>

## Directory layout

<pre style="display: inline-block; white-space:pre-wrap">
```
your-site/
├── _bashbuilder/
│   ├── bashbuilder.sh      ← the builder
│   ├── markdown-toc.sh     ← TOC helper (called automatically)
│   ├── template.html       ← your site's HTML shell
│   └── src/                ← put your markdown here
│       ├── index.md        → builds to /index.html
│       └── arch-usb/       → topic folder
│           ├── intro.md    → builds to /posts/arch-usb/intro.html
│           └── iso.md      → builds to /posts/arch-usb/iso.html
├── posts/                  ← generated; do not edit by hand
├── css/
│   └── main.css
└── index.html              ← generated from src/index.md
```
</pre>

<br> 

## Writing pages

Each `.md` file may begin with optional **front matter**:

```markdown
---
title: My Page Title
---

# My Page Title

Content here...
```

- `title` — used in `<title>`, site nav, and TOC.  
  Falls back to the first `# h1` in the document, then the filename.

Without front matter the file still builds fine.

## Building

```bash
cd _bashbuilder

# Build everything
./bashbuilder.sh

# Build one file
./bashbuilder.sh src/arch-usb/intro.md
```

Output is written directly to the correct location — no manual move needed.

## Template placeholders

| Placeholder        | What it becomes                                |
|--------------------|------------------------------------------------|
| `{{TITLE}}`        | Page title (front matter → h1 → filename)      |
| `{{CSS_PATH}}`     | Relative path to `css/main.css` (auto)         |
| `{{SITE_NAV}}`     | Site-wide `<nav>` with links to all pages      |
| `{{TOC_NAV}}`      | In-page `<nav>` with links to headings         |
| `{{BODY}}`         | Converted markdown body                        |
| `{{DATE_UPDATED}}` | Last-modified date (git log → mtime → today)   |

## Dependencies

| Tool       | Purpose                 | Install                          |
|------------|-------------------------|----------------------------------|
| `markdown` | Markdown → HTML         | `sudo apt install markdown`      |
| `pandoc`   | Fallback converter      | `sudo apt install pandoc`        |
| `python3`  | Relative path calc      | Usually pre-installed            |
| `git`      | Accurate modified dates | Optional; mtime used as fallback |

## Inter-page links

Links between pages in the same topic folder work as plain relative refs:

```markdown
See the [Live ISO](iso.html) guide.
```

Links from one topic to another:

```markdown
See [arch-usb intro](../arch-usb/intro.html).
```

Links to the root from a post:

```markdown
[Home](../../index.html)
```

The CSS path is computed automatically per page, so `{{CSS_PATH}}` in the
template always resolves correctly regardless of nesting depth.
