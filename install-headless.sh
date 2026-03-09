#!/bin/bash

# Omora headless/WSL2 installer
# Installs dev tools, shell config, and terminal environment only — no GUI/Wayland

set -eEo pipefail

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

if ! command -v dnf &>/dev/null; then
  fail "dnf not found. This installer requires Fedora or a dnf-based distro."
fi

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
sudo dnf copr enable -y varlad/eza 2>/dev/null || warn "Could not enable COPR varlad/eza"

# ── Packages ─────────────────────────────────────────────────────────────────

log "Installing headless packages..."
mapfile -t packages < <(grep -v '^#' "$OMARCHY_INSTALL/omarchy-headless.packages" | grep -v '^$')

# Install what's available, skip what isn't (some may not exist on all Fedora versions)
for pkg in "${packages[@]}"; do
  if ! rpm -q "$pkg" &>/dev/null; then
    sudo dnf install -y "$pkg" 2>/dev/null || warn "Skipped: $pkg (not available in repos)"
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
cp "$OMARCHY_PATH/default/bashrc" ~/.bashrc

# Core configs (only terminal-relevant ones)
mkdir -p ~/.config

for cfg in git lazygit starship.toml tmux btop fastfetch; do
  if [[ -e "$OMARCHY_PATH/config/$cfg" ]]; then
    cp -R "$OMARCHY_PATH/config/$cfg" ~/.config/
  fi
done

# ── Git ──────────────────────────────────────────────────────────────────────

log "Configuring git..."
if [[ -z $(git config --global user.name 2>/dev/null) ]]; then
  read -rp "Git name (leave empty to skip): " git_name
  [[ -n $git_name ]] && git config --global user.name "$git_name"
fi

if [[ -z $(git config --global user.email 2>/dev/null) ]]; then
  read -rp "Git email (leave empty to skip): " git_email
  [[ -n $git_email ]] && git config --global user.email "$git_email"
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

# ── Done ─────────────────────────────────────────────────────────────────────

echo
log "Omora headless setup complete!"
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
