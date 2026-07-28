#!/bin/bash

# Omora headless/WSL2 installer
# Installs dev tools, shell config, and terminal environment only — no GUI/Wayland
#
# This script is executed by boot-headless.sh. Run it, don't source it from
# an interactive shell (it calls exit on failure).
#
# Options:
#   --dry-run            Print the planned actions without changing the system
#
# Environment:
#   OMORA_ASSUME_YES=1   Non-interactive mode: skip all prompts
#   OMORA_DRY_RUN=1      Same as --dry-run

set -eEo pipefail

# ── Arguments ────────────────────────────────────────────────────────────────

DRY_RUN="${OMORA_DRY_RUN:-0}"
ASSUME_YES="${OMORA_ASSUME_YES:-0}"

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=1 ;;
    -y | --yes) ASSUME_YES=1 ;;
    *) echo -e "\e[33m=> Unknown option: $arg\e[0m" ;;
  esac
done

# Define Omarchy/Omora locations
export OMARCHY_PATH="$HOME/.local/share/omarchy"
export OMARCHY_INSTALL="$OMARCHY_PATH/install"
export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ── Helpers ──────────────────────────────────────────────────────────────────

log() { echo -e "\e[32m=> $1\e[0m"; }
warn() { echo -e "\e[33m=> $1\e[0m"; }
fail() { echo -e "\e[31m=> $1\e[0m" >&2; exit 1; }

# ── Guards ───────────────────────────────────────────────────────────────────

if (( EUID == 0 )); then
  fail "Do not run as root. Run as your regular user (sudo will be used when needed)."
fi

if [[ ! -f /etc/fedora-release ]]; then
  fail "Omora requires Fedora Linux (/etc/fedora-release not found).
For Arch Linux, use upstream Omarchy instead: https://github.com/basecamp/omarchy"
fi

if ! command -v dnf &>/dev/null; then
  fail "dnf not found. This installer requires Fedora or a dnf-based distro."
fi

# Omora targets dnf5, the default package manager since Fedora 41.
# Older Fedora releases are untested; ask before continuing.
FEDORA_VERSION_ID="$(. /etc/os-release && echo "${VERSION_ID:-0}")"
if (( FEDORA_VERSION_ID < 41 )); then
  warn "Omora is developed against Fedora 41+ (dnf5). Detected: $(cat /etc/fedora-release)."
  warn "This release is untested and some packages may be missing."
  if (( ASSUME_YES == 0 )); then
    reply=""
    read -rp "Continue anyway? [y/N] " reply < /dev/tty || true
    [[ $reply =~ ^[Yy]$ ]] || fail "Aborted. Re-run with OMORA_ASSUME_YES=1 to skip this check."
  fi
fi

# ── Dry run ──────────────────────────────────────────────────────────────────

if (( DRY_RUN == 1 )); then
  log "Dry run — no changes will be made."
  echo
  echo "  Target system: $(cat /etc/fedora-release)"
  echo
  echo "  Would perform:"
  echo "    1. Install the 'Development Tools' group (gcc, make, ...)"
  echo "    2. Add the Docker CE repo (download.docker.com/linux/fedora)"
  echo "    3. Enable COPR repos: atim/lazygit, terjeros/eza"
  echo "    4. Install packages from install/omarchy-headless.packages:"

  mapfile -t packages < <(grep -v '^#' "$OMARCHY_INSTALL/omarchy-headless.packages" | grep -v '^$')
  for pkg in "${packages[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
      echo "       - $pkg (already installed)"
    else
      echo "       - $pkg"
    fi
  done

  echo "    5. Install upstream tools: starship, mise, lazydocker"
  echo "    6. Copy ~/.bashrc and ~/.config/{git,lazygit,starship.toml,tmux,btop,fastfetch}"
  echo "       (existing files are backed up to ~/.omora-backup/<timestamp>/ first)"
  echo "    7. Configure git identity (interactive, skipped with OMORA_ASSUME_YES=1)"
  echo "    8. Write /etc/docker/daemon.json and add ${USER:-$(id -un)} to the docker group"
  echo "    9. Create ~/Work with a mise config and install Node.js via mise"
  echo "   10. Raise inotify limits (/etc/sysctl.d/40-max-user-watches.conf, 41-max-user-instances.conf)"
  echo
  log "Dry run complete. Re-run without --dry-run to apply these changes."
  exit 0
fi

# ── Change tracking (for the final summary) ──────────────────────────────────

INSTALLED_PKGS=()
SKIPPED_PKGS=()
COPIED_CONFIGS=()
BACKED_UP=()
BACKUP_DIR="$HOME/.omora-backup/$(date +%Y%m%d-%H%M%S)"

# Back up a file inside $HOME before overwriting it
backup_file() {
  local target="$1"
  if [[ -e $target ]]; then
    local rel="${target#"$HOME"/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -a "$target" "$BACKUP_DIR/$rel"
    BACKED_UP+=("$target")
  fi
}

# ── Repos ────────────────────────────────────────────────────────────────────

log "Setting up repositories..."

# Development tools group
sudo dnf group install -y development-tools >/dev/null 2>&1 \
  || sudo dnf group install -y 'Development Tools' >/dev/null 2>&1 \
  || sudo dnf install -y gcc gcc-c++ make automake autoconf >/dev/null

# Docker CE repo (if not present)
if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
  sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null \
    || sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null \
    || warn "Could not add Docker repo — install docker manually if needed"
fi

# COPR repos for packages not in official Fedora repos
log "Enabling COPR repos..."
sudo dnf copr enable -y atim/lazygit 2>/dev/null || warn "Could not enable COPR atim/lazygit"
sudo dnf copr enable -y terjeros/eza 2>/dev/null || warn "Could not enable COPR terjeros/eza"

