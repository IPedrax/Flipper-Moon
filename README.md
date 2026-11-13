# slsteam-moon-x64

64-bit-only continuation of [swwayps/slsteam-moon](https://github.com/swwayps/slsteam-moon),
itself a fork of [SLSsteam](https://github.com/AceSLS/SLSsteam). It targets the 64-bit
Steam client (steamrt64), now the default on Linux. The 32-bit client is not supported
here; for it, use the upstream repository.

Ported to x86_64 and proven on a real client: manifest binding, live add/remove
of a game, package patching, the LuaTools/Lumen buttons, the achievements panel for
added games, and downloading a non-owned title. Hooks installed but not yet exercised:
reconcile pin, depot quarantine, parental restrictions and the stats redirect. Details
and the full status table: [`docs/X86_64.md`](docs/X86_64.md).

## Install

Requirements: Linux with the 64-bit Steam client (the default), `curl`, a terminal and
`sudo`. The installer stops Steam and asks for your password once.

**1. If you already have the upstream (32-bit) slsteam-moon / luatools-moon, remove it first.**
Run the upstream uninstaller, which cleans the old library, wrapper, launcher patches,
CloudRedirect hook, Lumen and the LuaTools plugin:

```sh
curl -fsSL https://raw.githubusercontent.com/swwayps/luatools-moon/main/uninstall.sh | bash
```

It also deletes `~/.config/SLSsteam` (your `config.yaml` and depot keys): copy that folder
first if you want to keep it. In the clean reinstall this was tested with, the Lua scripts of
the games you added (`<Steam>/config/stplug-in/`) were left in place. Installing over an
existing 32-bit install without this step has not been tested. Skip the step on a machine
that never had slsteam-moon.

**2. Install, in one command:**

```sh
curl -fsSL https://raw.githubusercontent.com/ogb4n/slsteam-moon-x64/main/install-x86_64.sh | bash
```

It downloads the latest x86_64 release of this repository, then runs the upstream
luatools-moon installer with the 64-bit pieces swapped in (Lumen and the LuaTools plugin
come from their upstream repositories). CloudRedirect is skipped because its hook is a
32-bit library: Steam Cloud is disabled for added games (`DisableCloud: yes`).

**3. Start Steam** from your applications menu. The first launch can take a while.

## Update and uninstall

- **Update:** use Lumen's About tab, "Update All", or rerun the install command above.
  The installer repoints the few places where Lumen hard-codes the upstream repositories
  (the update check, the Update All button, the auto-fix offer) to this repository, so an
  update installs the latest x86_64 release here and never the 32-bit upstream one. If a
  Lumen update changes that text, the installer warns and exits with an error.
- **Uninstall:** the same upstream `uninstall.sh` as in step 1 removes everything installed
  here as well.
- **Offline or local zip:** `./install-x86_64.sh --slsteam-zip slsteam-moon-linux-<version>-x86_64.zip`.

Build: [`docs/BUILDING.md`](docs/BUILDING.md). Upstream history is kept; the 32-bit code
is still in the tree and will be removed in a separate change.

## Credits

Upstream:

- [swwayps](https://github.com/swwayps) and contributors, slsteam-moon: the
  protocol handlers, SteamStub support and Lua manifest importer this port is built on.
- [AceSLS](https://github.com/AceSLS) and contributors —
  the hook framework, protobuf plumbing, ownership patches,
  family-share bypass, and the broader feature set this branch
  builds on.

Reference material:

- [SteamDatabase / SteamAppInfo](https://github.com/SteamDatabase/SteamAppInfo)
  — `appinfo.vdf` v41 format documentation.
- [atom0s / Steamless](https://github.com/atom0s/Steamless) —
  invoked by the wrapper-integration helper.
- [Midrags / SFF / LumaCore](https://github.com/Midrags/SFF) —
  Windows reference port for the `LoadPackage` patch logic.
- [OpenSteamTool](https://github.com/OpenSteam001/OpenSteamTool) —
  some features were ported from or inspired by this project.
  Full credit to its author.

## Support

Open an issue: https://github.com/ogb4n/slsteam-moon-x64/issues
