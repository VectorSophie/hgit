#!/usr/bin/env python3
"""build-nupkg.py [out_dir] - build hgit.<version>.nupkg from packaging/chocolatey
(a nupkg is an OPC zip: nuspec + tools/ + the three OPC bookkeeping parts).
Needed because `choco pack` only runs on Windows."""
import os, re, sys, uuid, zipfile
here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "packaging", "chocolatey")
out = sys.argv[1] if len(sys.argv) > 1 else "dist"
os.makedirs(out, exist_ok=True)
nuspec = open(os.path.join(here, "hgit.nuspec"), encoding="utf-8").read()
ver = re.search(r"<version>([^<]+)</version>", nuspec).group(1)
path = os.path.join(out, "hgit.%s.nupkg" % ver)
psm = "package/services/metadata/core-properties/%s.psmdcp" % uuid.uuid4().hex
with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", '<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" /><Default Extension="nuspec" ContentType="application/octet" /><Default Extension="ps1" ContentType="application/octet" /><Default Extension="psmdcp" ContentType="application/vnd.openxmlformats-package.core-properties+xml" /></Types>')
    z.writestr("_rels/.rels", '<?xml version="1.0" encoding="utf-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Type="http://schemas.microsoft.com/packaging/2010/07/manifest" Target="/hgit.nuspec" Id="R1" /><Relationship Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="/%s" Id="R2" /></Relationships>' % psm)
    z.writestr(psm, '<?xml version="1.0" encoding="utf-8"?><coreProperties xmlns="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"><creator>VectorSophie</creator><description>hgit</description><identifier>hgit</identifier><version>%s</version><keywords>hgit vcs templeos holyc qemu</keywords><lastModifiedBy>build-nupkg.py</lastModifiedBy></coreProperties>' % ver)
    z.write(os.path.join(here, "hgit.nuspec"), "hgit.nuspec")
    for f in sorted(os.listdir(os.path.join(here, "tools"))):
        z.write(os.path.join(here, "tools", f), "tools/" + f)
print(path)
