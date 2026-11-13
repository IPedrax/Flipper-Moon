#!/usr/bin/env bash
# ============================================================================
#  luatools-moon installer, x86_64 edition
# ============================================================================
#  Runs the stock luatools-moon installer (checks, dependencies, cleanup, Lumen,
#  LuaTools plugin, Game Mode, desktop coverage) with the pieces that cannot work
#  with the 64-bit Steam client (steamrt64) replaced:
#
#    * slsteam-moon : the x86_64 build (release asset *-x86_64.zip, or a local zip)
#                     instead of the i386 release;
#    * CloudRedirect: skipped, its hook is a 32-bit LD_PRELOAD library that a 64-bit
#                     client ignores; DisableCloud is forced to "yes" so Steam does
#                     not attempt a cloud sync nobody answers.
#
#  With the legacy 32-bit client (sentinel .steam-disable-steamrt64-client, or
#  STEAM_FORCE_CLIENT=ubuntu12_32|scout|ldlp) everything is delegated unchanged.
#
#  The stock installer is sourced, not forked: it ends with
#  `[ -z "$SLSPLUGIN_LIB_ONLY" ] && main`, so its functions load without running and
#  we override only the two above. Upstream fixes keep flowing in.
#
#  Usage
#    ./install-x86_64.sh [--slsteam-zip FILE] [stock installer options]
#    SLSM_ZIP=FILE        same as --slsteam-zip
#    LUATOOLS_INSTALL_FILE=FILE   use a local copy of the stock install.sh
#    LUATOOLS_INSTALL_URL=URL     where to fetch it (default: swwayps/luatools-moon main)
#    LUATOOLS_INSTALL_SHA256=HEX  refuse a stock installer whose sha256 differs
#
#  Build a local zip:  make && scripts/package.sh --host
# ============================================================================

set -uo pipefail

UPSTREAM_URL="${LUATOOLS_INSTALL_URL:-https://raw.githubusercontent.com/swwayps/luatools-moon/main/install.sh}"
UPSTREAM_FILE="${LUATOOLS_INSTALL_FILE:-}"
UPSTREAM_SHA256="${LUATOOLS_INSTALL_SHA256:-}"
SLSM_ZIP="${SLSM_ZIP:-}"
# x86_64 release asset of slsteam-moon (scripts/package.sh names it this way).
SLSM_X64_ASSET_GLOB='^slsteam-moon-linux-.*-x86_64\.zip$'

die() { echo "install-x86_64: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Our own options, removed before the stock parser sees the arguments.
# ---------------------------------------------------------------------------
PASSTHRU=()
while [ "$#" -gt 0 ]; do
	case "$1" in
		--slsteam-zip)   [ "$#" -ge 2 ] || die "--slsteam-zip needs a file"; SLSM_ZIP="$2"; shift ;;
		--slsteam-zip=*) SLSM_ZIP="${1#*=}" ;;
		*)               PASSTHRU+=("$1") ;;
	esac
	shift
done

# ---------------------------------------------------------------------------
# Which Steam client will actually run? Same rule as steam.sh and setup.sh:
# steamrt64 is the default; the sentinel or STEAM_FORCE_CLIENT selects the 32-bit one.
# ---------------------------------------------------------------------------
slsm_steam_root() {
	local r
	for r in "$HOME/.steam/steam" "$HOME/.steam/debian-installation" "$HOME/.local/share/Steam"; do
		if [ -f "$r/steam.sh" ]; then readlink -f "$r"; return 0; fi
	done
	return 1
}

slsm_client_is_64bit() {
	local root force64=0
	case "${STEAM_FORCE_CLIENT:-}" in
		ubuntu12_32|scout|ldlp) return 1 ;;
		steamrt64|steamrt3c|steamrt) force64=1 ;;
	esac
	root="$(slsm_steam_root)" || return 1
	if [ "$force64" != 1 ] && [ -e "$root/.steam-disable-steamrt64-client" ]; then
		return 1
	fi
	[ -x "$root/steamrt64/steam" ] && [ -f "$root/steamrt64/steamclient.so" ]
}

