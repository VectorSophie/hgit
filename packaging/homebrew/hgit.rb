class Hgit < Formula
  desc "Version control for TempleOS, pre-loaded in a TempleOS VM (runs under QEMU)"
  homepage "https://github.com/VectorSophie/hgit"
  url "https://github.com/VectorSophie/hgit/releases/download/v1.8.9/hgit-bundle-1.8.9.tar.gz"
  sha256 "f6a7a85a131c8f8b8b7b251efa1c471e81016ef45a75acd05ffe0ab2288f94f5"
  license "GPL-3.0-only"

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
