Frontend
-----------------------------
- [x] fix font size for name-ascii art
- [ ] learn how to insert gists into webpage:
	- https://codersblock.Com/blog/customizing-github-gists
- [ ] bashbuilder how to folder /bash-ssg
  - [ ] document and explain
- [ ] all packages.list and post-install scripts into /post-install
  - get all flatpak from install script : `grep -oP "(?<=flatpak install flathub ).*" eigene-WIP-post-install-arch.sh`
- [ ] 3d CSS for fun xD
- [ ] BUG: Navbar generates each FILE not per Folder with Submenu entries
- [ ] BUG: Table of Contents does not always render correctly. Maybe try giving Claude those 3 example files and ask him to generate a BashSSG from there? Might be more efficient...
	
Bash SSG Builder
-----------------------------
- [x] add {date} updated variable and parse on each rebuild
- [·] add header navigation builder (BUGGY)
  - [x] get all html files (absolute paths) and insert as <a> in correct position
  - [ ] if filename = current file -> set link as "active"
  - [ ] if links from same folder -> add <hr> under last link
- [ ] figure out how to create the ASCII font dynamically
  - [ ] apply font-matter string to this and insert the newly generated "hero" into `<pre>` html-files