# ---------------------------------------------------------------------------
# Load the stock installer (functions only).
# ---------------------------------------------------------------------------
load_stock_installer() {
	local file
	if [ -n "$UPSTREAM_FILE" ]; then
		[ -f "$UPSTREAM_FILE" ] || die "LUATOOLS_INSTALL_FILE not found: $UPSTREAM_FILE"
		file="$UPSTREAM_FILE"
	else
		command -v curl >/dev/null 2>&1 || die "curl is required to fetch the stock installer"
		STOCK_TMP="$(mktemp -d)"; trap 'rm -rf "${STOCK_TMP:-}"' EXIT
		file="$STOCK_TMP/install.sh"
		curl --proto '=https' --proto-redir '=https' -fsSL --connect-timeout 15 --retry 3 \
			"$UPSTREAM_URL" -o "$file" || die "could not fetch $UPSTREAM_URL"
	fi
	if [ -n "$UPSTREAM_SHA256" ]; then
		[ "$(sha256sum "$file" | awk '{print $1}')" = "$UPSTREAM_SHA256" ] \
			|| die "stock installer sha256 does not match LUATOOLS_INSTALL_SHA256"
	else
		echo "→ stock installer sha256: $(sha256sum "$file" | awk '{print $1}')"
	fi
	# shellcheck disable=SC1090
	SLSPLUGIN_LIB_ONLY=1 . "$file"
	declare -F main >/dev/null && declare -F install_slsteam_moon >/dev/null \
		&& declare -F install_cloudredirect >/dev/null \
		|| die "the stock installer does not define main/install_slsteam_moon/install_cloudredirect"
}

