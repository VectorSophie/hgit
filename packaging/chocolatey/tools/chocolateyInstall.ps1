$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Install-ChocolateyZipPackage -PackageName 'hgit' -Url 'https://github.com/VectorSophie/hgit/releases/download/v1.8.9/hgit-bundle-1.8.9.zip' `
  -UnzipLocation $toolsDir -Checksum 'fb64f16b4e9dc080ab4aec6247c39ee9e6e01d544a74db6413a72af122a7e800' -ChecksumType 'sha256'
$home_dir = Join-Path $toolsDir 'hgit-1.8.9'
$bin = Join-Path $env:ChocolateyInstall 'bin'
Set-Content -Path (Join-Path $bin 'hgit.cmd') -Value "@echo off`r`npython `"$home_dir\hgit-launch.py`" %*" -Encoding Ascii
Set-Content -Path (Join-Path $bin 'hgit-type.cmd') -Value "@echo off`r`npython `"$home_dir\hgit-type.py`" %*" -Encoding Ascii
