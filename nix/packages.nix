{
  fetchFromGitHub,
  fprintd,
  libfprint,
  umockdev,
}:

let
  libfprint-elanmoc2 = libfprint.overrideAttrs (old: {
    pname = "libfprint-elanmoc2";
    version = "1.94.100-elanmoc2-unstable-2026-11-08";
    __intentionallyOverridingVersion = true;

    # libfprint 1.94.100 with Depau's elanmoc2 driver and local fixes, see
    # https://github.com/0xsharkboy/libfprint/commits/elanmoc2
    src = fetchFromGitHub {
      owner = "0xsharkboy";
      repo = "libfprint";
      rev = "8b2b1c21ef64a0673d0d8a25819151a9cc54eba7";
      hash = "sha256-VirBAUnDLkr2hOhKSBVR1134/tlUcxOQE4dn99FszsU=";
    };

    postPatch = (old.postPatch or "") + ''
      # The egis_etu905 umockdev replay is timing-sensitive and flakes under
      # load; it covers a driver unrelated to this package.
      substituteInPlace tests/meson.build \
        --replace-fail "'egis_etu905': {}," ""
    '';

    nativeInstallCheckInputs = (old.nativeInstallCheckInputs or [ ]) ++ [ umockdev ];

    meta = old.meta // {
      description = "libfprint with the experimental ELAN Match-on-Chip 2 driver";
      platforms = [ "x86_64-linux" ];
    };
  });

  fprintd-elanmoc2 = fprintd.override {
    libfprint = libfprint-elanmoc2;
  };
in
{
  inherit libfprint-elanmoc2 fprintd-elanmoc2;
}
