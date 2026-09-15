# cc_minecraft

Lua scripts for **CC: Tweaked** (ComputerCraft) computers, turtles, and pocket
computers running in a Minecraft 1.21.1 modpack. See `CLAUDE.md` for project
and modpack details.

## Installing a script onto a computer

Scripts are installed in-game via `installer.lua`, which downloads a role's
files straight from this repo's `main` branch and sets up a `startup.lua` to
launch it automatically.

1. Make sure the computer has HTTP access enabled (default in most modpacks;
   `wget`/`pastebin` must be allowed in the CC: Tweaked config).
2. On the computer's terminal, run:

   ```
   wget run https://raw.githubusercontent.com/rprih/cc/main/installer.lua
   ```

3. Pick a role from the printed list (e.g. `Fission Reactor Controller`).
4. Confirm overwriting any existing files if prompted.
5. Run `reboot`, or start the entry script directly, to launch it.

To reinstall or update a role later, just re-run the same command and
overwrite the existing files.

## Available roles

Roles are defined in [`manifest.lua`](manifest.lua):

- **Fission Reactor Controller** — `machines/fission-reactor/controller.lua`
- **Fission Reactor Turbine Controller** — `machines/fission-reactor-turbine/controller.lua`
- **Matrix Telemetry Transmitter** — `machines/main-matrix/battery-telemetry-transmitter.lua`
