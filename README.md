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

Install (builds a 64-bit library, then runs the stock luatools-moon installer with
the pieces that cannot work on a 64-bit client replaced):

```sh
./install-x86_64.sh --slsteam-zip slsteam-moon-linux-<version>-x86_64.zip
```

Updates: after installing Lumen, the installer repoints the few places where Lumen
hard-codes the upstream repositories (the About tab's update check, the Update All
button, the auto-fix offer) to this repository, so Update All installs the latest
x86_64 release here instead of the 32-bit upstream one. Lumen and the LuaTools plugin
themselves are still downloaded from their upstream repositories.

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
