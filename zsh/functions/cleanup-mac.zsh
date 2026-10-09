cleanup-mac() {
  local cargo_home="${CARGO_HOME:-$HOME/.cargo}"

  echo '🧹 Sweeping up developer trash...'

  # ── Apple / Xcode ──────────────────────────
  rm -rf ~/Library/Developer/Xcode/DerivedData/*(N) \
    && echo '✅ Xcode Derived Data cleared'

  (( $+commands[xcrun] )) \
    && xcrun simctl delete unavailable \
    && echo '✅ Unavailable Simulators deleted'

  # ── JavaScript / TypeScript ────────────────
  (( $+commands[npm] )) \
    && npm cache clean --force \
    && echo '✅ NPM cache cleared'

  (( $+commands[yarn] )) \
    && yarn cache clean \
    && echo '✅ Yarn cache cleared'

  (( $+commands[pnpm] )) \
    && pnpm store prune \
    && echo '✅ PNPM store pruned'

  (( $+commands[bun] )) \
    && bun pm cache rm \
    && echo '✅ Bun cache cleared'

  # ── Rust ───────────────────────────────────
  if [[ -d "$cargo_home/registry/cache" ]]; then
    rm -rf "$cargo_home/registry/cache" \
      && echo '✅ Cargo downloaded crate cache cleared'
  fi

  # ── Python ─────────────────────────────────
  if (( $+commands[python3] )) \
    && python3 -m pip --version &>/dev/null; then
    python3 -m pip cache purge \
      && echo '✅ pip cache cleared'
  fi

  (( $+commands[uv] )) \
    && uv cache prune \
    && echo '✅ uv cache pruned'

  (( $+commands[poetry] )) \
    && poetry cache clear --all \
    && echo '✅ Poetry cache cleared'

  # ── Android ────────────────────────────────
  rm -rf ~/.gradle/caches/*(N) \
    && echo '✅ Gradle caches cleared'

  # ── Homebrew ───────────────────────────────
  (( $+commands[brew] )) \
    && brew cleanup \
    && echo '✅ Homebrew cleanup complete'

  # ── Optional project cleanup ──────────────
  if [[ "${1:-}" == "--project" ]]; then
    echo '🧹 Cleaning current project...'

    # Rust build artifacts
    if [[ -f Cargo.toml ]] \
      && (( $+commands[cargo] )); then
      cargo clean \
        && echo '✅ Rust build artifacts cleared'
    fi

    # Python project caches
    if [[ -f pyproject.toml || -f requirements.txt \
       || -f setup.py || -f pytest.ini ]]; then

      rm -rf .pytest_cache .mypy_cache \
             .ruff_cache .hypothesis

      echo '✅ Python test and lint caches cleared'

      # Remove Python bytecode caches recursively.
      # Exclude environments and dependency directories.
      find . \( -name .git -o -name .venv \
                 -o -name venv -o -name node_modules \
                 -o -name target \) -prune -o \
             -type d -name __pycache__ -prune \
             -exec rm -rf {} +

      echo '✅ Python bytecode caches cleared'
    fi
  fi

  echo '✨ Your Mac is clean.'
}
