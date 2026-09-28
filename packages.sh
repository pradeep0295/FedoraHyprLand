#!/usr/bin/env bash
set -Eeuo pipefail

readonly NOCTALIA_MIN_FEDORA=44
readonly HYPRLAND_MIN_VERSION="0.55.0"
readonly HYPRLAND_COPR="sdegler/hyprland"
readonly LEXEND_URL="https://raw.githubusercontent.com/google/fonts/main/ofl/lexend/Lexend%5Bwght%5D.ttf"
readonly MAPLE_URL="https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF-unhinted.zip"

install_packages=(
  brightnessctl
  cliphist
  curl
  adw-gtk3-theme
  fontconfig
  ffmpegthumbnailer
  grim
  gvfs
  gvfs-mtp
  hyprland
  kitty
  mousepad
  NetworkManager
  bluez
  noctalia
  pamixer
  pavucontrol
  qalculate-gtk
  sddm
  pipewire-alsa
  pipewire-utils
  playerctl
  qt6-qtsvg
  qt6ct
  slurp
  thunar
  thunar-archive-plugin
  thunar-volman
  tumbler
  unzip
  uwsm
  wl-clipboard
  wireplumber
  xarchiver
  xdg-desktop-portal-gtk
  xdg-desktop-portal-hyprland
  xdg-user-dirs
  xdg-utils
)

extra_packages=(
  btop
  cava
  fastfetch
  gnome-system-monitor
  loupe
  mpv
  nvtop
)

dry_run=0
install_extras=0
temp_dir=""
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

cleanup() {
  if [[ -n "$temp_dir" ]]; then
    rm -rf -- "$temp_dir"
  fi
}
trap cleanup EXIT

usage() {
  printf 'Usage: %s [--with-extras] [--dry-run]\n' "${0##*/}"
}

for arg in "$@"; do
  case "$arg" in
    --with-extras) install_extras=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

run() {
  if (( dry_run )); then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

check_fedora() {
  if (( dry_run )); then
    return
  fi

  if [[ ! -r /etc/os-release ]]; then
    printf 'Cannot identify this operating system. This installer supports Fedora only.\n' >&2
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != fedora ]]; then
    printf 'This installer supports Fedora only (detected: %s).\n' "${PRETTY_NAME:-unknown}" >&2
    exit 1
  fi

  if (( VERSION_ID < NOCTALIA_MIN_FEDORA )); then
    printf 'Noctalia is available in Fedora %s and newer; detected Fedora %s.\n' \
      "$NOCTALIA_MIN_FEDORA" "$VERSION_ID" >&2
    exit 1
  fi
}

hyprland_available_in_enabled_repos() {
  dnf -q repoquery --available --queryformat='%{name}' hyprland 2>/dev/null \
    | grep -Fxq hyprland
}

hyprland_lua_version_available() {
  local available_version
  available_version=$(dnf -q repoquery --available --queryformat='%{version}' hyprland 2>/dev/null \
    | sort -V \
    | tail -n 1)

  [[ -n "$available_version" ]] || return 1
  [[ "$(printf '%s\n%s\n' "$HYPRLAND_MIN_VERSION" "$available_version" | sort -V | head -n 1)" == "$HYPRLAND_MIN_VERSION" ]]
}

ensure_hyprland_repository() {
  if (( dry_run )); then
    printf '[dry-run] check enabled DNF repositories for Hyprland %s or newer (Lua config support)\n' \
      "$HYPRLAND_MIN_VERSION"
    printf '[dry-run] if no compatible release is available, install dnf5-plugins and enable COPR %s\n' \
      "$HYPRLAND_COPR"
    return
  fi

  if hyprland_lua_version_available; then
    printf 'Hyprland %s or newer is available and supports the Lua config.\n' \
      "$HYPRLAND_MIN_VERSION"
    return
  fi

  if hyprland_available_in_enabled_repos; then
    printf 'Enabled repositories have no Hyprland release new enough for Lua config; enabling COPR %s.\n' \
      "$HYPRLAND_COPR"
  else
    printf 'Hyprland is not available in enabled repositories; enabling COPR %s.\n' \
      "$HYPRLAND_COPR"
  fi
  run "${sudo_cmd[@]}" dnf install -y dnf5-plugins
  run "${sudo_cmd[@]}" dnf copr enable -y "$HYPRLAND_COPR"

  if ! hyprland_lua_version_available; then
    printf 'Hyprland %s or newer is still unavailable after enabling COPR %s.\n' \
      "$HYPRLAND_MIN_VERSION" \
      "$HYPRLAND_COPR" >&2
    exit 1
  fi
}

