#!/usr/bin/env bash
# Install the sway / Regolith 3 copycat desktop from this directory onto
# Ubuntu 26.04: apt packages from packages.txt, then the config directories,
# helper scripts and wallpapers copied into $HOME.
#
# Runs as the normal user; sudo is used for apt only. Nothing under $HOME is
# ever deleted: a destination that already exists and differs from the repo
# copy stops the script before anything is touched, and --overwrite moves each
# such path to <path>.bak.<timestamp> before the repo copy is installed.
set -euo pipefail

SELF_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
TS=$(date +%Y%m%d-%H%M%S)
DRY_RUN=0
SKIP_PACKAGES=0
OVERWRITE=0

usage() {
    cat <<USAGE
Usage: ${0##*/} [--dry-run] [--skip-packages] [--overwrite]

  --dry-run        Show what would be done without changing anything.
  --skip-packages  Do not run apt; only install the configuration files.
  --overwrite      Replace destinations that already exist and differ, after
                   moving each one to <path>.bak.<timestamp>.
  -h, --help       Show this help.
USAGE
}

for arg in "$@"; do
    case $arg in
        --dry-run)       DRY_RUN=1 ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        --overwrite)     OVERWRITE=1 ;;
        -h|--help)       usage; exit 0 ;;
        *)               usage >&2; exit 2 ;;
    esac
done

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
run()  { printf '  + %s\n' "$*"; (( DRY_RUN )) || "$@"; }

# Units: each one is copied as a whole. Directories under config/ go to
# ~/.config, scripts under bin/ go to ~/.local/bin one file at a time (that
# directory is shared with other tools), and the wallpapers go to
# ~/.local/share/backgrounds.
UNIT_SRC=()
UNIT_DST=()
for d in "$SELF_DIR"/config/*/; do
    d=${d%/}
    [[ -d $d ]] || continue
    UNIT_SRC+=("$d"); UNIT_DST+=(".config/${d##*/}")
done
for f in "$SELF_DIR"/bin/*; do
    [[ -f $f ]] || continue
    UNIT_SRC+=("$f"); UNIT_DST+=(".local/bin/${f##*/}")
done
UNIT_SRC+=("$SELF_DIR/backgrounds/lascaille"); UNIT_DST+=(".local/share/backgrounds/lascaille")

# Commands the sway config, i3blocks blocks and helper scripts call.
COMMANDS=(
    sway swaymsg swaynag swaybg swayidle swaylock Xwayland
    foot rofi i3blocks swaync swaync-client swayosd-server swayosd-client
    grim slurp wl-copy kanshi nwg-displays
    playerctl playerctld pavucontrol wpctl
    nm-applet nm-connection-editor nmcli blueman-applet
    jq notify-send gsettings python3 systemd-run dbus-update-activation-environment setsid
    gnome-keyring-daemon gnome-control-center nautilus
    xdg-user-dir xdg-settings gtk-launch im-config
)

###############################################################################
# 0. Sanity
###############################################################################
if (( EUID == 0 )); then
    echo "Run this as your normal user, not as root; sudo is used for apt only." >&2
    exit 1
fi
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ ${ID:-} != ubuntu || ${VERSION_ID:-} != 26.04 ]]; then
        warn "This targets Ubuntu 26.04; found ${PRETTY_NAME:-unknown}. Package names may differ."
    fi
fi

###############################################################################
# 1. Pre-flight: classify every destination before anything is changed
###############################################################################
log "Checking destinations under $HOME"
STATUS=()
conflicts=()
for i in "${!UNIT_SRC[@]}"; do
    src=${UNIT_SRC[i]}
    dst=$HOME/${UNIT_DST[i]}
    if [[ ! -e $dst && ! -L $dst ]]; then
        status=new
    elif diff -rq "$src" "$dst" >/dev/null 2>&1; then
        status=unchanged
    else
        status=conflict
        conflicts+=("~/${UNIT_DST[i]}")
    fi
    STATUS+=("$status")
    printf '  %-10s ~/%s\n' "$status" "${UNIT_DST[i]}"
done

