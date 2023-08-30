{
  description = "Flake used to setup development environment for Zephyr";

  inputs.nixpkgs.url = "nixpkgs/23.05";

  inputs.pypi-deps-db.url = "github:DavHau/pypi-deps-db";

  inputs.mach-nix = {
    url = "mach-nix";
    inputs.pypi-deps-db.follows = "pypi-deps-db";
  };

  outputs = { nixpkgs, mach-nix, ... }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};

          zephyrSdk = pkgs.callPackage ./sdk.nix { };

          pythonEnv = mach-nix.lib.${system}.mkPython {
            requirements = pkgs.lib.concatStrings (map builtins.readFile [
            ./data/requirements-base.txt
            ./data/requirements-build-test.txt
            ./data/requirements-compliance.txt
            ./data/requirements-extras.txt
            ./data/requirements-run-test.txt
          ]);
          };

          mkShell = pkgs.mkShell.override {
            stdenv = pkgs.gccMultiStdenv;
          };
        in
        {
          default = mkShell {
            buildInputs = with pkgs; [
              cmake
              ninja
              python39Packages.west # west from pythonEnv has issues with jlink runner
              pythonEnv

              zephyrSdk
            ];

            shellHook = ''
              export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
              export ZEPHYR_SDK_INSTALL_DIR=${zephyrSdk}
            '';
          };
        }
      );
    };
}
