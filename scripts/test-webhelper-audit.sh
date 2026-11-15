#!/bin/bash
# Régression x86_64 : un processus nommé steamwebhelper sous LD_AUDIT doit démarrer et
# finir normalement (setup() y retire LD_AUDIT avant que le journal n'existe : segfault le
# 2026-11-13) ; un processus quelconque doit aussi être laissé tranquille. Un `steam` sans
# STEAM_STEAMRT_RECURSION_GUARD est le lanceur steamrt64 : aucun setup() (ses watchers
# tournaient à 100 % une fois ses descripteurs fermés), mais LD_AUDIT conservé pour le
# client qu'il relance.
set -u
cd "$(dirname "$0")/.."
LIB="$PWD/bin/SLSsteam.so"
[ -f "$LIB" ] || { echo "missing: $LIB" >&2; exit 2; }
T="$(mktemp -d /tmp/slsm-webhelper.XXXXXX)"; trap 'rm -rf "$T"' EXIT
cp "$(command -v printenv)" "$T/steamwebhelper"
cp "$(command -v printenv)" "$T/otherproc"
mkdir -p "$T/boot"
cp "$(command -v printenv)" "$T/boot/steam"
out="$(HOME="$T" LD_AUDIT="$LIB" "$T/steamwebhelper" LD_AUDIT)"; rc=$?
# printenv sort 1 si la variable est absente : c'est le résultat attendu (retirée)
[ $rc -eq 1 ] && [ -z "$out" ] || { echo "FAIL steamwebhelper: rc=$rc out='$out'"; exit 1; }
out="$(HOME="$T" LD_AUDIT="$LIB" "$T/otherproc" LD_AUDIT)"; rc=$?
[ $rc -eq 0 ] && [ "$out" = "$LIB" ] || { echo "FAIL autre processus: rc=$rc out='$out'"; exit 1; }
out="$(env -i PATH=/usr/bin:/bin HOME="$T/boot" XDG_CONFIG_HOME="$T/boot/.config" \
	XDG_DATA_HOME="$T/boot/.local/share" XDG_CACHE_HOME="$T/boot/.cache" \
	LD_AUDIT="$LIB" "$T/boot/steam" LD_AUDIT)"; rc=$?
[ $rc -eq 0 ] && [ "$out" = "$LIB" ] || { echo "FAIL lanceur: LD_AUDIT perdu rc=$rc out='$out'"; exit 1; }
log="$(cat "$T/boot/.SLSsteam.log" 2>/dev/null)"
case "$log" in *"steamrt bootstrapper"*) ;; *) echo "FAIL lanceur: pas de ligne de saut: '$log'"; exit 1;; esac
case "$log" in *"CEF:"*) echo "FAIL lanceur: setup() a tourné: '$log'"; exit 1;; esac
[ ! -e "$T/boot/.config/SLSsteam" ] || { echo "FAIL lanceur: configuration touchée"; exit 1; }
echo "PASS test-webhelper-audit"
