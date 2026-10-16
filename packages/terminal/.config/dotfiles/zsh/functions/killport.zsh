killport() {
    if [[ -z "$1" ]]; then
      echo "Usage: killport <port>   (e.g., killport 3000)"
      return 1
    fi
    local -a pids=(${(f)"$(lsof -ti tcp:"$1" -sTCP:LISTEN)"})
    if (( ! ${#pids} )); then
      echo "No process listening on port $1"
      return 1
    fi
    echo "Killing ${pids} on port $1..."
    kill -9 $pids && echo "✅ Port $1 cleared."
}
