# CC Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the empty `intstaller.lua` placeholder with a working `installer.lua` + `manifest.lua` pair that lets a user `wget` one file, run it, pick a machine role from a menu, and have all required scripts (including shared `common/` dependencies) downloaded to the right paths and wired up to run on boot.

**Architecture:** `manifest.lua` is a plain Lua file at the repo root that `return`s a table of installable roles (name, file list, startup entry point). `installer.lua`, also at the repo root, is the single script a user fetches manually — it downloads `manifest.lua` over HTTP, shows a menu, confirms before overwriting anything, downloads the chosen role's files to their repo-relative paths, and writes a `startup.lua` shim that runs the role's entry script on boot.

**Tech Stack:** CC: Tweaked Lua (Cobalt runtime, roughly Lua 5.1 semantics) — `http`, `fs`, `read`, `write`, `print` globals. No build system, no package manager, no test runner.

**Spec:** `docs/superpowers/specs/2026-09-15-cc-installer-design.md`

## Global Constraints

- Base URL is hardcoded: `https://raw.githubusercontent.com/rprih/cc/main/` — always installs from `main`, no ref selection (per spec's "Out of scope").
- All repo-relative paths (both in `manifest.lua` and used by `installer.lua`) are written **without** a leading `/`, e.g. `common/communication.lua`, `machines/fission-reactor/controller.lua` — CC's `fs` API treats these as root-relative already.
- Only one overwrite confirmation per install run, covering every target file (role files + `startup.lua`) at once — not a per-file prompt.
- Declining the overwrite prompt must leave the filesystem completely untouched (check before any write happens).
- Every `http.get` failure is a loud `error(...)` — no retries, no silent fallback (matches this repo's "fail loudly" convention from `CLAUDE.md`).
- No headless CC: Tweaked emulator and no local Lua interpreter are available in this environment (verified: `lua`/`luac` not installed, and installing one via Homebrew is blocked by an unaccepted Xcode license) — every verification step in this plan is a manual code trace, not an executed test. Final confirmation happens in-game, out of band from this plan.
- Do not touch or commit the user's existing unrelated in-progress edits to `machines/fission-reactor/controller.lua` or `machines/main-matrix/battery-telemetry-transmitter.lua`, or the untracked `common/` directory — those are pre-existing uncommitted work, out of scope for this plan.

---

## Task 1: `manifest.lua`

**Files:**
- Create: `manifest.lua` (repo root)

**Interfaces:**
- Produces: a Lua chunk that, when `load`ed and called, returns an array of role tables, each shaped `{ id: string, name: string, files: string[], startup: string }`. Task 2 consumes this shape directly (`role.name`, `role.files`, `role.startup`).

- [ ] **Step 1: Write `manifest.lua`**

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

- [ ] **Step 2: Manually trace the file for correctness**

Check, by reading the file (no interpreter available):
- The file is a single `return { ... }` statement — no syntax errors from unbalanced braces (count: 2 role tables, each opened/closed once, outer table opened/closed once).
- Every `files` entry is spelled exactly as the corresponding file's real repo path (compare character-for-character against `machines/fission-reactor/controller.lua` and `machines/main-matrix/battery-telemetry-transmitter.lua` on disk, and `common/communication.lua`).
- Every role's `startup` value is one of the entries already listed in that same role's `files`.
- No trailing comma issues that would be invalid in Lua 5.1 (trailing commas after the last field in a table constructor ARE valid in Lua — confirm none of the entries are missing a comma *between* fields instead).

- [ ] **Step 3: Commit**

```bash
git add manifest.lua
git commit -m "feat: add installer manifest listing machine roles"
```

---

## Task 2: `installer.lua`

**Files:**
- Create: `installer.lua` (repo root)
- Delete: `intstaller.lua` (repo root — empty, untracked, typo'd placeholder being replaced)

**Interfaces:**
- Consumes: `manifest.lua`'s role shape from Task 1 (`role.name`, `role.files` as `string[]`, `role.startup` as `string`).
- Produces: nothing consumed by later tasks — this is the last task in the plan.

- [ ] **Step 1: Remove the old placeholder**

```bash
rm intstaller.lua
```

(No `git rm` needed — `intstaller.lua` was never tracked; it only exists as an untracked empty file on disk.)

- [ ] **Step 2: Write `installer.lua`**

```lua
-- Installer for CC: Tweaked machine scripts.
-- Run this on a fresh or existing computer to install/update one of the
-- roles defined in manifest.lua.

local BASE_URL = "https://raw.githubusercontent.com/rprih/cc/main/"

local function fetch(path)
    local response, err = http.get(BASE_URL .. path)
    if not response then
        error("Failed to download '" .. path .. "': " .. tostring(err))
    end
    local body = response.readAll()
    response.close()
    return body
end

local function loadManifest()
    local source = fetch("manifest.lua")
    local chunk, err = load(source, "manifest.lua")
    if not chunk then
        error("Failed to parse manifest.lua: " .. tostring(err))
    end
    local ok, roles = pcall(chunk)
    if not ok then
        error("Failed to run manifest.lua: " .. tostring(roles))
    end
    if type(roles) ~= "table" or #roles == 0 then
        error("manifest.lua did not return a non-empty list of roles")
    end
    return roles
end

local function chooseRole(roles)
    print("Select a role to install:")
    for i, role in ipairs(roles) do
        print(i .. ". " .. role.name)
    end

    while true do
        write("> ")
        local input = read()
        local choice = tonumber(input)
        if choice and roles[choice] then
            return roles[choice]
        end
        print("Invalid selection, try again.")
    end
end

local function targetPaths(role)
    local paths = { "startup.lua" }
    for _, path in ipairs(role.files) do
        table.insert(paths, path)
    end
    return paths
end

local function confirmOverwrite(paths)
    local existing = {}
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            table.insert(existing, path)
        end
    end

    if #existing == 0 then
        return true
    end

    print("The following files already exist:")
    for _, path in ipairs(existing) do
        print("  " .. path)
    end
    write("Overwrite? (y/n): ")
    local answer = read()
    return answer == "y" or answer == "Y"
end

local function writeFile(path, contents)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    local file = fs.open(path, "w")
    file.write(contents)
    file.close()
end

local function installRole(role)
    for _, path in ipairs(role.files) do
        print("Downloading " .. path .. " ...")
        local body = fetch(path)
        writeFile(path, body)
    end

    local startupContent = "shell.run(\"" .. role.startup .. "\")\n"
    writeFile("startup.lua", startupContent)
end

local function main()
    local roles = loadManifest()
    local role = chooseRole(roles)
    local paths = targetPaths(role)

    if not confirmOverwrite(paths) then
        print("Aborted. No files were changed.")
        return
    end

    installRole(role)

    print("")
    print("Installed: " .. role.name)
    for _, path in ipairs(role.files) do
        print("  " .. path)
    end
    print("  startup.lua -> " .. role.startup)
    print("")
    print("Run 'reboot' to start it automatically, or run the entry")
    print("script directly right now.")
end

main()
```

- [ ] **Step 3: Manually trace the "happy path, no existing files" scenario**

Walk the code as if executing it, on a computer with none of the target
files present:

1. `main()` calls `loadManifest()` → `fetch("manifest.lua")` builds
   `BASE_URL .. "manifest.lua"` = `https://raw.githubusercontent.com/rprih/cc/main/manifest.lua`,
   calls `http.get`. Assume it succeeds and returns Task 1's file content.
   `load(source, "manifest.lua")` compiles it (it's a single `return {...}`,
   valid Lua) → `chunk`. `pcall(chunk)` runs it → `ok = true`,
   `roles` = the 2-element array from Task 1. `type(roles) == "table"` and
   `#roles == 2`, so no error. Returns `roles`.
2. `chooseRole(roles)` prints "Select a role to install:", then
   "1. Fission Reactor Controller" and "2. Matrix Telemetry Transmitter".
   Simulate user typing `1` → `tonumber("1") == 1`, `roles[1]` exists →
   returns the fission-reactor-controller role table.
3. `targetPaths(role)` returns
   `{"startup.lua", "common/communication.lua", "machines/fission-reactor/controller.lua"}`.
4. `confirmOverwrite(paths)`: on a computer with none of these files,
   `fs.exists` is false for all three → `existing` stays empty → returns
   `true` immediately, no prompt shown.
5. `installRole(role)`: for `"common/communication.lua"`, `fetch` downloads
   it, `writeFile` computes `fs.getDir("common/communication.lua")` =
   `"common"`, which doesn't exist yet → `fs.makeDir("common")`, then opens
   `"common/communication.lua"` for write and writes the body. Same for
   `"machines/fission-reactor/controller.lua"` → dir
   `"machines/fission-reactor"` gets created. Then writes `startup.lua`
   with content `shell.run("machines/fission-reactor/controller.lua")\n`
   (`fs.getDir("startup.lua")` is `""`, so no `makeDir` call — matches the
   `dir ~= ""` guard).
6. Final prints list both downloaded files, the `startup.lua -> ...` line,
   and the reboot reminder. No errors anywhere in this path.

Confirm each of the 6 points above matches what the code actually does by
re-reading the corresponding function. If any point doesn't match, fix the
code before moving on.

- [ ] **Step 4: Manually trace the "existing files, user declines" scenario**

Same as above through step 3, but assume `common/communication.lua`
already exists on disk (e.g. from a prior install of the other role).

1. `confirmOverwrite(paths)`: `fs.exists("common/communication.lua")` is
   true → `existing = {"common/communication.lua"}`. Since
   `#existing > 0`, prints "The following files already exist:" and
   `  common/communication.lua`, then `write("Overwrite? (y/n): ")` and
   `read()`. Simulate the user typing `n` → `answer = "n"` →
   `answer == "y" or answer == "Y"` is false → function returns `false`.
2. Back in `main()`, `confirmOverwrite` returned false → prints "Aborted.
   No files were changed." and `return`s immediately.
3. Confirm no call to `installRole` happened anywhere on this path (i.e.
   `installRole(role)` is textually after the `if not confirmOverwrite ...
   return end` guard, not before it) — check the actual line order in
   `main()`.

- [ ] **Step 5: Manually trace the "invalid menu input" scenario**

In `chooseRole`, simulate the user typing `banana` then `1`:
- `tonumber("banana")` is `nil` → the `if choice and roles[choice]` guard
  is false → prints "Invalid selection, try again." → loop repeats
  (`while true do`) → `write("> ")` prompts again.
- Second iteration: user types `1` → `tonumber("1") == 1`, `roles[1]`
  exists → returns `roles[1]`, loop exits.

Confirm the `while true do ... end` around the read/validate logic is the
only way out of `chooseRole`, i.e. there's no path where invalid input
falls through to using a `nil` role.

- [ ] **Step 6: Manually trace an `http.get` failure**

Simulate `http.get` inside `fetch("manifest.lua")` returning `nil, "Could
not resolve host"` (CC: Tweaked's documented failure shape). Confirm:
`response` is `nil` → `if not response then error(...) end` fires →
script halts with `Failed to download 'manifest.lua': Could not resolve
host` — no attempt to call `.readAll()` on a `nil` value (which would be a
different, less clear crash). Same reasoning applies to every other
`fetch(path)` call inside `installRole`, since they all go through the
same `fetch` function.

- [ ] **Step 7: Commit**

```bash
git add installer.lua
git commit -m "feat: implement CC installer script"
```

- [ ] **Step 8: Note remaining out-of-band verification for the user**

This step has no code — it's a reminder for the plan's executor to
surface to the user once Tasks 1-2 are committed:

> `manifest.lua` and `installer.lua` only work once they (and the actual
> `common/` and `machines/` files they reference) are pushed to `main` on
> GitHub — the installer always fetches from the remote, never local disk.
> The user has pre-existing uncommitted changes to
> `machines/fission-reactor/controller.lua` and
> `machines/main-matrix/battery-telemetry-transmitter.lua`, plus an
> untracked `common/` directory, that this plan intentionally left alone.
> Before testing the installer in-game, the user needs to decide what to
> do with those and push everything to `main`. Real end-to-end
> verification (run `installer.lua` on an actual/emulated CC computer,
> confirm files land correctly and `startup.lua` boots the right script)
> has to happen in-game — nothing in this plan can execute CC: Tweaked
> Lua.

---

## Self-Review Notes

- **Spec coverage:** manifest shape (Task 1) ✓; fetch/parse/menu/overwrite-check/download/startup-shim/summary (Task 2, one file per spec's "keep installer standalone" decision) ✓; hardcoded `BASE_URL` ✓; single overwrite prompt covering all files ✓; loud `error()` on every `http.get` failure ✓; path-mirroring convention ✓; manual/in-game testing approach ✓; out-of-scope items (branch selection, uninstall, dependency auto-resolution) intentionally have no task, matching the spec.
- **Placeholder scan:** no TBD/TODO markers; all verification steps carry concrete expected values, not "verify it works."
- **Type consistency:** `role.name` / `role.files` / `role.startup` used identically in Task 1's produced shape and Task 2's consumption; no renamed fields between tasks.
