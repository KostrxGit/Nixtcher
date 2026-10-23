# Claude Code PostToolUse hook: after Claude edits a file, run the repo's own formatter and
# linter on that file. What the tools can fix is fixed silently; what is left goes back to
# Claude (exit 2 + stderr) so it cleans up before moving on.
#
# Only tools the repo already uses run (its node_modules, its dev shell), so a work repo is
# never reformatted with a style the team doesn't use. Exception: a narrow Python check for
# unused imports/variables (ruff F401/F811/F841) runs everywhere.
#
# @RUFF@ is replaced by Nix with a pinned ruff for that fallback.

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
[ -n "$file" ] && [ -f "$file" ] || exit 0

dir=$(dirname "$file")
root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")
cd "$root" || exit 0

issues=""
add() { [ -n "$1" ] && issues+="$1"$'\n'; }

# A tool from the repo: node_modules/.bin first, then the dev shell PATH
tool() {
  if [ -x "node_modules/.bin/$1" ]; then echo "node_modules/.bin/$1"
  elif command -v "$1" >/dev/null 2>&1; then command -v "$1"
  fi
}
has() { for f in "$@"; do [ -e "$f" ] && return 0; done; return 1; }
pkg_mentions() { [ -f package.json ] && grep -q "\"$1\"" package.json; }

case "$file" in
  *.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs | *.mts | *.cts | *.vue | *.svelte | *.css | *.scss | *.json)
    biome=$(tool biome)
    if [ -n "$biome" ] && has biome.json biome.jsonc; then
      unused=(--only=correctness/noUnusedImports --only=correctness/noUnusedVariables)
      "$biome" check --write "$file" >/dev/null 2>&1
      "$biome" lint --write --unsafe --only=correctness/noUnusedImports "$file" >/dev/null 2>&1 # drop unused imports
      add "$("$biome" check --colors=off --diagnostic-level=error "$file" 2>&1 | grep -v '^Checked\|^$' | head -n 30)"
      add "$("$biome" lint --colors=off "${unused[@]}" "$file" 2>&1 | grep -v '^Checked\|^$' | head -n 20)"
    else
      prettier=$(tool prettier)
      if [ -n "$prettier" ] && { pkg_mentions prettier || has .prettierrc .prettierrc.json .prettierrc.js .prettierrc.cjs .prettierrc.mjs .prettierrc.yaml prettier.config.js prettier.config.mjs prettier.config.cjs; }; then
        "$prettier" --write --log-level=silent "$file" >/dev/null 2>&1
      fi
      eslint=$(tool eslint)
      case "$file" in *.css | *.scss | *.json) eslint="" ;; esac
      if [ -n "$eslint" ] && has eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml; then
        "$eslint" --fix "$file" >/dev/null 2>&1
        # errors, plus unused-variable/import warnings (other old warnings in the file are left alone)
        add "$("$eslint" --format json "$file" 2>/dev/null | jq -r '.[].messages[]
          | select(.severity == 2 or ((.ruleId // "") | test("no-unused")))
          | "  \(.line):\(.column)  \(.message)  [\(.ruleId // "parse")]"' 2>/dev/null | head -n 40)"
      fi
    fi
    ;;
  *.py | *.pyi)
    ruff=$(command -v ruff || true)
    if [ -n "$ruff" ] && { has ruff.toml .ruff.toml || grep -qs '^\[tool\.ruff' pyproject.toml; }; then
      "$ruff" check --fix --quiet "$file" >/dev/null 2>&1
      "$ruff" format --quiet "$file" >/dev/null 2>&1
      add "$("$ruff" check --quiet --output-format concise "$file" 2>&1 | head -n 40)"
    else
      r=${ruff:-@RUFF@}
      "$r" check --isolated --select F401,F811,F841 --fix --quiet "$file" >/dev/null 2>&1
      add "$("$r" check --isolated --select F401,F811,F841 --quiet --output-format concise "$file" 2>&1 | head -n 20)"
    fi
    ;;
  *.rs)
    rustfmt=$(command -v rustfmt || true)
    if [ -n "$rustfmt" ]; then
      edition=$(grep -m1 -oE '^edition *= *"[0-9]+"' Cargo.toml 2>/dev/null | grep -oE '[0-9]+' || echo 2021)
      add "$("$rustfmt" --edition "$edition" "$file" 2>&1 | head -n 20)"
    fi
    ;;
esac

if [ -n "${issues//[$'\n ']/}" ]; then
  {
    echo "Lint found problems in ${file#"$root"/} that need fixing before you continue."
    echo "Delete unused imports, variables and dead code (don't rename them with _ to silence the warning)."
    printf '%s' "$issues"
  } >&2
  exit 2
fi
exit 0