# ── Packages ─────────────────────────────────────────────────────────────────

log "Installing headless packages..."
mapfile -t packages < <(grep -v '^#' "$OMARCHY_INSTALL/omarchy-headless.packages" | grep -v '^$')

# Install what's available, skip what isn't (some may not exist on all Fedora versions)
for pkg in "${packages[@]}"; do
  if ! rpm -q "$pkg" &>/dev/null; then
    if sudo dnf install -y "$pkg" 2>/dev/null; then
      INSTALLED_PKGS+=("$pkg")
    else
      SKIPPED_PKGS+=("$pkg")
      warn "Skipped: $pkg (not available in repos)"
    fi
  fi
done

# ── Tools not in Fedora repos (installed via their own installers) ───────────

log "Installing tools from upstream..."

# Starship (shell prompt)
if ! command -v starship &>/dev/null; then
  log "Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null
fi

# Mise (version manager)
if ! command -v mise &>/dev/null; then
  log "Installing mise..."
  curl -sS https://mise.run | sh >/dev/null
  eval "$(~/.local/bin/mise activate bash)" 2>/dev/null || true
fi

# Lazydocker (if not installed via dnf)
if ! command -v lazydocker &>/dev/null; then
  log "Installing lazydocker..."
  curl -sS https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash >/dev/null 2>&1 \
    || warn "Could not install lazydocker"
fi

# ── Shell config ─────────────────────────────────────────────────────────────

log "Configuring shell environment..."

# Bashrc
backup_file "$HOME/.bashrc"
cp "$OMARCHY_PATH/default/bashrc" ~/.bashrc
COPIED_CONFIGS+=("~/.bashrc")

# Core configs (only terminal-relevant ones)
mkdir -p ~/.config

for cfg in git lazygit starship.toml tmux btop fastfetch; do
  if [[ -e "$OMARCHY_PATH/config/$cfg" ]]; then
    backup_file "$HOME/.config/$cfg"
    cp -R "$OMARCHY_PATH/config/$cfg" ~/.config/
    COPIED_CONFIGS+=("~/.config/$cfg")
  fi
done

# ── Git ──────────────────────────────────────────────────────────────────────

log "Configuring git..."

if (( ASSUME_YES == 1 )); then
  log "OMORA_ASSUME_YES=1 — skipping git identity prompts"
else
  # Read from /dev/tty so prompts work when piped via curl | bash
  if [[ -z $(git config --global user.name 2>/dev/null) ]]; then
    git_name=""
    read -rp "Git name (leave empty to skip): " git_name < /dev/tty || true
    [[ -n $git_name ]] && git config --global user.name "$git_name"
  fi

  if [[ -z $(git config --global user.email 2>/dev/null) ]]; then
    git_email=""
    read -rp "Git email (leave empty to skip): " git_email < /dev/tty || true
    [[ -n $git_email ]] && git config --global user.email "$git_email"
  fi
fi

# ── Docker ───────────────────────────────────────────────────────────────────

if command -v docker &>/dev/null; then
  log "Configuring Docker..."

  sudo mkdir -p /etc/docker
  sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" }
}
EOF

  # On WSL2, Docker may be managed by Docker Desktop — only enable if systemd is PID 1
  if [[ $(cat /proc/1/comm 2>/dev/null) == "systemd" ]]; then
    sudo systemctl enable docker.socket
  fi

  sudo usermod -aG docker "${USER}"
fi

# ── Mise (version manager) ──────────────────────────────────────────────────

if command -v mise &>/dev/null; then
  log "Setting up mise..."
  mkdir -p "$HOME/Work" "$HOME/Work/tries"

  cat >"$HOME/Work/.mise.toml" <<'EOF'
[env]
_.path = "{{ cwd }}/bin"
EOF

  mise trust ~/Work/.mise.toml
  mise use -g node@latest
fi

# ── System tuning ────────────────────────────────────────────────────────────

log "Applying system tweaks..."

# Increase file watchers (needed for dev servers, webpack, etc.)
if [[ -d /etc/sysctl.d ]]; then
  echo "fs.inotify.max_user_watches=524288" | sudo tee /etc/sysctl.d/40-max-user-watches.conf >/dev/null
  echo "fs.inotify.max_user_instances=1024" | sudo tee /etc/sysctl.d/41-max-user-instances.conf >/dev/null
  sudo sysctl --system >/dev/null 2>&1 || true
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo
log "Omora headless setup complete!"
echo
echo "  Summary of changes:"
echo "    Packages installed: ${#INSTALLED_PKGS[@]}"
if (( ${#SKIPPED_PKGS[@]} > 0 )); then
  echo "    Packages skipped (unavailable): ${SKIPPED_PKGS[*]}"
fi
echo "    Configs copied:     ${COPIED_CONFIGS[*]}"
if (( ${#BACKED_UP[@]} > 0 )); then
  echo "    Backups saved to:   $BACKUP_DIR"
fi
echo "    System files:       /etc/docker/daemon.json, /etc/sysctl.d/4{0,1}-max-user-*.conf"
echo
echo "  Restart your shell or run: source ~/.bashrc"
echo
echo "  Installed:"
echo "    Shell:  starship, fzf, zoxide, bat, eza, fd, ripgrep"
echo "    Dev:    neovim, tmux, lazygit, lazydocker, git, gh"
echo "    Build:  gcc, clang, rust, cargo, ruby, mise, node"
echo "    Infra:  docker, docker-compose, docker-buildx"
echo
echo "  Work dir: ~/Work"
echo
