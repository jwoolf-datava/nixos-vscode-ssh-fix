moduleConfig:
{ lib, pkgs, config, ... }:

with lib;

let
  phpStormPatched = final: prev: pkgs.jetbrains.phpstorm.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        ./phpstorm.patch
      ];

      installPhase = (old.installPhase or "") + ''
        makeWrapper "$out/$pname/bin/remote-dev-server.sh" "$out/bin/$pname-remote-dev-server" \
          --prefix PATH : "$out/libexec/$pname:${final.lib.makeBinPath [ final.jdk final.coreutils final.gnugrep final.which final.git ]}" \
          --prefix LD_LIBRARY_PATH : "${final.lib.makeLibraryPath ([
            # Some internals want libstdc++.so.6
            final.stdenv.cc.cc.lib final.libsecret final.e2fsprogs
            final.libnotify
          ])}" \
          --set-default JDK_HOME "$jdk" \
          --set-default ANDROID_JAVA_HOME "$jdk" \
          --set-default JAVA_HOME "$jdk" \
          --set PHPSTORM_JDK "$jdk" \
          --set PHPSTORM_VM_OPTIONS ${old.vmoptsFile}
      '';
    });
in {
  options.services.phpstorm-fix = with types; {
    enable = mkEnableOption "auto-fix service for phpstorm in NixOS";
  };

  config = moduleConfig rec {
    name = "auto-fix-phpstorm";
    description = "Automatically fix the PHPStorm RemoteDev.";
    path = [ phpStormPatched ];
    serviceConfig = {
      Restart = "never";
      ExecStart = "${pkgs.writeShellScript "${name}.sh" ''
        phpstorm-remote-dev-server registerBackendLocationForGateway
      ''}";
    };
  };
}
