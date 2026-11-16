#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTS_DIR="$REPO_DIR/dots"
UV_WORKING_DIR="$HOME/.local/state/noon"

SUDO="sudo"
if [[ -n "${SUDO_PASS:-}" ]]; then
  SUDO="echo \"$SUDO_PASS\" | sudo -S"
elif [[ "$EUID" -eq 0 ]]; then
  SUDO=""
fi

FORCE=false
NVIDIA=false
REMOVE=false
ALL=false
BUILD_LIBQT=true

declare -a SELECTED=(core)
add_conf() {
  local name="${1%.conf}" existing
  for existing in "${SELECTED[@]}"; do
    [[ "$existing" == "$name" ]] && return 0
  done
  SELECTED+=("$name")
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Installs the Noon shell on Hyprland. Only the core session is installed by
default; applications and extras are opt-in.

Options:
  -f, --force      Re-run repo setup even when it is already configured
  --all            Install every package set (core, apps, dev, misc, gaming, ai)
  --apps           Install optional desktop applications
  --dev            Install build dependencies (implied when building Noon-libqt)
  --misc           Install miscellaneous utilities
  --gaming         Install gaming packages
  --ai             Install local AI tooling
  --nvidia         Install NVIDIA packages
  --no-libqt       Skip building and installing Noon-libqt
  --remove         Remove Noon system files (QML modules and the noon wrapper)
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)   FORCE=true ;;
    --nvidia)     NVIDIA=true ;;
    --remove)     REMOVE=true ;;
    --all)        ALL=true ;;
    --apps)       add_conf apps ;;
    --dev)        add_conf dev ;;
    --misc)       add_conf misc ;;
    --gaming)     add_conf gaming ;;
    --ai)         add_conf ai ;;
    --no-libqt)   BUILD_LIBQT=false ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

detect_distro() {
  . /etc/os-release
  case "$ID" in
    fedora) echo fedora ;;
    arch)   echo arch ;;
    *)
      case "${ID_LIKE:-}" in
        *fedora*) echo fedora ;;
        *arch*)   echo arch ;;
        *) echo "unsupported: $ID" >&2; exit 1 ;;
      esac
      ;;
  esac
}

DISTRO=$(detect_distro)

case "$DISTRO" in
  fedora)
    PKG_CMD="$SUDO dnf install --skip-file-locks -y"
    ;;
  arch)
    if command -v yay &>/dev/null; then
      AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
      AUR_HELPER="paru"
    else
      AUR_HELPER="$SUDO pacman"
    fi
    PKG_CMD="$AUR_HELPER -S --needed --noconfirm"
    ;;
esac

qml_install_dir() {
  local dir=""
  if command -v qtpaths6 &>/dev/null; then
    dir="$(qtpaths6 --query QT_INSTALL_QML 2>/dev/null || true)"
  elif command -v qtpaths &>/dev/null; then
    dir="$(qtpaths --query QT_INSTALL_QML 2>/dev/null || true)"
  fi
  if [[ -z "$dir" ]]; then
    for candidate in /usr/lib64/qt6/qml /usr/lib/qt6/qml; do
      [[ -d "$candidate" ]] && dir="$candidate" && break
    done
  fi
  echo "$dir"
}

remove_stale_qml() {
  local qml_dir
  qml_dir="$(qml_install_dir)"
  [[ -z "$qml_dir" || ! -d "$qml_dir/Noon" ]] && return 0
  # Modules that were removed from Noon-libqt or are not imported by the shell.
  for module in Network Devices Blobs Scrcpy QR; do
    if [[ -e "$qml_dir/Noon/$module" ]]; then
      echo "  Removing stale QML module $module"
      $SUDO rm -rf "$qml_dir/Noon/$module"
    fi
  done
}

