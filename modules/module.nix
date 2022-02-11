moduleConfig:
{ lib, pkgs, config, ... }:

with lib;

let
  originalNodePackage = pkgs.nodejs-14_x;

  # Adapted from https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/applications/editors/vscode/generic.nix#L181
  nodePackageFhs = pkgs.buildFHSUserEnv {
    name = originalNodePackage.name;

    # additional libraries which are commonly needed for extensions
    targetPkgs = pkgs: (with pkgs; [
      # ld-linux-x86-64-linux.so.2 and others
      glibc

      # dotnet
      curl
      icu
      libunwind
      libuuid
      openssl
      zlib

      # mono
      krb5
    ]);

    runScript = "${originalNodePackage}/bin/node";

    meta = {
      description = ''
        Wrapped variant of ${name} which launches in an FHS compatible envrionment.
        Should allow for easy usage of extensions without nix-specific modifications.
      '';
    };
  };

  originalNodePackageBin = "${originalNodePackage}/bin/node";
  nodePackageFhsBin = "${nodePackageFhs}/bin/${nodePackageFhs.name}";

  nodeBinToUse = if 
    config.services.vscode-server.useFhsNodeEnvironment
  then 
    nodePackageFhsBin
  else
    originalNodePackageBin;
in
{
  options.services.vscode-server = with types;{
    enable = mkEnableOption "auto-fix service for vscode-server in NixOS";
    nodePackage = mkOption {
      type = package;
      default = pkgs.nodejs-14_x;
    };
    useFhsNodeEnvironment = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Wraps NodeJS in a Fhs compatible envrionment. Should allow for easy usage of extensions without nix-specific modifications. 
      '';
    };
  };

  config = moduleConfig rec {
    name = "auto-fix-vscode-server";
    description = "Automatically fix the VS Code server used by the remote SSH extension";
    serviceConfig = {
      Restart = "always";
      RestartSec = 0;
      ExecStart = "${pkgs.writeShellScript "${name}.sh" ''
        set -euo pipefail
        PATH=${makeBinPath (with pkgs; [ coreutils findutils inotify-tools ])}
        fix_vscode () {
            bin_dir="$1"
            if [[ -e $bin_dir ]]; then
              find "$bin_dir" -mindepth 2 -maxdepth 2 -name node -exec ln -sfT ${nodeBinToUse} {} \;
              find "$bin_dir" -path '*/bin/rg' -exec ln -sfT ${pkgs.ripgrep}/bin/rg {} \;
            else
              mkdir -p "$bin_dir"
            fi
        }
        dirs=(
          "~/.vscode-server/bin"
          "~/.vscode-server-insiders/bin"
        )
        fix_all_vscode() {
          for bin_dir in $dirs ; do
            fix_vscode "$bin_dir"
          done
        }

        while IFS=: read -r bin_dir event; do
          # A new version of the VS Code Server is being created.
          if [[ $event == 'CREATE,ISDIR' ]]; then
            # Create a trigger to know when their node is being created and replace it for our symlink.
            touch "$bin_dir/node"
            inotifywait -qq -e DELETE_SELF "$bin_dir/node"
            fix_vscode $bin_dir
          # The monitored directory is deleted, e.g. when "Uninstall VS Code Server from Host" has been run.
          elif [[ $event == DELETE_SELF ]]; then
            # See the comments above Restart in the service config.
            exit 0
          fi
        done < <(inotifywait -q -m -e CREATE,ISDIR -e DELETE_SELF --format '%w%f:%e' "''${dirs[@]}")
      ''}";
    };
  };
}
