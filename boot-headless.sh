#!/bin/bash

# Omora headless/WSL2 bootstrap
# Usage: curl -sL https://raw.githubusercontent.com/tears-mysthrala/omora/dev/boot-headless.sh | bash

set -eEo pipefail

echo -e "\e[32m"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║   Omora — Headless / WSL2 Installer   ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "\e[0m"

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
source ~/.local/share/omarchy/install-headless.sh
