#!/bin/bash

# Omora headless/WSL2 bootstrap
# Usage: curl -sL https://raw.githubusercontent.com/tears-mysthrala/omora/dev/boot-headless.sh | bash
# Dry run: curl -sL https://raw.githubusercontent.com/tears-mysthrala/omora/dev/boot-headless.sh | bash -s -- --dry-run
# Non-interactive: curl -sL ... | OMORA_ASSUME_YES=1 bash

set -eEo pipefail

echo -e "\e[32m"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║   Omora — Headless / WSL2 Installer   ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "\e[0m"

# Must be Fedora — fail early with a clear message
if [[ ! -f /etc/fedora-release ]]; then
  echo -e "\e[31mError: Omora requires Fedora Linux (/etc/fedora-release not found).\e[0m" >&2
  echo "For Arch Linux, use upstream Omarchy instead: https://github.com/basecamp/omarchy" >&2
  exit 1
fi

echo "Detected: $(cat /etc/fedora-release)"

# Ensure git is installed
if ! command -v git &>/dev/null; then
  sudo dnf install -y git
fi

# Use custom branch if instructed, otherwise default to dev
OMORA_REF="${OMORA_REF:-dev}"
OMORA_REPO="${OMORA_REPO:-tears-mysthrala/omora}"

echo -e "Cloning Omora from: https://github.com/${OMORA_REPO}.git"
rm -rf ~/.local/share/omarchy/
git clone "https://github.com/${OMORA_REPO}.git" ~/.local/share/omarchy >/dev/null 2>&1

cd ~/.local/share/omarchy
git fetch origin "${OMORA_REF}" && git checkout "${OMORA_REF}" >/dev/null 2>&1
cd -

echo -e "\e[32mUsing branch: $OMORA_REF\e[0m\n"

chmod +x ~/.local/share/omarchy/install-headless.sh
source ~/.local/share/omarchy/install-headless.sh "$@"
