# Hyprland Dotfiles

Public backup of a personal Hyprland setup on Debian 13.

## Included

- `hypr/`: Hyprland entrypoint, settings, layouts, rules, keybindings and scripts.
- `noctalia/config.toml`: declarative Noctalia configuration.
- `noctalia/settings.toml`: selected Noctalia UI state, including lockscreen widgets.
- `kitty/kitty.conf`: Kitty terminal configuration and clipboard mappings.

The repository intentionally excludes credentials, encryption keys, clipboard entries and runtime data. Review paths and hardware-specific settings before reusing it on another machine.

Workspace IDs are global in Hyprland, but the included navigation binds treat number keys and previous/next navigation as slots on the focused monitor. Adjust `workspaces.conf` and `SwitchMonitorWorkspace.sh` when changing monitor assignments.

## Restore

From the repository root, copy the relevant files into the matching locations under `~/.config` and `~/.local/state`.

```bash
cp -a hypr/hyprland.conf ~/.config/hypr/
cp -a hypr/peter ~/.config/hypr/
cp -a noctalia/config.toml ~/.config/noctalia/
cp -a noctalia/settings.toml ~/.local/state/noctalia/
cp -a kitty/kitty.conf ~/.config/kitty/
chmod +x ~/.config/hypr/peter/scripts/*.sh
hyprctl reload
noctalia msg config-reload
```

Do not copy a Noctalia storage key from another machine. Generate or configure it locally if clipboard persistence is enabled.
