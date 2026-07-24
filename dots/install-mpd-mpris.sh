#!/bin/bash
set -e

VERSION="0.4.3"
BINDIR="${1:-/usr/local/bin}"

echo "Installing mpd-mpris v$VERSION to $BINDIR..."

curl -sL "https://github.com/natsukagami/mpd-mpris/archive/refs/tags/v$VERSION.tar.gz" | tar xz
cd "mpd-mpris-$VERSION"

go mod download
CGO_ENABLED=0 go build -ldflags="-s -w" -o mpd-mpris ./cmd/mpd-mpris

install -Dm755 mpd-mpris "$BINDIR/mpd-mpris"
install -Dm644 mpd-mpris.desktop /usr/share/applications/mpd-mpris.desktop
install -Dm644 services/mpd-mpris.service /usr/lib/systemd/user/mpd-mpris.service

cd ..
rm -rf "mpd-mpris-$VERSION"

echo "Done. Run: systemctl --user enable --now mpd-mpris"
