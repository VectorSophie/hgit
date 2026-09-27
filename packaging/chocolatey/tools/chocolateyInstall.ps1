$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Install-ChocolateyZipPackage -PackageName 'hgit' -Url 'https://github.com/VectorSophie/hgit/releases/download/v1.9.0/hgit-bundle-1.9.0.zip' `
  -UnzipLocation $toolsDir -Checksum '1cfd6ad5ab08e9894293f2e558260a774313b5c9d84bb1f89c750d9a922b80c7' -ChecksumType 'sha256'
$home_dir = Join-Path $toolsDir 'hgit-1.9.0'
$bin = Join-Path $env:ChocolateyInstall 'bin'
Set-Content -Path (Join-Path $bin 'hgit.cmd') -Value "@echo off`r`npython `"$home_dir\hgit-launch.py`" %*" -Encoding Ascii
Set-Content -Path (Join-Path $bin 'hgit-type.cmd') -Value "@echo off`r`npython `"$home_dir\hgit-type.py`" %*" -Encoding Ascii
