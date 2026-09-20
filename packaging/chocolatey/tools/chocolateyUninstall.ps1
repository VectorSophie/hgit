$bin = Join-Path $env:ChocolateyInstall 'bin'
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $bin 'hgit.cmd'), (Join-Path $bin 'hgit-type.cmd')
