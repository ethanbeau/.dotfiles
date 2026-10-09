killdev() {
    local servers=(
        # JavaScript / TypeScript
        "vite"
        "wrangler"
        "expo"
        "next"
        "nuxt"
        "webpack"
        "react-scripts"
        "nodemon"
        "turbo"

        # Rust
        "trunk"
        "bacon"
        "watchexec"
        "cargo-watch"
        "cargo-leptos"
        "cargo-tauri"
        "dx"

        # Python
        "uvicorn"
        "gunicorn"
        "hypercorn"
        "daphne"
        "granian"
        "flask"
        "fastapi"
        "streamlit"
        "gradio"
        "reflex"
    )

    local commands=(
        # Rust: Cargo development commands
        '(^|/)cargo[[:space:]]+(watch|leptos[[:space:]]+watch|tauri[[:space:]]+dev)([[:space:]]|$)'

        # Python: python -m <server>
        '(^|/)python(3(\.[0-9]+)?)?[[:space:]]+-m[[:space:]]+(uvicorn|gunicorn|hypercorn|flask|fastapi|streamlit|gradio|daphne)([[:space:]]|$)'

        # Django development server
        '(^|/)python(3(\.[0-9]+)?)?[[:space:]]+([^[:space:]]*/)?manage\.py[[:space:]]+runserver([[:space:]]|$)'
    )

    echo "Terminating dev servers..."

    local server
    for server in "${servers[@]}"; do
        pkill -f "(^|/)${server}(\.[cm]?js)?([[:space:]]|$)" 2>/dev/null
    done

    local pattern
    for pattern in "${commands[@]}"; do
        pkill -f "$pattern" 2>/dev/null
    done

    echo "✅ Dev server cleanup complete!"
}
