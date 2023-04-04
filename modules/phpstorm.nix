moduleConfig:
{ lib, pkgs, config, ... }:

with lib;

let
  phpStormPatched = with pkgs; jetbrains.phpstorm.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        ./phpstorm.patch
      ];

      installPhase = (old.installPhase or "") + ''
        makeWrapper "$out/$pname/bin/remote-dev-server.sh" "$out/bin/$pname-remote-dev-server" \
          --prefix PATH : "$out/libexec/$pname:${pkgs.lib.makeBinPath [ pkgs.jdk pkgs.coreutils pkgs.gnugrep pkgs.which pkgs.git ]}" \
          --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath ([
            # Some internals want libstdc++.so.6
            pkgs.stdenv.cc.cc.lib pkgs.libsecret pkgs.e2fsprogs
            pkgs.libnotify
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
      Restart = "no";
      ExecStart = "${pkgs.writeShellScript "${name}.sh" ''
        ${phpStormPatched}/bin/phpstorm-remote-dev-server registerBackendLocationForGateway
      ''}";
    };
  };
}
