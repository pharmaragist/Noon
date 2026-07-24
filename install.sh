#!/usr/bin/env bash
set -e

SUDO="sudo"
if [[ -n "$SUDO_PASS" ]]; then
  SUDO="echo \"$SUDO_PASS\" | sudo -S"
elif [[ "$EUID" -eq 0 ]]; then
  SUDO=""
fi

FORCE=false
NVIDIA=false
REMOVE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)   FORCE=true; shift ;;
    --nvidia)     NVIDIA=true; shift ;;
    --remove)     REMOVE=true; shift ;;
    *)            shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/dots"
UV_WORKING_DIR="$HOME/.local/state/noon"

detect_distro() {
  . /etc/os-release
  case "$ID" in
    fedora) echo fedora ;;
    arch)   echo arch ;;
    *)      echo "unsupported: $ID" >&2; exit 1 ;;
  esac
}

DISTRO=$(detect_distro)

case "$DISTRO" in
  fedora)
    PKG_CMD="sudo dnf install --skip-file-locks -y"
    ;;
  arch)
    if command -v yay &>/dev/null; then
      AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
      AUR_HELPER="paru"
    else
      AUR_HELPER="sudo pacman"
    fi
    PKG_CMD="$AUR_HELPER -S --noconfirm"
    ;;
esac

# ---- Fedora-specific repos ----
if [[ "$DISTRO" == fedora ]]; then
  if $FORCE || ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release &>/dev/null; then
    sudo dnf install --nogpgcheck --skip-file-locks \
      https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
      https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
  fi

  if $FORCE || ! rpm -q terra-release &>/dev/null; then
    if dnf repolist 2>/dev/null | grep -q "^terra"; then
      echo "[WARN]: terra repo already configured, skipping"
    else
      sudo dnf install --nogpgcheck --skip-file-locks \
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
          sudo dnf copr enable "$repo" -y || echo "[WARN]: failed to enable COPR $repo"
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
        bash "$SCRIPT_DIR/$s" || echo "[WARN]: script $s failed"
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
  echo "Removing shared files..."
  SHARED_DIR="$SCRIPT_DIR/shared"
  if [[ -d "$SHARED_DIR" ]]; then
    for component in "$SHARED_DIR"/*/; do
      [[ -d "$component" ]] || continue
      config="$component/INSTALLER_CONFIG"
      [[ -f "$config" ]] || continue
      dest_path=
      while IFS='=' read -r key value; do
        key="${key#"${key%%[! ]*}"}"
        value="${value#"${value%%[! ]*}"}"
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        [[ "$key" == "DESTINATION" ]] && dest_path="$value"
      done < "$config"
      [[ -z "$dest_path" ]] && continue
      dest_path="${dest_path/#\$HOME/$HOME}"
      cmd_prefix="$SUDO"
      [[ "$dest_path" == "$HOME"* ]] && cmd_prefix=""
      for item in "$component"/*; do
        [[ "$(basename "$item")" == "INSTALLER_CONFIG" ]] && continue
        name="$(basename "$item")"
        echo "  Removing $dest_path/$name"
        $cmd_prefix rm -rf "$dest_path/$name" || echo "[WARN]: failed to remove $name"
      done
    done
  fi
  echo "Removed."
  exit 0
fi

process_config "$SCRIPT_DIR/$DISTRO/$DISTRO.conf"

$NVIDIA && process_config "$SCRIPT_DIR/$DISTRO/NVIDIA.conf"

# Process shared directories with INSTALLER_CONFIG
SHARED_DIR="$SCRIPT_DIR/shared"
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
        $cmd_prefix cp -r "$item" "$dest_path/" || echo "[WARN]: failed to install $(basename "$item")"
      done
      if [[ "$type_name" == "fonts" ]]; then
        $SUDO fc-cache -f 2>/dev/null || true
      fi
    fi
  done
fi

echo "All packages installed"
