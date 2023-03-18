{
  description = "My Phoenix Web App";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        elixir = pkgs.elixir; # This selects the latest Elixir version
        hex = pkgs.hex;
        rebar3 = pkgs.rebar3;
        mixRelease = pkgs.stdenv.mkDerivation rec {
          pname = "my-phoenix-app";
          version = "0.1.0";
          src = ./.;

          buildInputs = [ elixir hex rebar3 ];

          MIX_ENV = "prod";

          buildPhase = ''
            runHook preBuild
            mix local.rebar --force
            mix local.hex --force
            mix deps.get --only prod
            mix compile
            mix release --no-halt
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp -r _build/${MIX_ENV}/rel/${pname}/* $out/
            ln -s $out/bin/${pname} $out/bin/${pname}
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "My Phoenix Web App";
            inherit (elixir.meta) platforms;
            maintainers = with maintainers; [ ];
          };
        };
      in
      {
        packages = {
          default = mixRelease;
          inherit mixRelease;
        };
        nixosModules.my-phoenix-app = { config, lib, pkgs, ... }: {
          systemd.services.my-phoenix-app = {
            description = "My Phoenix Web App";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            serviceConfig = {
              ExecStart = "${mixRelease}/bin/my-phoenix-app start";
              Restart = "on-failure";
              User = "phoenix";
              Group = "phoenix";
              AmbientCapabilities = "CAP_NET_BIND_SERVICE";
              ProtectSystem = "strict";
              ProtectHome = true;
            };
          };
          users.users.phoenix = {
            description = "Phoenix User";
            group = "phoenix";
            isSystemUser = true;
          };
          users.groups.phoenix = {};
        };
      });
}