ensure_display_manager() {
  if (( dry_run )); then
    printf '[dry-run] install and enable the SDDM display manager\n'
    printf '[dry-run] systemctl enable --now sddm.service\n'
    return
  fi

  run "${sudo_cmd[@]}" dnf install -y sddm
  run "${sudo_cmd[@]}" systemctl enable --now sddm.service
  printf 'Display manager: SDDM enabled and started.\n'
}

install_fonts() {
  local font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
  local maple_dir
  local font_file
  local found_font=0

  if (( dry_run )); then
    printf '[dry-run] download Lexend variable font to %s/Lexend/\n' "$font_dir"
    printf '[dry-run] download Maple Mono NF v7.9 to %s/MapleMono/\n' "$font_dir"
    printf '[dry-run] fc-cache -f %s\n' "$font_dir"
    return
  fi

  temp_dir=$(mktemp -d)
  maple_dir="$temp_dir/maple"
  mkdir -p "$font_dir/Lexend" "$font_dir/MapleMono" "$maple_dir"

  curl --fail --location --retry 3 "$LEXEND_URL" \
    --output "$font_dir/Lexend/Lexend[wght].ttf"
  curl --fail --location --retry 3 "$MAPLE_URL" --output "$temp_dir/maple.zip"
  unzip -q "$temp_dir/maple.zip" -d "$maple_dir"

  while IFS= read -r -d '' font_file; do
    install -m 644 "$font_file" "$font_dir/MapleMono/"
    found_font=1
  done < <(find "$maple_dir" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)

  if (( ! found_font )); then
    printf 'No TTF or OTF files were found in the Maple Mono archive.\n' >&2
    exit 1
  fi

  fc-cache --force "$font_dir"
}

install_configs() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
  local source_root="$script_dir/configs"
  local install_dir
  local source_path
  local target_path

  for install_dir in \
    hypr \
    kitty \
    gtk-3.0 \
    gtk-4.0 \
    qt6ct \
    fontconfig \
    noctalia \
    uwsm; do
    source_path="$source_root/$install_dir"
    target_path="$config_dir/$install_dir"

    if [[ "$install_dir" == hypr && -d "$target_path" ]]; then
      if (( dry_run )); then
        printf '[dry-run] merge missing Hyprland config files from %s into %s\n' \
          "$source_path" "$target_path"
      else
        cp -an "$source_path/." "$target_path/"
        printf 'Merged missing Hyprland config files into %s; existing files were kept.\n' \
          "$target_path"
      fi
    elif [[ -e "$target_path" ]]; then
      printf 'Keeping existing config: %s\n' "$target_path"
    elif (( dry_run )); then
      printf '[dry-run] install %s to %s\n' "$source_path" "$target_path"
    else
      mkdir -p "$(dirname -- "$target_path")"
      cp -a "$source_path" "$target_path"
      if [[ "$install_dir" == qt6ct ]]; then
        sed -i "s|@XDG_CONFIG_HOME@|$config_dir|g" "$target_path/qt6ct.conf"
      fi
      printf 'Installed config: %s\n' "$target_path"
    fi
  done
}

check_fedora

if (( EUID == 0 )); then
  sudo_cmd=()
else
  command -v sudo >/dev/null 2>&1 || {
    printf 'sudo is required to install Fedora packages.\n' >&2
    exit 1
  }
  sudo_cmd=(sudo)
fi

packages=("${install_packages[@]}")
if (( install_extras )); then
  packages+=("${extra_packages[@]}")
fi

ensure_hyprland_repository
run "${sudo_cmd[@]}" dnf install -y "${packages[@]}"
ensure_display_manager
install_fonts
install_configs
run xdg-mime default thunar.desktop inode/directory application/x-gnome-saved-search

