# Configure Omarchy dnf repo
sudo cp -f ~/.local/share/omarchy/default/dnf/omarchy-${OMARCHY_MIRROR:-stable}.repo /etc/yum.repos.d/omarchy.repo

# Re-enable dracut regeneration after installation
sudo rm -f /etc/dracut.conf.d/99-omarchy-install-skip.conf
sudo dracut --regenerate-all --force
