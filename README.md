# Omora

Opinionated dev/server environment for Fedora, forked from [Omarchy](https://github.com/basecamp/omarchy) and adapted from Arch Linux to Fedora (dnf/COPR).

## Headless / WSL2 Install

One-liner for a fresh Fedora (server, minimal, or WSL2):

```bash
curl -sL https://raw.githubusercontent.com/tears-mysthrala/omora/dev/boot-headless.sh | bash
```

### What it installs

| Category | Packages |
|----------|----------|
| **Shell** | starship, fzf, zoxide, bash-completion, bat, eza, fd, ripgrep |
| **Dev** | neovim, tmux, lazygit, lazydocker, git, gh |
| **Build** | gcc, clang, llvm, rust, cargo, ruby, luarocks |
| **Runtime** | mise, node (latest via mise), dotnet-runtime-9.0 |
| **Infra** | docker-ce, docker-compose, docker-buildx |
| **System** | btop, htop, fastfetch, jq, ImageMagick |

### What it does NOT install

No GUI, no Wayland, no Hyprland, no audio, no bluetooth, no gaming, no multimedia apps.

## Full Desktop Install (WIP)

The full desktop installer (`install.sh`) with Hyprland, theming, Waybar, etc. is a work in progress. The dotfiles and configs are already migrated but the bootloader/hardware layer still references Arch-specific tooling.

## Key differences from Omarchy

- **Package manager**: pacman/yay -> dnf/COPR
- **AUR** -> COPR repos (`atim/lazygit`, `terjeros/eza`)
- **Initramfs**: mkinitcpio -> dracut
- **Repos**: pacman mirrors -> `/etc/yum.repos.d/` repo files
- **Guard**: checks for `/etc/fedora-release` instead of `/etc/arch-release`
- **Tools not in repos**: starship, mise, lazydocker installed via upstream scripts

## Based on

[Omarchy](https://github.com/basecamp/omarchy) by DHH — a beautiful, modern & opinionated Linux distribution.

## License

Omora is released under the [MIT License](https://opensource.org/licenses/MIT).
