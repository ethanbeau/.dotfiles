gh-comments () {
    local pr_number="${1:-$(gh pr view --json number -q .number 2>/dev/null)}"

    if [[ -z "$pr_number" ]]; then
      echo "Error: No PR specified and no active PR found for current branch." >&2
      return 1
    fi

    gh api --paginate "repos/{owner}/{repo}/pulls/${pr_number}/comments" \
      --jq '.[] | "----------------------------------------\nFile: \(.path):\(.line // .original_line)\nAuthor: @\(.user.login)\n\n\(.body)\n"'
}