# ---------------------------------------------------------------------------
# Overrides (defined after the stock functions are loaded).
# ---------------------------------------------------------------------------
define_overrides() {
	eval "orig_$(declare -f install_slsteam_moon)"
	eval "orig_$(declare -f install_cloudredirect)"

	install_slsteam_moon() {
		slsm_client_is_64bit || { orig_install_slsteam_moon; return; }

		local tmp zip extract_root setup setup_path rc=0
		tmp="$(mktemp -d)"; trap 'rm -rf "${tmp:-}"' RETURN
		zip="$tmp/slsteam-moon-x86_64.zip"
		SLS_INFO='{}'

		if [ "${OPT_SLS_CHANNEL:-stable}" = beta ]; then
			log_warn "$(L "No beta channel for the x86_64 build; using the stable asset." \
			             "Não há canal beta para o build x86_64; usando o asset stable.")"
		fi

		if [ -n "$SLSM_ZIP" ]; then
			[ -f "$SLSM_ZIP" ] || fail "$(L "Local zip not found: $SLSM_ZIP" "Zip local não encontrado: $SLSM_ZIP")"
			log_info "$(L "Using the local slsteam-moon x86_64 zip: $SLSM_ZIP" \
			             "Usando o zip local x86_64 do slsteam-moon: $SLSM_ZIP")"
			cp -- "$SLSM_ZIP" "$zip" || fail "$(L "Could not copy the zip" "Não foi possível copiar o zip")"
			if [ -f "$SLSM_ZIP.sha256" ]; then
				verify_sha256 "$zip" "$(cat "$SLSM_ZIP.sha256")" \
					|| fail "$(L "The local zip does not match its .sha256" "O zip local não bate com o .sha256")"
				log_info "$(L "Verified slsteam-moon" "Verificado: slsteam-moon")"
			else
				log_warn "$(L "No .sha256 next to the local zip; continuing unverified." \
				             "Sem .sha256 ao lado do zip local; continuando sem verificação.")"
			fi
			SLS_INFO="$(jq -cn --arg id "$(sha256sum "$zip" | awk '{print substr($1,1,12)}')" \
				'{tag:"x86_64-local", channel:"local", id:$id}' 2>/dev/null || printf '{}')"
		else
			log_info "$(L "Resolving the latest slsteam-moon x86_64 release" \
			             "Buscando a última release x86_64 do slsteam-moon")"
			# The x86_64 releases live in this repository, not in the stock installer's i386 one.
			SLS_REPO="${SLSM_X64_REPO:-ogb4n/slsteam-moon-x64}"
			resolve_component_asset stable "$SLS_REPO" "" "$SLSM_X64_ASSET_GLOB" any "" || rc=$?
			if [ "$rc" -eq 2 ]; then fail "$(forge_unreachable_msg)"; fi
			if [ "$rc" -ne 0 ]; then
				fail "$(L "No x86_64 slsteam-moon release asset found. Build one (scripts/package.sh) and pass --slsteam-zip FILE." \
				          "Nenhum asset x86_64 do slsteam-moon encontrado. Gere um (scripts/package.sh) e passe --slsteam-zip ARQUIVO.")"
			fi
			log_info "$(L "Downloading slsteam-moon (x86_64)" "Baixando slsteam-moon (x86_64)")"
			rc=0
			download_resolved_asset "$zip" "slsteam-moon" || rc=$?
			[ "$rc" -eq 0 ] || fail "$(forge_unreachable_msg)"
			SLS_INFO="$DOWNLOADED_ASSET_INFO"
		fi

		log_info "$(L "Extracting" "Extraindo")"
		extract_zip "$zip" "$tmp/extracted" || fail "$(L "Extraction failed" "Falha na extração")"
		setup="$(find "$tmp/extracted" -maxdepth 2 -name setup.sh -type f | head -n1)"
		[ -n "$setup" ] || fail "$(L "setup.sh not found in the archive." "setup.sh não encontrado no pacote.")"
		extract_root="$(dirname "$setup")"

		# The archive must really carry the build for this client: setup.sh also checks,
		# but failing here keeps the stock cleanup from being the last thing that ran.
		if [ "$(od -An -tx1 -j4 -N1 "$extract_root/bin/SLSsteam.so" 2>/dev/null | tr -d ' \n')" != 02 ]; then
			fail "$(L "The archive's SLSsteam.so is not a 64-bit build; the Steam client here is 64-bit." \
			          "O SLSsteam.so do pacote não é 64 bits; o cliente Steam aqui é 64 bits.")"
		fi

		chmod +x "$setup" 2>/dev/null || true
		log_info "$(L "Running slsteam-moon setup (this will stop Steam)" \
		             "Rodando o setup do slsteam-moon (isto vai parar a Steam)")"
		setup_path="$(path_without_slsteam_wrapper "${PATH:-}")"
		( cd "$extract_root" && PATH="$setup_path" bash "$setup" install ) \
			|| fail "$(L "slsteam-moon setup failed" "Falha no setup do slsteam-moon")"

		log_success "$(L "slsteam-moon (x86_64) installed" "slsteam-moon (x86_64) instalado")"
		seed_slsteam_config "$extract_root/res/config.yaml"
	}

	install_cloudredirect() {
		slsm_client_is_64bit || { orig_install_cloudredirect; return; }
		log_warn "$(L "CloudRedirect is not available with the 64-bit Steam client (its hook is 32-bit); skipping cloud saves." \
		             "O CloudRedirect não está disponível com o cliente Steam de 64 bits (o hook é 32 bits); pulando cloud saves.")"
		# A leftover 32-bit hook would make the wrapper LD_PRELOAD a library the client ignores.
		set_disable_cloud yes
		return 0
	}
}

main_x86_64() {
	load_stock_installer
	define_overrides
	if slsm_client_is_64bit; then
		log_info "$(L "64-bit Steam client detected: using the x86_64 slsteam-moon build." \
		             "Cliente Steam de 64 bits detectado: usando o build x86_64 do slsteam-moon.")"
	else
		log_info "$(L "32-bit Steam client in use (or Steam not initialised yet): stock behaviour." \
		             "Cliente Steam de 32 bits em uso (ou Steam ainda não inicializada): comportamento padrão.")"
	fi
	main "${PASSTHRU[@]+"${PASSTHRU[@]}"}"
}

# Sourced by tests with SLSM_X64_LIB_ONLY=1.
if [ -z "${SLSM_X64_LIB_ONLY:-}" ]; then
	main_x86_64
fi
