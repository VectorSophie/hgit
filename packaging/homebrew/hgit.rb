class Hgit < Formula
  desc "Version control for TempleOS, pre-loaded in a TempleOS VM (runs under QEMU)"
  homepage "https://github.com/VectorSophie/hgit"
  url "https://github.com/VectorSophie/hgit/releases/download/v1.8.9/hgit-bundle-1.8.9.tar.gz"
  sha256 "01647bcb605ab257f519b407002263f6b2c4caeb61c695d5d3e2d41facce8a34"
  license "GPL-3.0-or-later"

  depends_on "python@3"
  depends_on "qemu"

  def install
    libexec.install Dir["*"]
    (bin/"hgit").write <<~SH
      #!/bin/sh
      exec "#{Formula["python@3"].opt_bin}/python3" "#{libexec}/hgit-launch.py" "$@"
    SH
    (bin/"hgit-type").write <<~SH
      #!/bin/sh
      exec "#{Formula["python@3"].opt_bin}/python3" "#{libexec}/hgit-type.py" "$@"
    SH
  end

  test do
    assert_match "usage", shell_output("#{bin}/hgit --help")
    assert_match "hgit bundle 1.8.9", shell_output("#{bin}/hgit --version")
  end
end
