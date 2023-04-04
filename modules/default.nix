let
  moduleConfig = name: description: serviceConfig: {
    systemd.user.services.${name} = {
      inherit description serviceConfig;
      wantedBy = [ "default.target" ];
      unitConfig.ConditionUser = "!@system";
    };
  };
in
{
  imports = [
    (import ./vscode.nix ({ name, description, serviceConfig, ... }: (moduleConfig name description serviceConfig)))
    (import ./phpstorm.nix ({ name, description, serviceConfig, ... }: (moduleConfig name description serviceConfig)))
  ];
}
