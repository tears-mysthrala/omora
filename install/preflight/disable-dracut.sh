# Temporarily disable dracut regeneration during package installation
# This speeds up installation significantly

echo "Temporarily disabling dracut regeneration during installation..."

# Prevent dracut from auto-regenerating initramfs during bulk package install
sudo mkdir -p /etc/dracut.conf.d
echo 'omit_install="yes"' | sudo tee /etc/dracut.conf.d/99-omarchy-install-skip.conf >/dev/null

echo "dracut auto-regeneration disabled"
