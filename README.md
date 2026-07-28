# Omora

Opinionated dev/server environment for Fedora — a fork and adaptation of [Omarchy](https://github.com/basecamp/omarchy) (by David Heinemeier Hansson, MIT License), ported from Arch Linux to Fedora (dnf/COPR).

Omora is not affiliated with or endorsed by the Omarchy project. See [Attribution & License](#attribution--license).

## Status

| Installer | Status |
|-----------|--------|
| **Headless / WSL2** (`boot-headless.sh`) | Supported target. Developed against Fedora 41+ (dnf5). Validation in a clean VM is still pending — treat as beta and see [ROADMAP.md](ROADMAP.md). |
| **Full desktop** (`boot.sh` / `install.sh`) | Experimental and incomplete. The desktop path still contains unresolved Arch-era scripts (pacman, mkinitcpio, Limine) and is not expected to work yet. |

## Headless / WSL2 Install

Requirements: Fedora 41+ (Server, Minimal, or WSL2) and a regular user with sudo. Older Fedora releases may work but are untested — the installer warns before continuing on them.

```bash
curl -sL https://raw.githubusercontent.com/tears-mysthrala/omora/dev/boot-headless.sh | bash
```

### Options

```bash
# Dry run — list every planned action without changing the system
curl -sL https://raw.githubusercontent.com/tears-mysthrala/omora/dev/boot-headless.sh | bash -s -- --dry-run

# Non-interactive — skip all prompts (git identity, old-Fedora warning)
curl -sL https://raw.githubusercontent.com/tears-mysthrala/omora/dev/boot-headless.sh | OMORA_ASSUME_YES=1 bash

# Use a different branch or fork
curl -sL ... | OMORA_REF=my-branch OMORA_REPO=user/fork bash
```

### What it changes

- Enables the COPR repos `atim/lazygit` and `terjeros/eza`, and adds the Docker CE repo.
- Installs the packages listed in `install/omarchy-headless.packages` (skips any unavailable on your Fedora release).
- Installs starship, mise and lazydocker via their upstream installers.
- Copies `~/.bashrc` and terminal configs (`git`, `lazygit`, `starship.toml`, `tmux`, `btop`, `fastfetch`) into `~/.config/`. Existing files are backed up to `~/.omora-backup/<timestamp>/` before being overwritten.
- Writes `/etc/docker/daemon.json`, adds your user to the `docker` group, and raises inotify limits via `/etc/sysctl.d/`.
- Prints a summary of all modifications when finished.

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

## Full Desktop Install (experimental)

The full desktop installer (`install.sh`) with Hyprland, theming, Waybar, etc. is a work in progress. The dotfiles and configs are already migrated but parts of the boot/hardware layer still reference Arch-specific tooling. Known unresolved references:

- `install/login/limine-snapper.sh` — pacman, mkinitcpio hooks, Limine bootloader entries (Fedora uses dracut + GRUB/systemd-boot).
- `install/config/hardware/nvidia.sh` and several `fix-*.sh` hardware scripts — pacman queries and mkinitcpio module configs.
- `migrations/*.sh` — several inherited migrations call `pacman`. They are never executed on a fresh install (marked as already applied), but would fail if run through `omarchy-migrate` on an existing system.

These are tracked in [ROADMAP.md](ROADMAP.md). Do not run `boot.sh` / `install.sh` on a real machine yet.

## Key differences from Omarchy

- **Package manager**: pacman/yay -> dnf/COPR
- **AUR** -> COPR repos (`atim/lazygit`, `terjeros/eza`)
- **Initramfs**: mkinitcpio -> dracut
- **Repos**: pacman mirrors -> `/etc/yum.repos.d/` repo files
- **Guard**: checks for `/etc/fedora-release` instead of `/etc/arch-release`
- **Tools not in repos**: starship, mise, lazydocker installed via upstream scripts

## Attribution & License

Omora is a fork of [Omarchy](https://github.com/basecamp/omarchy) by David Heinemeier Hansson — a beautiful, modern & opinionated Linux setup for Arch. Omarchy is released under the MIT License.

Omora keeps the same [MIT License](LICENSE) and preserves the original copyright notice; the Fedora adaptation is copyright tears-mysthrala. Themes, wallpapers, and most desktop configuration are inherited from Omarchy and remain under its license.
