#!/usr/bin/env bash
# render-packaging.sh [dist_dir] - write the Homebrew formula and Chocolatey
# package files for the version/checksums in dist/SHA256SUMS (from build-dist.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
DIST="${1:-dist}"
VER=$(grep -oP '#define HGIT_VERSION "\K[^"]+' src/hgit-cli/Hgit.HC)
TGZ=$(grep "hgit-bundle-$VER.tar.gz" "$DIST/SHA256SUMS" | cut -d' ' -f1)
ZIP=$(grep "hgit-bundle-$VER.zip" "$DIST/SHA256SUMS" | cut -d' ' -f1)
REL="https://github.com/VectorSophie/hgit/releases/download/v$VER"

mkdir -p packaging/homebrew packaging/chocolatey/tools
cat > packaging/homebrew/hgit.rb <<RB
class Hgit < Formula
  desc "Version control for TempleOS, pre-loaded in a TempleOS VM (runs under QEMU)"
  homepage "https://github.com/VectorSophie/hgit"
  url "$REL/hgit-bundle-$VER.tar.gz"
  sha256 "$TGZ"
  license "Unlicense"

  depends_on "python@3"
  depends_on "qemu"

  def install
    libexec.install Dir["*"]
    (bin/"hgit").write <<~SH
      #!/bin/sh
      exec "#{Formula["python@3"].opt_bin}/python3" "#{libexec}/hgit-launch.py" "\$@"
    SH
    (bin/"hgit-type").write <<~SH
      #!/bin/sh
      exec "#{Formula["python@3"].opt_bin}/python3" "#{libexec}/hgit-type.py" "\$@"
    SH
  end

  test do
    assert_match "usage", shell_output("#{bin}/hgit --help")
    assert_match "hgit bundle $VER", shell_output("#{bin}/hgit --version")
  end
end
RB

cat > packaging/chocolatey/hgit.nuspec <<NS
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>hgit</id>
    <version>$VER</version>
    <title>hgit</title>
    <authors>VectorSophie</authors>
    <projectUrl>https://github.com/VectorSophie/hgit</projectUrl>
    <licenseUrl>https://unlicense.org/</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <projectSourceUrl>https://github.com/VectorSophie/hgit</projectSourceUrl>
    <bugTrackerUrl>https://github.com/VectorSophie/hgit/issues</bugTrackerUrl>
    <tags>hgit vcs templeos holyc qemu</tags>
    <summary>Version control for TempleOS, pre-loaded in a TempleOS VM</summary>
    <description>hgit is a version-control system written in HolyC that runs inside TempleOS. This package ships a TempleOS disk image with hgit already loaded, plus the hgit command (boots it in QEMU) and hgit-type (sends commands to it).</description>
    <dependencies>
      <dependency id="qemu" />
      <dependency id="python" />
    </dependencies>
  </metadata>
  <files>
    <file src="tools\\**" target="tools" />
  </files>
</package>
NS

cat > packaging/chocolatey/tools/chocolateyInstall.ps1 <<PS
\$ErrorActionPreference = 'Stop'
\$toolsDir = Split-Path -Parent \$MyInvocation.MyCommand.Definition
Install-ChocolateyZipPackage -PackageName 'hgit' -Url '$REL/hgit-bundle-$VER.zip' \`
  -UnzipLocation \$toolsDir -Checksum '$ZIP' -ChecksumType 'sha256'
\$home_dir = Join-Path \$toolsDir 'hgit-$VER'
\$bin = Join-Path \$env:ChocolateyInstall 'bin'
Set-Content -Path (Join-Path \$bin 'hgit.cmd') -Value "@echo off\`r\`npython \`"\$home_dir\\hgit-launch.py\`" %*" -Encoding Ascii
Set-Content -Path (Join-Path \$bin 'hgit-type.cmd') -Value "@echo off\`r\`npython \`"\$home_dir\\hgit-type.py\`" %*" -Encoding Ascii
PS
cat > packaging/chocolatey/tools/chocolateyUninstall.ps1 <<'PS'
$bin = Join-Path $env:ChocolateyInstall 'bin'
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $bin 'hgit.cmd'), (Join-Path $bin 'hgit-type.cmd')
PS
echo "rendered for $VER"
