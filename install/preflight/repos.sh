if [[ -n ${OMARCHY_ONLINE_INSTALL:-} ]]; then
  # Install build tools
  sudo dnf group install -y development-tools 2>/dev/null \
    || sudo dnf group install -y 'Development Tools' 2>/dev/null \
    || sudo dnf install -y gcc gcc-c++ make automake autoconf

  # Configure Omarchy repo
  sudo cp -f ~/.local/share/omarchy/default/dnf/omarchy-${OMARCHY_MIRROR:-stable}.repo /etc/yum.repos.d/omarchy.repo

  # Import Omarchy signing key
  sudo rpm --import "https://keys.openpgp.org/vks/v1/by-fingerprint/40DFB630FF42BCFFB047046CF0134EE680CAC571"

  # Refresh all repos and update
  sudo dnf makecache
  sudo dnf distro-sync -y
fi
