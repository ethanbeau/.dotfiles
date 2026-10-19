killport() {
    emulate -L zsh
    local signal=TERM
    if [[ "${1:-}" == --force ]]; then
      signal=KILL
      shift
    fi
    if (( $# != 1 )) || [[ "$1" != <1-65535> ]]; then
      print -u2 'Usage: killport [--force] <port: 1-65535>'
      return 2
    fi
    local -a pids=(${(f)"$(lsof -ti tcp:"$1" -sTCP:LISTEN)"})
    if (( ! ${#pids} )); then
      echo "No process listening on port $1"
      return 1
    fi
    echo "Killing ${pids} on port $1..."
    kill -s "$signal" -- "${pids[@]}" && print "Sent SIG$signal to listeners on port $1."
}
