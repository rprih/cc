# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

This repository holds Lua scripts for **CC: Tweaked** (ComputerCraft) computers/turtles/pocket computers running inside a Minecraft 1.21.1 (NeoForge/Forge) modpack. There is no build system, package manager, linter, or test runner — scripts are plain Lua files that get loaded onto in-game Computer/Monitor/Pocket Computer peripherals and executed by CC: Tweaked's Lua runtime (Cobalt/LuaJ, roughly Lua 5.1 semantics with CC's sandboxed API additions).

Because there's no build/lint/test tooling, "running" a script means placing it in-world (e.g. via `pastebin`, a disk drive, or a synced resource pack folder into the world's `computercraft/computer/<id>/` save directory) and executing it on an actual or emulated Computer. Favor writing code that fails loudly and is easy to eyeball-verify from the in-game monitor/terminal, since there's no automated test harness to catch mistakes.

## Modpack context

CC: Tweaked is the scripting core; the other mods below expose extra **peripherals** that `peripheral.find(...)` / `peripheral.wrap(...)` can attach to, which is the main way these scripts do anything interesting beyond vanilla ComputerCraft.

| Mod | Version | Relevance to CC: Tweaked scripts |
|---|---|---|
| CC: Tweaked | 1.21.1-forge-1.120.0.2 | Core mod providing Computers, Turtles, Pocket Computers, Monitors, the Lua runtime, and the base peripheral/`term`/`redstone` APIs. |
| Advanced Peripherals | 1.21.1-0.7.62b | Adds many peripherals (e.g. Chat Box, Player Detector, Environment Detector, Redstone Integrator) attachable to computers for sensing/automation. |
| AE2 & JEI Integration (ae2ijeintegration) | 2.1.2 | Bridges Applied Energistics 2 items with JEI; not itself a peripheral API but affects what AE2 items/recipes show up. |
| Applied Mekanistics | 1.6.3 | AE2 ↔ Mekanism compatibility (P2P/processing integration); relevant if scripts monitor/control Mekanism machines fed through AE2. |
| Colony4ComputerCraft | 1.21.1-2.8.2 | Exposes MineColonies colony data/control as a CC: Tweaked peripheral. |
| Mekanism | 1.21.1-10.7.19.85 | Adds Mekanism machines/chemicals; not a CC: Tweaked peripheral itself, but its chemicals are what `me_bridge`'s `getChemicals`/`getChemical`/`importChemical`/`exportChemical` methods read when Mekanism is piped into an AE2 network via Applied Mekanistics. |
| Create Avionics | neoforge-1.0.0-By-NoxCrafted | Adds Create-based flight/avionics contraptions; may expose peripherals for controlling Create contraptions. |
| Create Tweaked Controllers | 1.21.1-1.2.7 | Bridges Create mod components (contraptions, mechanical machinery) to CC: Tweaked peripherals/redstone. |
| Iris | neoforge-1.8.14-beta.1+mc1.21.1 | Shader/rendering mod only — no gameplay or peripheral API surface relevant to scripting. |
| MoreRed | 1.21.1-6.0.0.3 | Adds extended redstone components (wireless redstone, logic gates, etc.). |
| MoreRed CCT Compat | 1.21.1-1.3.0 | Exposes MoreRed's redstone components as CC: Tweaked peripherals. |

Note: an ME Bridge peripheral (`peripheral.find("me_bridge")`, as used in `show_me_status.lua`) is provided by **Advanced Peripherals**, which is what connects a computer to an Applied Energistics 2 (AE2) ME network for reading/managing storage. AE2 itself is not in the mod list above, so it's presumably supplied elsewhere in the modpack — treat AE2 as present when working with `me_bridge`.

### ME Bridge peripheral API (Advanced Peripherals 0.7.x)

Reference: https://docs.advanced-peripherals.de/0.7/guides/storage_system_functions/ (this "Storage System Functions" guide covers both the RS Bridge and ME Bridge — it's the accurate one to use).

**Important:** other pages under `docs.advanced-peripherals.de/0.7/peripherals/me_bridge/` (and some third-party summaries) document `listItems()`/`listCells()` — those names are wrong/stale for the installed `AdvancedPeripherals-1.21.1-0.7.62b.jar`. The real peripheral (confirmed against the mod's source on the `release/1.21.1` branch) exposes `getItems()` / `getCells()`. Calling `me.listItems()` fails at runtime with `attempt to call field 'listItems' (a nil value)`. Always use the `get*` names below.

All calls below that can fail return `table, nil` on success or `nil, err: string` on failure — check for `nil` before iterating.

- `me.getItems(filter?: table)` — list of all items in the ME system (empty/no filter table returns everything). Each entry is an item stack table with `count` (**not** `amount`), `displayName`, `name`, `maxStackSize`, `fingerprint`, `isCraftable`. Item **types used** = number of entries returned; **items total** = sum of `count` across entries.
- `me.getItem(filter: table)` — same shape as one `getItems()` entry, for a single filtered item.
- `me.getCraftableItems(filter?: table)` — same shape as `getItems()`, restricted to craftable items.
- `me.getCells()` — flat list of every storage cell across the network's ME Drives. Each entry ("AE2 Disk"): `item` (the cell item itself), `type` (AE2 key-type id, e.g. `"ae2:i"` for item cells, `"ae2:f"` for fluid cells), `bytes`, `bytesPerType`, `usedBytes`, `totalTypes`, `fuzzyMode`. There's no single "total item types" call — derive network-wide type capacity by summing `totalTypes` over cells where `type == "ae2:i"`.
- `me.getTotalItemStorage()` / `me.getUsedItemStorage()` / `me.getAvailableItemStorage()` — for AE2 (unlike RS) these are **bytes**, not item counts, and already account for both type + count overhead — the simplest single number for "how full is the network." Mirrored by `*FluidStorage()`/`*ChemicalStorage()` variants.
- `me.getFluids(filter?)`, `me.getChemicals(filter?)` — analogous listings for fluids/Mekanism chemicals.

`show_me_status.lua` combines `getItems()` (types used + item count) with `getCells()` (type capacity) and the raw `get*ItemStorage()` byte totals.

### IDE Lua diagnostics

CC: Tweaked's globals (`peripheral`, `term`, `colors`, `sleep`, `fs`, `redstone`, etc.) aren't part of standard Lua, so a generic Lua language server will flag them as "undefined global" — these warnings are expected/false positives in this repo, not real bugs.

## Architecture / conventions for scripts in this repo

- **Peripheral-driven design**: scripts typically start by resolving peripherals via `peripheral.find("<type>")` (grabs the first match) or `peripheral.wrap("<side_or_name>")` (grabs a specific one), then poll or react to that peripheral's methods in a loop. When a script needs more than one peripheral of the same type (e.g. multiple monitors), prefer `peripheral.find` with a filter function or `{ peripheral.find("monitor") }` to get all matches rather than assuming there's exactly one.
- **Monitors as output**: when writing to a `monitor` peripheral, remember it does not behave like `term` by default — set `mon.setTextScale(...)` and manage cursor position (`mon.setCursorPos`, `mon.clear`) explicitly rather than assuming terminal-style auto-scroll.
- **No shared library yet**: each `.lua` file here is currently standalone. If common helpers emerge (e.g. peripheral-lookup wrappers, formatting helpers for ME system items), factor them into a shared file and load with `dofile`/`require` (CC: Tweaked supports a `require` shim rooted at the computer's file system) rather than duplicating logic across scripts.
- **In-game testing only**: there is no headless CC: Tweaked emulator configured in this repo. Verify scripts by running them on an actual/emulated computer in the modpack world and observing monitor/terminal output.
