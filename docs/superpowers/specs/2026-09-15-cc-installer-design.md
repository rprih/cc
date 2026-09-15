# CC Installer — Design

## Purpose

Give a fresh or existing CC: Tweaked computer a one-command way to install or
update the correct set of scripts for a given role (e.g. "Fission Reactor
Controller", "Matrix Telemetry Transmitter"), pulling everything from this
repo's GitHub remote (`rprih/cc`, `main` branch) over HTTP. Today
`intstaller.lua` is an empty placeholder and there is no install/update
mechanism at all — every machine script has to be `wget`ed by hand, file by
file, including shared dependencies under `common/`.

## User flow

1. User opens a terminal on a CC computer.
2. User runs `wget https://raw.githubusercontent.com/rprih/cc/main/installer.lua installer.lua`.
3. User runs `installer.lua`.
4. Installer shows a numbered menu of available roles (read from the repo's
   manifest); user picks one.
5. Installer downloads every file that role needs (including shared
   `common/` files) to the same relative paths as in the repo, and sets that
   role's entry script to run on boot.

Re-running the same installer for the same or a different role is how
"update" works — it just re-downloads everything for the chosen role.

## Components

### `manifest.lua` (repo root)

A plain Lua file that `return`s a table describing every installable role.
Kept separate from `installer.lua` so adding a new machine type is a
manifest edit, not an installer code change.

```lua
return {
  {
    id = "fission-reactor-controller",
    name = "Fission Reactor Controller",
    files = {
      "common/communication.lua",
      "machines/fission-reactor/controller.lua",
    },
    startup = "machines/fission-reactor/controller.lua",
  },
  {
    id = "matrix-telemetry-transmitter",
    name = "Matrix Telemetry Transmitter",
    files = {
      "common/communication.lua",
      "machines/main-matrix/battery-telemetry-transmitter.lua",
    },
    startup = "machines/main-matrix/battery-telemetry-transmitter.lua",
  },
}
```

Fields:
- `id` — stable slug, unused by the installer today but kept for future
  scripting/automation against a specific role.
- `name` — human label shown in the menu.
- `files` — repo-relative paths to download, **listed explicitly per role**
  including any shared `common/` dependencies (no automatic dependency
  resolution — keeps the installer simple, at the cost of repeating shared
  paths across roles).
- `startup` — which of `files` becomes `/startup.lua`'s target.

### `installer.lua` (repo root, renamed from `intstaller.lua`)

The only file a user fetches manually. Everything else it fetches itself.

Responsibilities, in order:

1. **Fetch manifest**: `http.get(BASE_URL .. "manifest.lua")`. On failure
   (nil response or non-200), `error()` with a clear message — no retry
   logic, matches the repo's "fail loudly" convention.
2. **Parse manifest**: `load()` the returned body as a Lua chunk and call it
   to get the roles table. If `load` fails (malformed manifest), `error()`.
3. **Present menu**: numbered list of `name` fields via `term`, read a
   number from `read()`, validate it's in range (re-prompt on invalid
   input rather than crashing).
4. **Pre-flight overwrite check**: for the chosen role, compute the full
   set of target paths (`files` + `/startup.lua`). Check each with
   `fs.exists`. If any exist, print the list and ask one y/n prompt:
   "N file(s) already exist. Overwrite? (y/n)". A "no" answer aborts with
   no filesystem changes at all (nothing has been written yet at this
   point).
5. **Download files**: for each path in `files`, `http.get(BASE_URL ..
   path)`, `fs.makeDir` on the parent directory if needed, write the body
   to that relative path on the computer. Any single download failure
   aborts the whole run with `error()` — partial installs are avoided by
   checking existence up front, but a network failure mid-loop can still
   leave a partial set of files; this is accepted as a rare-enough case not
   worth transactional rollback for a hobby install script.
6. **Write startup shim**: overwrite `/startup.lua` with a one-line shim:
   `shell.run("<startup path>")`.
7. **Summary**: print what was installed and remind the user to `reboot`
   (or that they can run the entry script immediately without rebooting).

### Base URL

`https://raw.githubusercontent.com/rprih/cc/main/` — hardcoded constant in
`installer.lua`. No branch/ref selection; always installs from `main`.

## Data flow

```
GitHub (raw.githubusercontent.com/rprih/cc/main)
  │  http.get
  ▼
installer.lua ── loads manifest.lua ── shows menu ── user picks role
  │
  │  http.get per file in role.files
  ▼
Target computer filesystem (paths mirror repo layout exactly, rooted at "/")
  │
  ▼
/startup.lua  (shell.run shim → role.startup)
```

Paths are mirrored exactly (`common/communication.lua` →
`/common/communication.lua`, etc.) because the existing scripts already use
`require("common.communication")`, which CC: Tweaked's `require` shim
resolves relative to the computer's root — so `common/` must land at the
root, not nested under the role's own directory.

## Error handling

- Every `http.get` result is checked for `nil` before use; failure is a
  loud `error(...)`, not a silent skip — consistent with this repo's "no
  test harness, fail loudly" convention (see root `CLAUDE.md`).
- Invalid menu input re-prompts instead of crashing (this is the one place
  a human is actively present and typing, so a typo shouldn't blow up the
  whole install).
- Declining the overwrite prompt is a clean, no-op abort, not an error.

## Testing

There is no headless CC: Tweaked emulator configured in this repo (per
`CLAUDE.md`), so this cannot be exercised by an automated test. Verification
is manual, in-game or in an emulator, after the branch is pushed:

1. Push `manifest.lua`, `installer.lua`, and the current `common/` /
   `machines/` contents to `main` (required since the installer only ever
   reads from the pushed remote, not local disk).
2. On a test computer, `wget` and run `installer.lua`, pick a role, confirm
   files land at the right paths and `/startup.lua` runs the right script
   on reboot.
3. Re-run the installer against the same computer to confirm the
   overwrite-confirmation path works.

## Out of scope

- Uninstall/rollback.
- Selecting a branch/tag/ref other than `main`.
- Automatic dependency resolution between `common/` files and roles.
- Any GUI/monitor-based install UI — this is a `term`-only interactive
  script, run from the computer's own shell.
