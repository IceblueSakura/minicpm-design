{
  description = "MiniCPM Core AI conversion workspace; use Apple's compiler via xcrun";
  inputs.nixpkgs.url = "nixpkgs";
  outputs = { nixpkgs, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [ uv cmake ninja pkg-config git b3sum jq ];
        shellHook = ''
          export SDKROOT="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
          export CC="$(/usr/bin/xcrun --find clang)"
          export CXX="$(/usr/bin/xcrun --find clang++)"
          export MACOSX_DEPLOYMENT_TARGET=27.0
          export PATH="$PWD/coreai-models/.venv/bin:$PATH"
          export USE_OS_COREAI=1
        '';
      };
    };
}
