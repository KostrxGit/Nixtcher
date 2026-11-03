# `py`: run Python scripts in a repo without nix-shell or activating anything.
#
#   py script.py [args]     run with the repo's .venv (made on first use)
#   py                      Python prompt in that environment
#   py -m pytest            any python option works as usual
#   py add requests numpy   install packages and record them in requirements.txt
#   py fresh                delete .venv and build it again
#
# The repo is the nearest folder (from where you are, upwards) with a .venv, pyproject.toml or
# requirements.txt; otherwise the git root, otherwise the current folder. Dependencies from
# requirements*.txt / pyproject.toml / uv.lock are installed again whenever those files change.
# Wheels with compiled parts (numpy, pandas, opencv, …) get the system libraries they expect.
{ lib, pkgs, ... }:
let
  python = pkgs.python3;
  libs = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    zstd
    libGL
    glib
    libxkbcommon
    fontconfig
    freetype
    dbus
    libx11
    libxext
    libsm
    libice
    libxrender
  ];

  py = pkgs.writeShellApplication {
    name = "py";
    runtimeInputs = with pkgs; [
      uv
      git
      coreutils
    ];
    text = ''
      dir=$PWD root=""
      while [ "$dir" != / ]; do
        if [ -d "$dir/.venv" ] || [ -f "$dir/pyproject.toml" ] || [ -f "$dir/requirements.txt" ]; then
          root=$dir; break
        fi
        dir=$(dirname "$dir")
      done
      root=''${root:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
      venv=$root/.venv
      export UV_PYTHON_DOWNLOADS=never
      newVenv() { uv venv --quiet --python ${python}/bin/python3 "$venv"; }
      pipInstall() { uv pip install --python "$venv/bin/python" "$@"; }

      case "''${1:-}" in
        fresh)
          rm -rf "$venv"; shift ;;
        add)
          shift
          [ $# -gt 0 ] || { echo "usage: py add <package>..."; exit 1; }
          [ -x "$venv/bin/python" ] || newVenv
          pipInstall "$@"
          if [ -f "$root/pyproject.toml" ]; then
            echo "Installed. This repo has a pyproject.toml: add them to its dependencies there."
          else
            printf '%s\n' "$@" >>"$root/requirements.txt"
            echo "Installed and added to requirements.txt."
          fi
          exit 0 ;;
      esac

      if [ ! -x "$venv/bin/python" ]; then
        echo "⚗  Preparing $venv" >&2
        newVenv
      fi

      # (Re)install dependencies when their files change
      stamp=$venv/.py-deps
      sum=$({ cat "$root"/requirements*.txt "$root/pyproject.toml" "$root/uv.lock" 2>/dev/null || true; } | sha256sum | cut -d' ' -f1)
      if [ "$sum" != "$(cat "$stamp" 2>/dev/null || true)" ]; then
        if [ -f "$root/uv.lock" ]; then
          (cd "$root" && UV_PROJECT_ENVIRONMENT=$venv uv sync --quiet --python "$venv/bin/python") >&2
        elif [ -f "$root/pyproject.toml" ]; then
          pipInstall --quiet -r "$root/pyproject.toml" >&2
        fi
        for req in "$root"/requirements*.txt; do
          [ -f "$req" ] && pipInstall --quiet -r "$req" >&2
        done
        echo "$sum" >"$stamp"
      fi

      export LD_LIBRARY_PATH=${lib.makeLibraryPath libs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      exec "$venv/bin/python" "$@"
    '';
  };
in
{
  home.packages = [
    py
    pkgs.uv
  ];
}
