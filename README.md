# Privex's Shell Core

A library of shell functions designed to ease the development of shell scripts written for both `bash` and `zsh`.

**UNDER CONSTRUCTION**

# Usage

**Automatically install ShellCore if it's missing on the first run**

This is the recommended method, as it means you don't have to bundle ShellCore with small scripts.

Below is a short snippet that you can place at the start of your script or main shell file, which will:

 - Check if ShellCore is installed at all - locally or globally
    - If not, attempt to automatically install ShellCore if we failed to find an installation. The installation script is fully
      unattended - errors are sent to **stderr**.
    - If the installation fails, then output an error message to **stderr** and exit the script with a non-zero return code.
 - Attempt to load ShellCore from `~/.pv-shcore` (local) first, then fallback to `/usr/local/share/pv-shcore` (global)

```bash
# Error handling function for ShellCore
_sc_fail() { >&2 echo "Failed to load or install Privex ShellCore..." && exit 1; }
# If `load.sh` isn't found in the user install / global install, then download and run the auto-installer
# from Privex's CDN.
[[ -f "${HOME}/.pv-shcore/load.sh" ]] || [[ -f "/usr/local/share/pv-shcore/load.sh" ]] || \
    { curl -fsS https://cdn.privex.io/github/shell-core/install.sh | bash >/dev/null; } || _sc_fail

# Attempt to load the local install of ShellCore first, then fallback to global install if it's not found.
[[ -d "${HOME}/.pv-shcore" ]] && source "${HOME}/.pv-shcore/load.sh" || \
    source "/usr/local/share/pv-shcore/load.sh" || _sc_fail

# Optionally, you may wish to run `autoupdate_shellcore` after loading it. This will quietly update ShellCore to
# the latest version. 
# To avoid auto-updates causing slow load times, by default they'll only be triggered at most once per week.
# You can also use `update_shellcore` from within your script to force a ShellCore update.
autoupdate_shellcore
```

**Bundling with your application**

You can also simply `git clone https://github.com/Privex/shell-core.git` and place it within your project, or use a Git Submodule.

If you're concerned about ShellCore updates potentially breaking your script, then this may be the preferred option - as any other
shellscript project (or a user) on the system could trigger updates to the local/global ShellCore installation.

# Features

**Bash Error Handler**

![Screenshot of Error Handler](http://cdn.privex.io/github/shell-core/shellcore_errorhandler.png)

Included with ShellCore's various helpers, is a bash module in `base/trap.bash` - which adds python-like error handling
to any bash script, with tracebacks, the file and line number of the problematic code, etc.

It's known to work on both Mac OSX as well as Ubuntu Linux Server, and may work on other OS's too.

The error handling module is based on a snippet posted to Stack Overflow by Luca Borrione - Source: https://stackoverflow.com/a/13099228

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

