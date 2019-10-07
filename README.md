# Privex's Shell Core

A library of shell functions designed to ease the development of shell scripts written for both `bash` and `zsh`.

**UNDER CONSTRUCTION**

# Usage

**Automatically install ShellCore if it's missing on the first run**

This is the recommended method, as it means you don't have to bundle ShellCore with small scripts.

Below is a four ( 4 ) line snippet that you can place at the start of your script or main shell file, which will
in order:

 - Search for ShellCore in the user's home directory at `~/.pv-shcore` and load it from there if found.
 - If there's no local user install, then fallback to a global ShellCore installation in `/usr/local/share/pv-shcore` 
 - Attempt to automatically install ShellCore if we failed to find an installation. The installation script is fully
   unattended, and shouldn't output any messages unless there are errors.
     - If the install was successful, it should have generated a script in `/tmp/pv-shellcore` which simply sources the `load.sh`
       file from where-ever ShellCore was installed - avoiding the need for your script to re-attempt to locate the installation.
 - If the installation fails, then output an error message to **stderr** and exit the script with a non-zero return code.

```bash
# Attempt to load Privex ShellCore from the local or global install directory, if not found, try to install it.
{ [[ -d "${HOME}/.pv-shcore" ]] && source "${HOME}/.pv-shcore/load.sh"; } || \
{ [[ -d "/usr/local/share/pv-shcore" ]] && source "/usr/local/share/pv-shcore/load.sh"; } || \
{ curl -fsS https://cdn.privex.io/github/shell-core/install.sh -O - | bash && source /tmp/pv-shellcore; } || \ 
{ >&2 echo "Failed to load or install Privex ShellCore..."; exit 1 }

# Optionally, you may wish to run `autoupdate_shellcore` after loading it. This will quietly update ShellCore to
# the latest version. 
# To avoid auto-updates causing slow load times, by default they'll only be triggered at most once per week.
# You can also use `update_shellcore` from within your script to force a ShellCore update.
autoupdate_shellcore
```

**Bundling with your application**

You can also simply `git clone https://github.com/Privex/shellcore.git` and place it within your project, or use a Git Submodule.

If you're concerned about ShellCore updates potentially breaking your script, then this may be the preferred option - as any other
shellscript project (or a user) on the system could trigger updates to the local/global ShellCore installation.

# License

```
+===================================================+
|                 © 2019 Privex Inc.                |
|               https://www.privex.io               |
+===================================================+
|                                                   |
|        Privex ShellCore                           |
|                                                   |
|        Core Developer(s):                         |
|                                                   |
|          (+)  Chris (@someguy123) [Privex]        |
|                                                   |
+===================================================+

Copyright (C) 2019    Privex Inc. (https://www.privex.io)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

```

