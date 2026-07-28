# Omora Roadmap

## Purpose

Omora is an opinionated dev/server environment for Fedora, forked from
[Omarchy](https://github.com/basecamp/omarchy) (Arch Linux, MIT, by DHH).
It targets developers who want the Omarchy terminal/dev experience on Fedora
servers, minimal installs, and WSL2 — without the Arch base.

## Users

- The maintainer's own Fedora workstations, servers, and WSL2 instances.
- Fedora users who like Omarchy's tooling choices but do not run Arch.

## Current state (observed)

- Headless/WSL2 installer (`boot-headless.sh` + `install-headless.sh`) is the
  supported path: dnf/COPR package install, upstream installers for
  starship/mise/lazydocker, shell config, Docker, inotify tuning.
  It checks for Fedora, supports `--dry-run` and `OMORA_ASSUME_YES`, backs up
  overwritten configs to `~/.omora-backup/<timestamp>/`, and prints a summary
  of changes.
- Developed against Fedora 41+ (dnf5). **No clean-VM validation has been
  performed yet.**
- The desktop path (`boot.sh`, `install.sh`, `install/`) is experimental and
  incomplete: `install/login/limine-snapper.sh`, `install/config/hardware/nvidia.sh`,
  and several `fix-*.sh` scripts still use pacman/mkinitcpio; some inherited
  `migrations/*.sh` call pacman (never run on fresh installs, broken under
  `omarchy-migrate`).
- `default/pacman/` (dead Arch configs) has been removed; `default/dnf/`
  repo files are the active channel mechanism.

## Now — honest, verifiable headless install

Goal for the next version: a headless install that has been run end-to-end on
a clean Fedora VM and documents exactly what it changes.

- [x] Fedora guard with a clear error message in `boot-headless.sh` and
      `install-headless.sh` (rejects non-Fedora, warns below Fedora 41).
- [x] `--dry-run` mode listing all planned actions without executing them.
- [x] `OMORA_ASSUME_YES=1` non-interactive mode, documented in the README.
- [x] Final summary of modifications (packages, configs, backups, system files).
- [x] Backup of overwritten user configs to `~/.omora-backup/<timestamp>/`.
- [x] Remove dead Arch pacman configs (`default/pacman/`).
- [x] Document the validated Fedora target honestly (developed against
      Fedora 41+, VM validation pending).
- [ ] Run the headless installer in a clean Fedora VM (or WSL2 instance),
      record the exact Fedora version, and update the README from "developed
      against" to "validated on Fedora XX".
- [ ] Fix or remove every package in `install/omarchy-headless.packages` that
      is skipped as unavailable during that validation run.

Acceptance criteria: fresh Fedora VM → one-liner install → shell restarts into
a working starship/zoxide/eza/nvim/tmux/lazygit environment; `docker run
hello-world` works after re-login; no step errors out.

## Next — structure and confidence

- Split the headless installer into modules mirroring `install/`
  (shell / development / containers / fonts / desktop) so parts can be
  installed independently.
- CI that runs `boot-headless.sh` in a Fedora container
  (`fedora:latest` / version-pinned) on every push to `dev`.
- Package manifest: pin or document expected package names per supported
  Fedora release; detect renames (e.g. `fd-find` vs `fd`).
- Make `main` the default branch once headless is validated on a clean VM —
  **human decision**, keep `dev` as the integration branch until then.
- Decide the fate of the desktop path: either port it properly to Fedora
  (dracut, GRUB/systemd-boot, dnf) or remove it and keep Omora headless-only.

## Optional

- Full Fedora desktop port (Hyprland, Waybar, theming) replacing the remaining
  Arch-era scripts in `install/`.
- Rollback/uninstall for the headless installer (restore from
  `~/.omora-backup/`, remove added repos and sysctl files).
- Profiles: `workstation` / `headless` / `wsl` selecting package and config
  sets.
- Reference integration with a separate Dotfiles repo instead of duplicating
  shell configuration.
- Fix or prune pacman-based `migrations/*.sh` for systems managed via
  `omarchy-migrate`.

## Out of scope

- Becoming its own distribution or ISO.
- Supporting every Fedora version — only current and current-1 at most.
- Replicating all of Omarchy's desktop features.
- Ubuntu/Debian or other distro ports.
- Changing the upstream license or removing Omarchy attribution.

## Archive / abandonment condition

Archive the repo if upstream Omarchy ships an official Fedora path, or if the
headless installer has not been validated and used on a real system within a
year of its last commit.
