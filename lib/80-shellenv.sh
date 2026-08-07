# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
#
# Phase: shellenv — the sysadmin toolbox, and the shell that makes it usable.
#
# ⚠️ WHY THIS PHASE EXISTS AT ALL. zsh has been in packages/dnf-core.txt since
# M1 and was never configured or made anybody's login shell; starship has been
# installed since M3 and was never initialised. Both are the most reliable
# shape of "forgotten, not decided" this project has: a package that is present
# and the one line that makes it do something missing. bluez, gnome-keyring and
# udisks2 were the same, and each of them was a bug.
#
# ⚠️ NOTHING HERE STARTS A SERVICE. It installs binaries, writes two files in
# $HOME and changes one field in /etc/passwd.
phase_shellenv() {
    section "Shell and tools"

    mapfile -t pkgs < <(read_list dnf-sysadmin.txt)
    step "${#pkgs[@]} packages"
    # `weak` rather than `noweak`: several of these are metapackage-ish and
    # their recommendations are the parts people expect (bind-utils, sysstat).
    dnf_install weak "${pkgs[@]}" || warn "some tools failed — see above"

    # ------------------------------------------------------------------ zshrc
    #
    # ⚠️ A SYMLINK, like the shell configuration in lib/60-shell.sh. A copy
    # would mean a `git pull` silently not reaching the file everybody is
    # actually using, which is the whole class of fault this repository keeps
    # finding in itself.
    #
    # ⚠️ AND AN EXISTING ~/.zshrc IS NEVER OVERWRITTEN. It is somebody's file.
    # It is moved aside once, with its name said out loud, so nothing is lost
    # and nobody has to guess where it went.
    if [[ -L "$HOME/.zshrc" ]]; then
        ln -sfn "$REPO_DIR/dotfiles/zsh/zshrc" "$HOME/.zshrc"
        ok ".zshrc linked"
    elif [[ -e "$HOME/.zshrc" ]]; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.before-buchhwin"
        ln -sfn "$REPO_DIR/dotfiles/zsh/zshrc" "$HOME/.zshrc"
        warn "your .zshrc was kept as ~/.zshrc.before-buchhwin"
        warn "  anything you want back goes in ~/.zshrc.local, which is sourced last"
    else
        ln -sfn "$REPO_DIR/dotfiles/zsh/zshrc" "$HOME/.zshrc"
        ok ".zshrc linked"
    fi

    # ------------------------------------------------------- the login shell
    #
    # ⚠️ THE FILE ALONE DOES NOTHING. Without this, ~/.zshrc sits there and the
    # account still logs into bash — which is exactly the state this machine was
    # in, with zsh installed for four milestones.
    #
    # ⚠️ `sudo chsh -s <shell> <user>` FIRST, and a bare `chsh` only as the
    # fallback. Plain `chsh` makes the account authenticate to itself, and on a
    # machine where the password is managed elsewhere — or where PAM has just
    # been changed, which lib/70-services.sh does — that prompt can fail with no
    # useful message.
    local want=/usr/bin/zsh
    if [[ ! -x "$want" ]]; then
        warn "zsh is not installed — the login shell was left alone"
    elif [[ "$(getent passwd "$USER" | cut -d: -f7)" == "$want" ]]; then
        ok "zsh is already the login shell"
    elif sudo -n chsh -s "$want" "$USER" 2>/dev/null \
         || sudo chsh -s "$want" "$USER" 2>/dev/null \
         || chsh -s "$want" 2>/dev/null; then
        ok "zsh is the login shell — it applies at the next login"
    else
        warn "could not change the login shell. Run it yourself:"
        warn "  sudo chsh -s $want $USER"
    fi

    # ------------------------------------------------------------ the PATH
    #
    # ⚠️ ~/.local/bin FOR NON-LOGIN SHELLS TOO. Fedora's /etc/profile.d adds it
    # only for login shells, so a terminal opened from the desktop did not have
    # it — anything installed with `pip --user`, or dropped in by hand, was
    # simply not found. ~/.zshrc adds it as well; this covers the programs that
    # read the environment rather than starting a shell.
    mkdir -p "$HOME/.local/bin" "$CONFIG_HOME/environment.d"
    if [[ ! -f "$CONFIG_HOME/environment.d/10-buchhwin-path.conf" ]]; then
        printf 'PATH=%s/.local/bin:${PATH}\n' "$HOME" \
            > "$CONFIG_HOME/environment.d/10-buchhwin-path.conf"
        ok "$HOME/.local/bin is on the PATH"
    fi
}
