{
  description = "Sigil shell assistant";

  inputs = {
    nixpkgs.url = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, treefmt-nix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        treefmt-nix.flakeModule
      ];

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        {
          config,
          pkgs,
          self',
          ...
        }:
        let
          python = pkgs.python311;
          pythonPackages = pkgs.python311Packages;
          runtimeBins = with pkgs; [
            bash
            fzf
            git
            glow
            zsh
          ];
        in
        {
          packages.sigil = pythonPackages.buildPythonApplication {
            pname = "sigil-sh";
            version = "0.1.0";
            pyproject = true;

            src = ./.;

            build-system = with pythonPackages; [
              setuptools
              setuptools-scm
            ];

            dependencies = with pythonPackages; [
              click
            ];

            buildInputs = runtimeBins;

            nativeCheckInputs =
              runtimeBins
              ++ (with pythonPackages; [
                pytestCheckHook
              ]);

            preCheck = ''
              substituteInPlace tests/test_shell_bindings.py \
                --replace-fail "#!/usr/bin/env bash" "#!${pkgs.bash}/bin/bash"
            '';

            makeWrapperArgs = [
              "--prefix"
              "PATH"
              ":"
              "${pkgs.lib.makeBinPath runtimeBins}"
            ];

            pythonImportsCheck = [
              "sigil"
            ];

            meta = with pkgs.lib; {
              description = "Verb-first LLM interaction for the shell";
              homepage = "https://github.com/rlouf/sigil";
              license = licenses.asl20;
              mainProgram = "sigil";
            };
          };

          packages.sigil-shell-bindings = pkgs.stdenv.mkDerivation {
            pname = "sigil-shell-bindings";
            version = "0.1.0";

            src = ./src/sigil/shell;

            installPhase = ''
              cp -r . $out
            '';
          };

          packages.default = self'.packages.sigil;

          treefmt = {
            projectRootFile = "flake.nix";

            programs = {
              nixfmt.enable = true;

              ruff-format = {
                enable = true;
                excludes = [
                  "docs/demos/**"
                ];
              };
            };
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.treefmt.build.devShell
            ];

            packages = runtimeBins ++ [
              pkgs.pre-commit
              pkgs.ruff
              pkgs.uv
              python
            ];
          };
        };
    };
}
