{
  description = "NordLayer packaged from .deb";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    packages.${system}.nordlayer = pkgs.stdenvNoCC.mkDerivation rec {
      pname = "nordlayer";
      version = "3.4.1";

      src = pkgs.fetchurl {
        url = "https://downloads.nordlayer.com/linux/latest/debian/pool/main/nordlayer_${version}_amd64.deb";
        sha256 = "sha256-Q8ibtGaXXF+sI7IMIgJZPjNi5QG0kgyta5gI0ZN3lUs=";
      };

      nativeBuildInputs = with pkgs; [
        dpkg
        autoPatchelfHook
      ];

      buildInputs = with pkgs; [
        libcap_ng
      ];

      unpackPhase = ''
        runHook preUnpack
        dpkg-deb -x "$src" .
        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        cp -r usr etc var $out/
        ln -s $out/usr/bin/nordlayer $out/bin/nordlayer
        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "NordLayer client (repacked from .deb)";
        homepage = "https://nordlayer.com/";
        license = licenses.unfree;
        platforms = ["x86_64-linux"];
      };
    };

    defaultPackage.${system} = self.packages.${system}.nordlayer;

    apps.${system}.default = {
      type = "app";
      program = "${self.packages.${system}.nordlayer}/bin/nordlayer";
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = [
        self.packages.${system}.nordlayer
        pkgs.dpkg
        pkgs.patchelf
      ];
    };

    nixosModules = {
      nordlayer = {
        config,
        lib,
        pkgs,
        ...
      }: {
        options.services.nordlayer.enable =
          lib.mkEnableOption "NordLayer integration (package + systemd + nix-ld)";

        options.services.nordlayer.extraNixLdLibraries = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = with pkgs; [pkgs.libcap_ng];
          example = lib.literalExpression "with pkgs; [ openssl zlib ]";
          description = "Extra libraries for nix-ld if NordLayer dlopens them.";
        };

        config = lib.mkIf config.services.nordlayer.enable {
          environment.systemPackages = [
            self.packages.${pkgs.stdenv.hostPlatform.system}.nordlayer
          ];

          programs.nix-ld.enable = true;
          programs.nix-ld.libraries = config.services.nordlayer.extraNixLdLibraries;

          systemd.services.nordlayer = {
            description = "NordLayer Daemon";
            wantedBy = ["multi-user.target"];
            after = ["network.target"];

            serviceConfig = {
              ExecStart = "${self.packages.${pkgs.stdenv.hostPlatform.system}.nordlayer}/sbin/nordlayerd";
              RuntimeDirectory = "nordlayer";
              RuntimeDirectoryMode = "0755";
              Restart = "on-failure";
              Type = "simple";
            };
          };
        };
      };
    };
  };
}
