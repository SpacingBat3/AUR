#!/usr/bin/sh -e
# shellcheck shell=sh
#
# Scan this repo for updates of local packages, as long as they're installed.
# This works fine assuming you have `pacman` package installed.
# (i.e this should work with every standard Arch builds)
#
# ========================================================================
#
# ISC License
#
# Copyright (c) 2024 Dawid Papiewski "SpacingBat3"
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# ========================================================================

PKGDIR="${0%/*}/../packages"

# Simplified way of reading vars without parsing the script
# (sourcing would be incompatible with Bourne shell due to arrays).
read_package_meta() {
    grep "$2=" "$PKGDIR/$1/PKGBUILD" | cut -d'=' -f2
}

for pkg in "$PKGDIR/"*; do if [ -d "$pkg" ]; then
	pkg="$(basename "$pkg")"
	# Check if local package is installed and store its ver to var
	if lpkgver="$(pacman -Q "$pkg" | awk '{print $2}')" 2>/dev/null && [ -n "$lpkgver" ]; then
		# Read and format ver from PKGBUILD
		rpkgver="$(read_package_meta "$pkg" pkgver)-$(read_package_meta "$pkg" pkgrel)"
		if _repoch="$(read_package_meta "$pkg" epoch)" && [ -n "$_repoch" ]; then
			rpkgver="$_repoch:$rpkgver"
			unset _repoch
		fi
		# Compare between two package versions
		vercmp="$(vercmp "$lpkgver" "$rpkgver")"
		# Handle different version cases
		if [ "$vercmp" -lt 0 ]; then (
			echo "$pkg: $lpkgver < $rpkgver, updating..."
			cd "$PKGDIR/$pkg"
			makepkg -cCsi
		); elif [ "$vercmp" -gt 0 ]; then
			echo "$pkg: local package is newer than in repo! ($lpkgver > $rpkgver)"
		else
			echo "$pkg: up-to-date ($lpkgver), doing nothing..."
		fi
	fi
fi; done