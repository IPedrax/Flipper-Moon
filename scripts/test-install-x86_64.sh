#!/bin/bash
# install-x86_64.sh : le choix 64/32 bits et les surcharges, contre un faux installeur
# amont (aucun réseau, aucun Steam réel, HOME jetable). Ne lance ni setup.sh ni sudo.
set -u
cd "$(dirname "$0")/.."
T="$(mktemp -d /tmp/slsm-inst.XXXXXX)"; trap 'rm -rf "$T"' EXIT
fail=0; ok() { echo "  ok   - $1"; }; ko() { echo "  FAIL - $1"; fail=$((fail+1)); }

cat > "$T/stock.sh" <<'STUB'
LANG_IS_PT=0
L() { printf '%s' "$1"; }
log_info() { echo "info: $1"; }; log_warn() { echo "warn: $1"; }; log_success() { echo "ok: $1"; }
fail() { echo "FAIL: $1"; exit 1; }
install_slsteam_moon() { echo "STOCK install_slsteam_moon"; }
install_cloudredirect() { echo "STOCK install_cloudredirect"; }
SLS_REPO=stub/stub
resolve_component_asset() { return 3; }
forge_unreachable_msg() { echo unreachable; }
set_disable_cloud() { echo "set_disable_cloud $1"; }
main() { install_slsteam_moon; install_cloudredirect; echo "args: $*"; }
[ -z "${SLSPLUGIN_LIB_ONLY:-}" ] && main "$@"
STUB

mkroot() { # $1 = with64 (1/0)  $2 = sentinel (1/0)
	rm -rf "$T/home"; mkdir -p "$T/home/.steam" "$T/home/Steam"
	echo '#!/bin/sh' > "$T/home/Steam/steam.sh"
	if [ "$1" = 1 ]; then
		mkdir -p "$T/home/Steam/steamrt64"; : > "$T/home/Steam/steamrt64/steamclient.so"
		printf '#!/bin/sh\n' > "$T/home/Steam/steamrt64/steam"; chmod +x "$T/home/Steam/steamrt64/steam"
	fi
	[ "$2" = 1 ] && : > "$T/home/Steam/.steam-disable-steamrt64-client"
	ln -s "$T/home/Steam" "$T/home/.steam/steam"
}
run() { env -u STEAM_FORCE_CLIENT HOME="$T/home" LUATOOLS_INSTALL_FILE="$T/stock.sh" "$@" bash install-x86_64.sh --noplugin 2>&1; }

mkroot 1 0; out="$(run)"
echo "$out" | grep -q 'STOCK install_slsteam_moon' && ko "64-bit: stock slsteam used" || ok "64-bit: slsteam-moon is overridden"
echo "$out" | grep -q 'No x86_64 slsteam-moon release asset' && ok "64-bit without asset/zip stops with a message" || ko "64-bit: no message without asset"

# Cloud override and option pass-through, called directly (the step above exits on purpose).
out="$(env -u STEAM_FORCE_CLIENT HOME="$T/home" LUATOOLS_INSTALL_FILE="$T/stock.sh" SLSM_X64_LIB_ONLY=1 bash -c '
	. ./install-x86_64.sh; load_stock_installer >/dev/null; define_overrides
	install_cloudredirect; echo "rc=$?"' 2>&1)"
echo "$out" | grep -q 'STOCK install_cloudredirect' && ko "64-bit: CloudRedirect not skipped" || ok "64-bit: CloudRedirect skipped"
echo "$out" | grep -q 'set_disable_cloud yes' && ok "64-bit: DisableCloud forced to yes" || ko "64-bit: DisableCloud not forced"

mkroot 1 1; out="$(run)"
echo "$out" | grep -q 'STOCK install_slsteam_moon' && echo "$out" | grep -q 'STOCK install_cloudredirect' \
	&& ok "sentinel (32-bit client): stock behaviour" || ko "sentinel: stock behaviour lost"
echo "$out" | grep -q 'args: --noplugin' && ok "stock options are passed through" || ko "options lost"

mkroot 1 1; out="$(env HOME="$T/home" STEAM_FORCE_CLIENT=steamrt64 LUATOOLS_INSTALL_FILE="$T/stock.sh" bash install-x86_64.sh 2>&1)"
echo "$out" | grep -q 'STOCK install_slsteam_moon' && ko "STEAM_FORCE_CLIENT=steamrt64 ignored" || ok "STEAM_FORCE_CLIENT=steamrt64 beats the sentinel"

mkroot 0 0; out="$(run)"
echo "$out" | grep -q 'STOCK install_slsteam_moon' && ok "no steamrt64 directory: stock behaviour" || ko "no steamrt64: not stock"

mkroot 1 0; out="$(env -u STEAM_FORCE_CLIENT HOME="$T/home" LUATOOLS_INSTALL_FILE="$T/stock.sh" LUATOOLS_INSTALL_SHA256=deadbeef bash install-x86_64.sh 2>&1)"
echo "$out" | grep -q 'does not match' && ok "pinned sha256 mismatch refuses the stock installer" || ko "sha256 pin ignored"