if (( ${#conflicts[@]} > 0 && ! OVERWRITE )); then
    cat >&2 <<MSG

These paths already exist and differ from the repo copies:
$(printf '  %s\n' "${conflicts[@]}")
Nothing was installed or changed. Move them aside yourself and re-run,
or re-run with --overwrite to move each one to <path>.bak.$TS first.
MSG
    exit 1
fi

###############################################################################
# 2. Packages
###############################################################################
if (( SKIP_PACKAGES )); then
    log "Skipping package installation (--skip-packages)"
else
    read -ra PACKAGES <<< "$(sed 's/#.*//' "$SELF_DIR/packages.txt" | tr '\n' ' ')"
    log "Installing ${#PACKAGES[@]} packages"
    run sudo apt-get update
    run sudo apt-get install -y "${PACKAGES[@]}"
fi

###############################################################################
# 3. Configuration files
###############################################################################
log "Installing configuration files"
moved=()
for i in "${!UNIT_SRC[@]}"; do
    src=${UNIT_SRC[i]}
    dst=$HOME/${UNIT_DST[i]}
    case ${STATUS[i]} in
        unchanged) continue ;;
        conflict)  run mv "$dst" "$dst.bak.$TS"; moved+=("$dst.bak.$TS") ;;
    esac
    run mkdir -p "${dst%/*}"
    run cp -a "$src" "$dst"
done

# cp -a keeps the executable bits from a git checkout; a zip download does not.
executables=()
for f in "$SELF_DIR"/bin/*; do
    [[ -f $f ]] && executables+=("$HOME/.local/bin/${f##*/}")
done
for f in "$SELF_DIR"/config/i3blocks/blocks/*; do
    [[ ${f##*/} == _common ]] || executables+=("$HOME/.config/i3blocks/blocks/${f##*/}")
done
run chmod 755 "${executables[@]}"

if (( DRY_RUN )); then
    log "Dry run; nothing was changed and the checks were skipped"
    exit 0
fi

###############################################################################
# 4. Checks that need no running sway session
###############################################################################
log "Checking the installed configuration"
fail=0
check() {
    local name=$1 out; shift
    if out=$("$@" 2>&1); then
        printf '  ok    %s\n' "$name"
    else
        printf '  FAIL  %s\n' "$name"
        [[ -z $out ]] || printf '%s\n' "$out" | head -5 | sed 's/^/        /'
        fail=1
    fi
}
has_font() { fc-list | grep -i "$1" >/dev/null; }
python_syntax() { python3 -c 'import ast, sys
for path in sys.argv[1:]:
    with open(path) as f:
        ast.parse(f.read(), path)' "$@"; }

# Without a seat, sway -C tries the DRM backend, hangs and fails; the headless
# backend validates the config the same way from a terminal or over ssh.
# sway -C exits 0 for errors inside included files and only logs them, so the
# log has to be checked as well as the exit status.
sway_check() {
    local out
    out=$(timeout 30 env WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
        sway -C -c "$HOME/.config/sway/config" 2>&1) || { grep -i 'error' <<< "$out"; return 1; }
    if grep -q 'Error on line' <<< "$out"; then
        grep 'Error on line' <<< "$out"
        return 1
    fi
}
check "sway -C" sway_check
check "foot --check-config" foot --check-config -c "$HOME/.config/foot/foot.ini"
check "swaync config.json is valid JSON" jq -e . "$HOME/.config/swaync/config.json"
check "bash syntax of i3blocks blocks and helper scripts" bash -c \
    'for f in "$@"; do bash -n "$f" || exit 1; done' _ \
    "$HOME"/.config/i3blocks/blocks/* \
    "$HOME"/.local/bin/regolith-{apply-look,force-kill,grimshot,lock,polkit-agent}
check "sh syntax of sway-toggle-stacking" sh -n "$HOME/.local/bin/sway-toggle-stacking"
check "python syntax of helper scripts" python_syntax \
    "$HOME"/.local/bin/regolith-{keybindings,next-free-workspace,swap-focus}
check "python3 i3ipc module" python3 -c 'import i3ipc'
check "mate polkit agent" test -x /usr/libexec/polkit-mate-authentication-agent-1
check "font Bitstream Vera" has_font "Bitstream Vera"
check "font FontAwesome" has_font FontAwesome

missing=()
for cmd in "${COMMANDS[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if (( ${#missing[@]} > 0 )); then
    printf '  FAIL  missing commands: %s\n' "${missing[*]}"
    fail=1
else
    printf '  ok    all %d commands present\n' "${#COMMANDS[@]}"
fi

###############################################################################
# 5. Summary
###############################################################################
echo
if (( ${#moved[@]} > 0 )); then
    log "Previous versions were moved aside:"
    printf '  %s\n' "${moved[@]}"
fi
if (( fail )); then
    warn "Some checks failed (see above). Fix them before logging in to Sway."
    exit 1
fi
log 'Done. Log out, then pick "Sway" (gear icon) on the GDM login screen.'
