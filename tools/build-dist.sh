#!/usr/bin/env bash
# build-dist.sh <bundle.qcow2> [out_dir] - assemble the distributable packages
# from packaging/bundle + a refreshed disk image: a .tar.gz (Homebrew), a .zip
# (Chocolatey), and a .deb (apt/dpkg). Version = HGIT_VERSION from Hgit.HC.
set -euo pipefail
cd "$(dirname "$0")/.."
QCOW="$1"; OUT="${2:-dist}"
VER=$(grep -oP '#define HGIT_VERSION "\K[^"]+' src/hgit-cli/Hgit.HC)
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT

# common payload
P="$STAGE/hgit-$VER"; mkdir -p "$P"
cp packaging/bundle/hgit-launch.py packaging/bundle/hgit-type.py packaging/bundle/README.md "$P/"
cp LICENSE packaging/HgitAll.HC "$P/"; cp "$QCOW" "$P/templeos-hgit.qcow2"; echo "$VER" > "$P/VERSION"
(cd "$STAGE" && tar czf "$OUT/hgit-bundle-$VER.tar.gz" "hgit-$VER")
(cd "$STAGE" && python3 -c "
import zipfile,os,sys
z=zipfile.ZipFile('$OUT/hgit-bundle-$VER.zip','w',zipfile.ZIP_DEFLATED)
for r,_,fs in os.walk('hgit-$VER'):
    for f in fs: z.write(os.path.join(r,f))
z.close()")

# .deb
D="$STAGE/deb"; mkdir -p "$D/DEBIAN" "$D/usr/lib/hgit" "$D/usr/bin" "$D/usr/share/doc/hgit"
cp "$P"/hgit-launch.py "$P"/hgit-type.py "$P"/templeos-hgit.qcow2 "$P"/HgitAll.HC "$P"/VERSION "$D/usr/lib/hgit/"
cp "$P/README.md" "$P/LICENSE" "$D/usr/share/doc/hgit/"
printf '#!/bin/sh\nexec python3 /usr/lib/hgit/hgit-launch.py "$@"\n' > "$D/usr/bin/hgit"
printf '#!/bin/sh\nexec python3 /usr/lib/hgit/hgit-type.py "$@"\n' > "$D/usr/bin/hgit-type"
chmod 755 "$D/usr/bin/hgit" "$D/usr/bin/hgit-type"
printf 'hgit is licensed under the GNU GPL version 3 only; the full text is /usr/share/doc/hgit/LICENSE.\nThe bundled disk image contains TempleOS, which is public domain.\nhttps://github.com/VectorSophie/hgit\n' > "$D/usr/share/doc/hgit/copyright"
SIZE=$(du -sk "$D" | cut -f1)
cat > "$D/DEBIAN/control" <<CTRL
Package: hgit
Version: $VER
Section: devel
Priority: optional
Architecture: all
Depends: qemu-system-x86, python3
Installed-Size: $SIZE
Maintainer: VectorSophie <jay7math@gmail.com>
Homepage: https://github.com/VectorSophie/hgit
Description: hgit - version control for TempleOS, pre-loaded in a TempleOS VM
 hgit is written in HolyC and only runs inside TempleOS. This package ships a
 TempleOS disk image with hgit already installed plus a launcher (hgit) that
 boots it in QEMU and a helper (hgit-type) to send commands to it.
CTRL
dpkg-deb --build --root-owner-group "$D" "$OUT/hgit_${VER}_all.deb" >/dev/null
( cd "$OUT" && sha256sum hgit-bundle-$VER.tar.gz hgit-bundle-$VER.zip hgit_${VER}_all.deb > SHA256SUMS )
ls -la "$OUT"; cat "$OUT/SHA256SUMS"
