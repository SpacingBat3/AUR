#!/usr/bin/sh -e
# shellcheck shell=sh disable=SC2086
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

VSEL='^pkgver='
STDIN=/proc/$$/fd/0

updsrcinfo() (
	cd "$PKGDIR/$1";
	makepkg --printsrcinfo > .SRCINFO
)

normalize_version() {
	version=
	while read version; do
		if [ "$(echo "$version" | cut -c1)" = "v" ]; then
			version="$(echo "$version" | cut -c 2-)";
		fi
		if [ -n "$1" ]; then
			version="$(echo "$version" | sed 's~'"$1"'~~g')";
		fi
		echo "$version"
	done
	unset version;
}

git_tag_latest() {
	version=$(git ls-remote --exit-code --refs --tags $1 $2'*');
	echo "$version" | cut -d '/' -f 3 | normalize_version $2 | \
		sort -V | tail -n1;
    unset version;
}

fetch_version() {
	case $1 in
		github) git_tag_latest "https://github.com/$2.git" $3;;
		git) git_tag_latest "$2" $3 ;;
		*) return 1 ;;
	esac;
	return 0;
}

handle_line() {
	pkgbuild="$PKGDIR/$1/PKGBUILD"
	version=$(
		grep -E $VSEL "$pkgbuild" | \
			sed -E "s/$VSEL(.*)$/\\1/g" | \
			tail -n1 | \
			normalize_version $3
	);
	version_new="$(fetch_version $2 $3 $4)"
	if [ -n "$version_new" ] && [ "$version" != "$version_new" ]; then
		echo "$1: Update from $version-N to $version_new-1...";
		sed -i.old \
			"s/$VSEL$version$/pkgver=$version_new/;s/^pkgrel=[0-9.]*/pkgrel=1/" \
			"$pkgbuild";
		echo "$1: Updating checksums for the new sources...";
		updpkgsums "$pkgbuild";
		echo "$1: Updating .SRCINFO from the new PKGBUILD...";
		updsrcinfo "$1";
		printf '%s\n' \
			"$1: Manual interaction required (commiting, pushing repo)!" \
			"    A new shell instance will be opened to commit and push changes..." \
			"    (Type 'exit' to continue updating another packages.)"
		(
			cd "$PKGDIR/$1";
			"$SHELL" < $STDIN;
			echo "$1: Shell returned code $?."
		)
	elif [ -n "$version_new" ]; then
		echo "$1: pkgver=$version is up-to-date";
	fi
	unset version version_new
}

(
	while read line; do if [ -n "$line" ] && [ "_$(echo "$line" | cut -c1)" != "_#" ]; then
		handle_line $line;
	fi; done < "$PKGDIR/UPDATESRC";
	echo
	echo "Done all jobs for now. :)"
)
unset line;