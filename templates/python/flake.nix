{
  description = "Python dev shell with uv";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      python = pkgs.python313;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          python
          pkgs.uv
          pkgs.ruff
          pkgs.pyright
        ];
        # uv uses this Python instead of downloading its own
        UV_PYTHON = "${python}/bin/python3";
        UV_PYTHON_DOWNLOADS = "never";
        shellHook = ''
          [ -f pyproject.toml ] || uv init --quiet --no-readme
          uv sync --quiet 2>/dev/null || true
          source .venv/bin/activate 2>/dev/null || true
        '';
      };
    };
}