install_libqt() {
  local libqt_dir=""

  for candidate in "${NOON_LIBQT_DIR:-}" "$REPO_DIR/Noon-libqt" "$REPO_DIR/../Noon-libqt" "$HOME/.local/src/noon-libqt"; do
    if [[ -n "$candidate" && -f "$candidate/CMakeLists.txt" ]]; then
      libqt_dir="$candidate"
      break
    fi
  done

  if [[ -z "$libqt_dir" ]]; then
    local clone_dir="$HOME/.local/src/noon-libqt"
    echo "[libqt] Noon-libqt not found, cloning into $clone_dir"
    mkdir -p "$(dirname "$clone_dir")"
    if ! git clone --depth 1 https://github.com/pharmaragist/Noon-libqt.git "$clone_dir"; then
      echo "[WARN]: could not clone Noon-libqt; C++ QML modules will be missing"
      return 0
    fi
    libqt_dir="$clone_dir"
  fi

  if ! command -v cmake &>/dev/null; then
    echo "[WARN]: cmake not found; skipping Noon-libqt build"
    return 0
  fi

  local generator=()
  command -v ninja &>/dev/null && generator=(-G Ninja)
  local build_dir="$libqt_dir/build-noon"

  echo "[libqt] Configuring $libqt_dir"
  cmake -S "$libqt_dir" -B "$build_dir" "${generator[@]}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSCRCPY=OFF

  echo "[libqt] Building"
  cmake --build "$build_dir" -j"$(nproc)"

  echo "[libqt] Installing"
  $SUDO cmake --install "$build_dir"

  remove_stale_qml
}

# ---- Fedora-specific repos ----
if [[ "$DISTRO" == fedora ]]; then
  if $FORCE || ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release &>/dev/null; then
    $SUDO dnf install --nogpgcheck --skip-file-locks \
      https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
      https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
  fi

  if $FORCE || ! rpm -q terra-release &>/dev/null; then
    if dnf repolist 2>/dev/null | grep -q "^terra"; then
      echo "[WARN]: terra repo already configured, skipping"
    else
      $SUDO dnf install --nogpgcheck --skip-file-locks \
        --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
        terra-release -y || echo "[WARN]: terra repo setup failed"
    fi
  fi
fi

flush_block() {
  local type="$1"; shift
  local items=("$@")
  [[ ${#items[@]} -eq 0 ]] && return
  case "$type" in
    copr)
      if [[ "$DISTRO" != fedora ]]; then
        echo "[WARN]: COPR not supported on $DISTRO, skipping"
        return
      fi
      for repo in "${items[@]}"; do
        if $FORCE || ! dnf copr list 2>/dev/null | grep -qc "$repo"; then
          $SUDO dnf copr enable "$repo" -y || echo "[WARN]: failed to enable COPR $repo"
        fi
      done
      ;;
    pkgs)
      $PKG_CMD "${items[@]}" || echo "[WARN]: some packages failed to install"
      ;;
    python)
      uv pip install --system "${items[@]}" || echo "[WARN]: some python packages failed to install"
      ;;
    script)
      for s in "${items[@]}"; do
        bash "$DOTS_DIR/$DISTRO/$s" || echo "[WARN]: script $s failed"
      done
      ;;
  esac
}

process_config() {
  local conf="$1"
  [[ ! -f "$conf" ]] && return
  local -a copr_list=() pkgs_list=() python_list=() script_list=()
  local block_type= block_items=()
  while IFS= read -r line; do
    line="${line#"${line%%[! ]*}"}"
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ -n "$block_type" ]]; then
      if [[ "$line" == "}" ]]; then
        case "$block_type" in
          copr)   copr_list+=("${block_items[@]}") ;;
          pkgs)   pkgs_list+=("${block_items[@]}") ;;
          python) python_list+=("${block_items[@]}") ;;
          script) script_list+=("${block_items[@]}") ;;
        esac
        block_type=
        block_items=()
      else
        for item in $line; do
          [[ -n "$item" ]] && block_items+=("$item")
        done
      fi
    else
      if [[ "$line" =~ ^(copr|pkgs|python|script)[[:space:]]*\{[[:space:]]*$ ]]; then
        block_type="${BASH_REMATCH[1]}"
        block_items=()
      fi
    fi
  done < "$conf"
  if [[ -n "$block_type" && ${#block_items[@]} -gt 0 ]]; then
    case "$block_type" in
      copr)   copr_list+=("${block_items[@]}") ;;
      pkgs)   pkgs_list+=("${block_items[@]}") ;;
      python) python_list+=("${block_items[@]}") ;;
      script) script_list+=("${block_items[@]}") ;;
    esac
  fi
  # Flush in dependency order: copr -> pkgs -> script -> python
  flush_block copr   "${copr_list[@]}"
  flush_block pkgs   "${pkgs_list[@]}"
  flush_block script "${script_list[@]}"
  flush_block python "${python_list[@]}"
}