mkroot 1 0; out="$(env -u STEAM_FORCE_CLIENT HOME="$T/home" LUATOOLS_INSTALL_FILE="$T/stock.sh" bash install-x86_64.sh --slsteam-zip "$T/absent.zip" 2>&1)"
echo "$out" | grep -q 'Local zip not found' && ok "--slsteam-zip with a missing file stops" || ko "missing zip not detected"

# --- repoint_lumen: fixtures carry the exact lines of Lumen v2.9 ---------------
mklumen() {
	rm -rf "$T/lumen"; mkdir -p "$T/lumen/lua/menu"
	cat > "$T/lumen/lua/about.lua" <<'LUA'
  { key = "slsteam_moon", name = "slsteam-moon",    repo = "swwayps/slsteam-moon",
    mirror_key = "slsteam-moon",
    asset_pat = "^slsteam%-moon%-linux%-.*%-lumen%.zip$",
    beta_path = "dist/slsteam-moon-linux.zip" },
  { key = "plugin",       name = "LuaTools plugin", repo = "swwayps/luatools-moon",
    mirror_key = "plugin",
about.INSTALL_URL =
  "https://raw.githubusercontent.com/swwayps/luatools-moon/main/install.sh"
LUA
	printf '%s\n' 'slscheck.AUTOFIX_URL =' '  "https://raw.githubusercontent.com/swwayps/slsteam-moon/slsteam-moon/autofix.sh"' > "$T/lumen/lua/slscheck.lua"
	printf '%s\n' 'noTerm: "run:\n\ncurl -fsSL https://raw.githubusercontent.com/swwayps/slsteam-moon/slsteam-moon/autofix.sh | bash",' \
		'updateNoTerm: "run:\n\ncurl -fsSL https://raw.githubusercontent.com/swwayps/luatools-moon/main/install.sh | bash",' > "$T/lumen/lua/menu/02-i18n.js"
}
repoint() { env HOME="$T/home" SLSM_X64_LIB_ONLY=1 bash -c '
	log_warn() { echo "warn: $1"; }; L() { printf "%s" "$1"; }
	d="$1"; shift; . ./install-x86_64.sh; repoint_lumen "$d"; echo "rc=$?"' _ "$T/lumen" 2>&1; }

mklumen; out="$(repoint)"
echo "$out" | grep -q 'rc=0' && ok "repoint_lumen succeeds on Lumen v2.9 files" || ko "repoint_lumen failed: $out"
grep -rq 'swwayps/slsteam-moon' "$T/lumen" && ko "an upstream slsteam-moon reference is left" || ok "no swwayps/slsteam-moon reference left"
grep -rq 'swwayps/luatools-moon/main/install.sh' "$T/lumen" && ko "the upstream installer URL is left" || ok "no upstream installer URL left"
grep -q 'repo = "ogb4n/slsteam-moon-x64",' "$T/lumen/lua/about.lua" && ok "update check points at this repository" || ko "repo not repointed"
grep -q 'mirror_key = "slsteam-moon-x64",' "$T/lumen/lua/about.lua" && ok "upstream mirror key replaced" || ko "mirror key kept"
grep -qF '%-x86_64%.zip$' "$T/lumen/lua/about.lua" && ok "asset pattern matches the x86_64 zip" || ko "asset pattern kept"
grep -q 'repo = "swwayps/luatools-moon",' "$T/lumen/lua/about.lua" && ok "LuaTools plugin repository is left alone" || ko "plugin repository touched"
grep -q 'ogb4n/slsteam-moon-x64/main/install-x86_64.sh | bash' "$T/lumen/lua/menu/02-i18n.js" && ok "terminal hint shows this installer" || ko "terminal hint not repointed"
cp -r "$T/lumen" "$T/lumen.once"; out="$(repoint)"
echo "$out" | grep -q 'rc=0' && diff -r "$T/lumen" "$T/lumen.once" >/dev/null && ok "repoint_lumen is idempotent" || ko "second run changed something or failed"
rm "$T/lumen/lua/slscheck.lua"; out="$(repoint)"
echo "$out" | grep -q 'rc=1' && echo "$out" | grep -q 'slscheck.lua not found' && ok "a missing Lumen file is reported with rc=1" || ko "missing file not reported: $out"
mklumen; sed -i 's/mirror_key = "slsteam-moon",/mirror_key = "renamed",/' "$T/lumen/lua/about.lua"; out="$(repoint)"
echo "$out" | grep -q 'rc=1' && echo "$out" | grep -q 'expected text not found' && ok "changed Lumen text is reported with rc=1" || ko "changed text not reported: $out"

echo "== total: $fail failed =="
[ "$fail" -eq 0 ]
