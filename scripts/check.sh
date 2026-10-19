#!/usr/bin/env bash
set -eo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

for tool in python3 zsh stow shellcheck ruff ty; do
  command -v "$tool" >/dev/null || {
    printf 'Missing check dependency: %s\n' "$tool" >&2
    exit 1
  }
done

bash_files=(scripts/*.sh scripts/lib/*.sh packages/terminal/.config/dotfiles/zsh/lib/homebrew.sh)
sh_files=(packages/linux/.local/bin/bat packages/linux/.local/bin/fd packages/terminal/.local/bin/lazygit-delta)
for file in "${bash_files[@]}"; do bash -n "$file"; done
for file in "${sh_files[@]}"; do sh -n "$file"; done
while IFS= read -r -d '' file; do zsh -n "$file"; done < <(
  find packages -type f \( -name '*.zsh' -o -name '.zshrc' -o -name '.zprofile' \) -print0
)
shellcheck -x "${bash_files[@]}" "${sh_files[@]}"
ruff check scripts tests
ruff format --check scripts tests
ty check scripts tests
python3 -m unittest discover -s tests -v