if $REMOVE; then
  echo "Removing Noon system files..."
  qml_dir="$(qml_install_dir)"
  if [[ -n "$qml_dir" && -d "$qml_dir/Noon" ]]; then
    $SUDO rm -rf "$qml_dir/Noon"
  fi
  $SUDO rm -f /usr/local/bin/noon
  echo "Removed system files. User dotfiles were left untouched."
  exit 0
fi

if $ALL; then
  for conf in "$DOTS_DIR/$DISTRO"/*.conf; do
    name="$(basename "$conf" .conf)"
    [[ "$name" == "core" || "$name" == "nvidia" ]] && continue
    add_conf "$name"
  done
fi

# Building Noon-libqt needs the development package set.
if $BUILD_LIBQT && [[ -f "$DOTS_DIR/$DISTRO/dev.conf" ]]; then
  add_conf dev
fi

for name in "${SELECTED[@]}"; do
  conf="$DOTS_DIR/$DISTRO/$name.conf"
  if [[ -f "$conf" ]]; then
    echo "==> Installing $name packages"
    process_config "$conf"
  elif [[ "$name" == "core" ]]; then
    echo "[WARN]: missing $conf; install the shell dependencies manually"
  fi
done

if $NVIDIA; then
  process_config "$DOTS_DIR/$DISTRO/nvidia.conf"
fi

if $BUILD_LIBQT; then
  install_libqt
fi

# Process shared directories with INSTALLER_CONFIG
SHARED_DIR="$DOTS_DIR/shared"
shopt -s dotglob nullglob
if [[ -d "$SHARED_DIR" ]]; then
  for component in "$SHARED_DIR"/*/; do
    [[ -d "$component" ]] || continue
    config="$component/INSTALLER_CONFIG"
    [[ -f "$config" ]] || continue
    dest_path= type_name=
    while IFS='=' read -r key value; do
      key="${key#"${key%%[! ]*}"}"
      value="${value#"${value%%[! ]*}"}"
      [[ -z "$key" || "$key" =~ ^# ]] && continue
      case "$key" in
        DESTINATION) dest_path="$value" ;;
        TYPE)        type_name="$value" ;;
      esac
    done < "$config"
    if [[ -n "$dest_path" && -n "$type_name" ]]; then
      dest_path="${dest_path/#\$HOME/$HOME}"
      echo "[$type_name] Installing..."
      cmd_prefix="$SUDO"
      [[ "$dest_path" == "$HOME"* ]] && cmd_prefix=""
      $cmd_prefix mkdir -p "$dest_path"
      for item in "$component"/*; do
        [[ "$(basename "$item")" == "INSTALLER_CONFIG" ]] && continue
        $cmd_prefix cp -a "$item" "$dest_path/" || echo "[WARN]: failed to install $(basename "$item")"
      done
      if [[ "$type_name" == "fonts" ]]; then
        $SUDO fc-cache -f 2>/dev/null || true
      fi
    fi
  done
fi
shopt -u dotglob nullglob

# The session starts the shell through /usr/local/bin/noon.
$SUDO bash "$DOTS_DIR/install-binary.sh"

echo "All packages installed"