print_post_install_instructions() {
  cat <<'EOF'

Next steps
==========

1. First graphical login
  Reboot when convenient. At SDDM, choose the UWSM-managed Hyprland session
  if it is listed, then sign in. If SDDM is not shown, switch to a text console
  with Ctrl+Alt+F3, sign in, and run:
  sudo systemctl enable --now sddm.service
  sudo systemctl set-default graphical.target
  This setup uses Hyprland 0.55+ and loads ~/.config/hypr/hyprland.lua.
  Its modular Lua files start Noctalia automatically. Give the shell a few
  seconds to start on first login; Super+Space opens its launcher.

2. First-session checks
  Super+Enter opens Kitty, Super+E opens Thunar, Super+T opens Mousepad, and
  Super+C opens Qalculate. Super+W opens Firefox if Firefox is installed; if
  it is missing, install it with: sudo dnf install firefox
  Super+1 through Super+5 switch workspaces; Super+Shift+1 through Super+5
  move the focused window to that workspace. Super+arrows change focus, and
  Super+Shift+arrows move the focused window. Hold Super and drag with the
  left mouse button to reposition a tiled window; Super+right-drag resizes.
  Super+V toggles floating mode; Super+Shift+V opens clipboard history;
  Super+period opens the emoji provider.
  Super+X opens the control center, Super+Z opens Noctalia settings, Super+L
  locks the session, Print starts a region screenshot, and Super+Print takes
  a fullscreen screenshot. Media and brightness keys use Noctalia controls.
  Super+M cleanly stops the UWSM-managed session and logs out.

3. Set the wallpaper and shell appearance
  Open Noctalia settings with Super+Z. Set a wallpaper first: the configured
  theme derives its dark tonal palette from the wallpaper. Review the panel,
  clock, launcher, notification, workspace, and accessibility settings there.
  The config opts into Noctalia's GTK 3, GTK 4, KColorScheme, Kitty, and Qt
  templates. Review Settings > Templates to confirm the integrations you use
  are enabled. Restart open applications after template changes so they pick
  up the updated colors.

4. GTK and Qt appearance
  GTK uses the adw-gtk3 theme, Breeze icons, Bibata-Modern-Ice cursor, and
  Lexend. If GTK applications do not pick up the dark theme, check Noctalia's
  GTK templates and run:
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
  Qt uses qt6ct with the Fusion style. After the first login, open qt6ct,
  choose the Noctalia color scheme in Appearance, then Apply. Noctalia's Qt
  template updates that scheme when its wallpaper palette changes. The session
  environment selects qt6ct as the Qt platform theme; log out and back in
  after changing environment settings. Some applications may use their own
  theme controls.

5. Kitty and fonts
  Kitty is configured for Maple Mono NF with a translucent background. Open a
  new Kitty window after login. Check font discovery with:
  fc-match 'Maple Mono NF'
  fc-match Lexend
  If either result does not name the requested font, rebuild the cache with:
  fc-cache -f ~/.local/share/fonts
  Then close and reopen the application. Noctalia's font settings can also
  select Lexend for shell text.

6. Thunar and file integration
  Directories are associated with Thunar. Confirm with:
  xdg-mime query default inode/directory
  In Thunar preferences, choose thumbnail file types and enable volume
  management if desired. Tumbler provides thumbnail support; ffmpegthumbnailer
  adds video thumbnails. GVFS and GVFS-MTP provide removable-device and MTP
  integration. Right-click files or folders for archive actions from
  thunar-archive-plugin and Xarchiver.

7. Optional utilities
  The --with-extras installer option adds btop, cava, fastfetch, system
  monitor, Loupe, mpv, and nvtop. The Ctrl+Shift+Escape binding opens btop;
  install the extras or run sudo dnf install btop to use it.

8. Troubleshooting
  Check the display manager with: systemctl status sddm.service
  Check the current boot's user-session messages with: journalctl --user -b
  Existing Hyprland files are never overwritten or removed; the installer
  adds only missing Lua files. If you already have a hyprland.lua, compare it
  with this repository and merge settings manually. A legacy hyprland.conf is
  left in place but is not used by the Lua-based Hyprland 0.55+ setup. Back it
  up or remove it yourself only after reviewing its contents. Hyprland reloads
  Lua modules from hyprland.lua when saved; use hyprctl reload if needed.

Existing configs were kept if they were already present; review them if the
installed behavior differs from the shortcuts and appearance described above.
EOF
}

if (( dry_run )); then
  printf '\nDry run complete; no changes were made.\n'
else
  printf '\nInstalled Hyprland, Noctalia, Kitty, and user fonts.\n'
  printf 'No existing packages or dotfiles were removed or overwritten.\n'
  print_post_install_instructions
fi