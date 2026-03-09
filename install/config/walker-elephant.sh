#!/bin/bash

# Ensure Walker service is started automatically on boot
mkdir -p ~/.config/autostart/
cp $OMARCHY_PATH/default/walker/walker.desktop ~/.config/autostart/

# And is restarted if it crashes or is killed
mkdir -p ~/.config/systemd/user/app-walker@autostart.service.d/
cp $OMARCHY_PATH/default/walker/restart.conf ~/.config/systemd/user/app-walker@autostart.service.d/restart.conf

# Create dnf post-transaction action to restart walker after updates
sudo mkdir -p /etc/dnf/plugins/post-transaction-actions.d
sudo tee /etc/dnf/plugins/post-transaction-actions.d/walker-restart.action > /dev/null << EOF
walker:any:$OMARCHY_PATH/bin/omarchy-restart-walker
elephant*:any:$OMARCHY_PATH/bin/omarchy-restart-walker
EOF

# Ensure the post-transaction-actions plugin is installed
omarchy-pkg-add python3-dnf-plugin-post-transaction-actions 2>/dev/null || true

# Link the visual theme menu config
mkdir -p ~/.config/elephant/menus
ln -snf $OMARCHY_PATH/default/elephant/omarchy_themes.lua ~/.config/elephant/menus/omarchy_themes.lua
ln -snf $OMARCHY_PATH/default/elephant/omarchy_background_selector.lua ~/.config/elephant/menus/omarchy_background_selector.lua
