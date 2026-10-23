# Sigurd: an original pixel-art pony who now and then trots along the bottom of the screen
# (theme/sigurd). Click him for a joke, a tip or a shortcut; `sigurd say "text"` makes him
# carry a message in (long rebuilds and encounters use this). He only takes clicks on
# himself and his bubble, and stays under fullscreen windows.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  src = ../../theme/sigurd;
  python = pkgs.python3.withPackages (ps: [
    ps.pygobject3
    ps.pycairo
  ]);

  sigurd = pkgs.stdenv.mkDerivation {
    pname = "sigurd";
    version = "1.0.0";
    src = lib.fileset.toSource {
      root = src;
      fileset = lib.fileset.unions [
        (src + "/sigurd.py")
        (src + "/sigurd_core.py")
        (src + "/frames")
      ];
    };
    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.wrapGAppsHook4
      pkgs.gobject-introspection
    ];
    buildInputs = [
      pkgs.gtk4
      pkgs.gtk4-layer-shell
    ];
    dontWrapGApps = true; # the Python wrapper below gets the GTK environment instead
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/sigurd $out/bin
      cp -r sigurd.py sigurd_core.py frames $out/share/sigurd/
      runHook postInstall
    '';
    # gtk4-layer-shell must be loaded before libwayland, hence LD_PRELOAD
    postFixup = ''
      makeWrapper ${python}/bin/python3 $out/bin/sigurd \
        --add-flags $out/share/sigurd/sigurd.py \
        --set LD_PRELOAD ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so \
        "''${gappsWrapperArgs[@]}"
    '';
    meta.mainProgram = "sigurd";
  };
in
{
  home.packages = [ sigurd ];

  xdg.configFile."sigurd/config.json".text = builtins.toJSON {
    enabled = true;
    visitEveryMinutes = 40; # on average; between 20 and 60 minutes apart
    activeFrom = 9; # only visits between 9:00 ...
    activeTo = 22; # ... and 22:00 (messages from `sigurd say` come any time)
    frames = "${sigurd}/share/sigurd/frames";
  };

  systemd.user.services.sigurd = {
    Unit = {
      Description = "Sigurd, the pony at the bottom of the screen";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };
    Service = {
      ExecStart = lib.getExe sigurd;
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
