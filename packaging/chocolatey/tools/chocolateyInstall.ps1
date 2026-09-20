$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Install-ChocolateyZipPackage -PackageName 'hgit' -Url 'https://github.com/VectorSophie/hgit/releases/download/v1.8.9/hgit-bundle-1.8.9.zip' `
  -UnzipLocation $toolsDir -Checksum 'c81d077d4a91bbcc7f3ffb147a4412bc23c9362658d69404b9270b775617219f' -ChecksumType 'sha256'
$home_dir = Join-Path $toolsDir 'hgit-1.8.9'
$bin = Join-Path $env:ChocolateyInstall 'bin'
Set-Content -Path (Join-Path $bin 'hgit.cmd') -Value "@echo off`r`npython `"$home_dir\hgit-launch.py`" %*" -Encoding Ascii
Set-Content -Path (Join-Path $bin 'hgit-type.cmd') -Value "@echo off`r`npython `"$home_dir\hgit-type.py`" %*" -Encoding Ascii
