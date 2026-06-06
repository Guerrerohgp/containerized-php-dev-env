#!/usr/bin/env bash

set -e

PLOD_HOME="${PLOD_HOME:-$HOME/.plod}"
PLOD_BIN="/usr/local/bin/plod"
PLOD_REPO="https://github.com/Guerrerohgp/phplocaldocker.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "============================================="
echo "  Plod - Global Installer"
echo "============================================="
echo ""
echo "This will install plod as a global command."
echo ""
echo "  Template location: $PLOD_HOME"
echo "  Command location:  $PLOD_BIN"
echo ""

read -r -p "Continue? [Y/n]: " confirm
if [[ "$confirm" =~ ^[nN] ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "Installing plod template to $PLOD_HOME..."

mkdir -p "$PLOD_HOME"

cp -r "$SCRIPT_DIR/docker" "$PLOD_HOME/"
cp "$SCRIPT_DIR/docker-compose.yml" "$PLOD_HOME/"
cp "$SCRIPT_DIR/.env.example" "$PLOD_HOME/"
cp "$SCRIPT_DIR/.gitignore" "$PLOD_HOME/"
cp "$SCRIPT_DIR/.gitattributes" "$PLOD_HOME/"
cp "$SCRIPT_DIR/.dockerignore" "$PLOD_HOME/"
cp "$SCRIPT_DIR/plod" "$PLOD_HOME/"
cp "$SCRIPT_DIR/plod.bat" "$PLOD_HOME/"
cp -r "$SCRIPT_DIR/public" "$PLOD_HOME/"

if [ -f "$SCRIPT_DIR/README.md" ]; then
    cp "$SCRIPT_DIR/README.md" "$PLOD_HOME/"
fi
if [ -f "$SCRIPT_DIR/LICENSE" ]; then
    cp "$SCRIPT_DIR/LICENSE" "$PLOD_HOME/"
fi
if [ -f "$SCRIPT_DIR/SECURITY.md" ]; then
    cp "$SCRIPT_DIR/SECURITY.md" "$PLOD_HOME/"
fi

echo "$PLOD_REPO" > "$PLOD_HOME/.plod-repo"

if [ -d "$SCRIPT_DIR/.git" ]; then
    git -C "$SCRIPT_DIR" rev-parse HEAD > "$PLOD_HOME/.plod-version" 2>/dev/null || echo "unknown" > "$PLOD_HOME/.plod-version"
else
    echo "unknown" > "$PLOD_HOME/.plod-version"
fi

find "$PLOD_HOME" -name "*.sh" -exec chmod +x {} \;
chmod +x "$PLOD_HOME/plod"
chmod +x "$PLOD_HOME/docker/php/start-container"

echo "Template installed."
echo ""
echo "Creating global command at $PLOD_BIN..."

cat > "$PLOD_BIN" << 'WRAPPER'
#!/usr/bin/env bash

set -e

PLOD_HOME="${PLOD_HOME:-$HOME/.plod}"
CURRENT_DIR="$(pwd)"

is_plod_project() {
    [ -f "$CURRENT_DIR/.env.example" ] && grep -q "COMPOSE_PROJECT_NAME" "$CURRENT_DIR/.env.example" 2>/dev/null
}

do_update() {
    if [ ! -d "$PLOD_HOME" ]; then
        echo "Error: Plod is not installed. Run install.sh first."
        exit 1
    fi

    local repo_url
    if [ -f "$PLOD_HOME/.plod-repo" ]; then
        repo_url=$(cat "$PLOD_HOME/.plod-repo")
    else
        repo_url="https://github.com/Guerrerohgp/phplocaldocker.git"
    fi

    local old_version="unknown"
    if [ -f "$PLOD_HOME/.plod-version" ]; then
        old_version=$(cat "$PLOD_HOME/.plod-version")
    fi

    echo ""
    echo "============================================="
    echo "  Updating Plod"
    echo "============================================="
    echo ""
    echo "  Repository: $repo_url"
    echo "  Current version: ${old_version:0:8}"
    echo ""

    local tmp_dir
    tmp_dir=$(mktemp -d)
    echo "Cloning latest version..."

    if ! git clone --depth 1 "$repo_url" "$tmp_dir" 2>/dev/null; then
        echo "Error: Failed to clone repository."
        rm -rf "$tmp_dir"
        exit 1
    fi

    local new_version
    new_version=$(git -C "$tmp_dir" rev-parse HEAD 2>/dev/null || echo "unknown")

    if [ "$old_version" = "$new_version" ]; then
        echo ""
        echo "Already up to date (version: ${new_version:0:8})."
        rm -rf "$tmp_dir"
        return 0
    fi

    echo "Updating template files..."

    rm -rf "$PLOD_HOME/docker"
    cp -r "$tmp_dir/docker" "$PLOD_HOME/"
    cp "$tmp_dir/docker-compose.yml" "$PLOD_HOME/"
    cp "$tmp_dir/.env.example" "$PLOD_HOME/"
    cp "$tmp_dir/.gitignore" "$PLOD_HOME/"
    cp "$tmp_dir/.gitattributes" "$PLOD_HOME/"
    cp "$tmp_dir/.dockerignore" "$PLOD_HOME/"
    cp "$tmp_dir/plod" "$PLOD_HOME/"
    cp "$tmp_dir/plod.bat" "$PLOD_HOME/"
    rm -rf "$PLOD_HOME/public"
    cp -r "$tmp_dir/public" "$PLOD_HOME/"

    [ -f "$tmp_dir/README.md" ] && cp "$tmp_dir/README.md" "$PLOD_HOME/"
    [ -f "$tmp_dir/LICENSE" ] && cp "$tmp_dir/LICENSE" "$PLOD_HOME/"
    [ -f "$tmp_dir/SECURITY.md" ] && cp "$tmp_dir/SECURITY.md" "$PLOD_HOME/"

    echo "$repo_url" > "$PLOD_HOME/.plod-repo"
    echo "$new_version" > "$PLOD_HOME/.plod-version"

    find "$PLOD_HOME" -name "*.sh" -exec chmod +x {} \;
    chmod +x "$PLOD_HOME/plod"
    chmod +x "$PLOD_HOME/docker/php/start-container"

    rm -rf "$tmp_dir"

    echo ""
    echo "============================================="
    echo "  Update Complete!"
    echo "============================================="
    echo ""
    echo "  Previous version: ${old_version:0:8}"
    echo "  New version:      ${new_version:0:8}"
    echo ""
    echo "  To update an existing project, run:"
    echo "    cd your-project && plod upgrade"
    echo ""
}

do_upgrade() {
    if [ ! -d "$PLOD_HOME" ]; then
        echo "Error: Plod global template is not installed. Run install.sh first."
        exit 1
    fi

    if ! is_plod_project; then
        echo "Error: Not in a plod project directory."
        echo "Navigate to a plod project directory to run 'plod upgrade'."
        exit 1
    fi

    local template_version="unknown"
    if [ -f "$PLOD_HOME/.plod-version" ]; then
        template_version=$(cat "$PLOD_HOME/.plod-version")
    fi

    echo ""
    echo "============================================="
    echo "  Upgrading Project"
    echo "============================================="
    echo ""
    echo "  Directory: $CURRENT_DIR"
    echo "  Template version: ${template_version:0:8}"
    echo ""
    echo "  This will update plod template files in your project."
    echo "  Your .env, public/, backups/, and source code will NOT be modified."
    echo ""

    read -r -p "Continue? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[nN] ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi

    echo ""
    echo "Updating template files..."

    rm -rf "$CURRENT_DIR/docker"
    cp -r "$PLOD_HOME/docker" "$CURRENT_DIR/"
    cp "$PLOD_HOME/docker-compose.yml" "$CURRENT_DIR/"
    cp "$PLOD_HOME/.dockerignore" "$CURRENT_DIR/"
    cp "$PLOD_HOME/plod" "$CURRENT_DIR/"
    cp "$PLOD_HOME/plod.bat" "$CURRENT_DIR/"

    if [ -f "$CURRENT_DIR/.env.example" ]; then
        cp "$CURRENT_DIR/.env.example" "$CURRENT_DIR/.env.example.bak"
        echo "  Backed up .env.example -> .env.example.bak"
    fi
    cp "$PLOD_HOME/.env.example" "$CURRENT_DIR/"

    cp "$PLOD_HOME/.gitignore" "$CURRENT_DIR/"
    cp "$PLOD_HOME/.gitattributes" "$CURRENT_DIR/"

    [ -f "$PLOD_HOME/README.md" ] && cp "$PLOD_HOME/README.md" "$CURRENT_DIR/"
    [ -f "$PLOD_HOME/LICENSE" ] && cp "$PLOD_HOME/LICENSE" "$CURRENT_DIR/"
    [ -f "$PLOD_HOME/SECURITY.md" ] && cp "$PLOD_HOME/SECURITY.md" "$CURRENT_DIR/"

    find "$CURRENT_DIR/docker" -name "*.sh" -exec chmod +x {} \;
    chmod +x "$CURRENT_DIR/plod"
    chmod +x "$CURRENT_DIR/docker/php/start-container"

    echo ""
    echo "============================================="
    echo "  Upgrade Complete!"
    echo "============================================="
    echo ""
    echo "  Template files updated to version ${template_version:0:8}."
    echo "  Your .env, public/, backups/, and source code were preserved."
    echo ""
    echo "  If your docker-compose.yml or .env.example changed significantly,"
    echo "  review the .env.example.bak backup and merge any custom settings."
    echo ""
    echo "  Run 'plod build' to rebuild containers with the new configuration."
    echo ""
}

if [ "$1" = "update" ]; then
    do_update
    exit 0
fi

if [ "$1" = "upgrade" ]; then
    do_upgrade
    exit 0
fi

if [ "$1" = "init" ] && ! is_plod_project; then
    echo ""
    echo "Bootstrapping new plod project in $CURRENT_DIR..."
    echo ""

    if [ ! -d "$PLOD_HOME" ]; then
        echo "Error: Plod is not installed. Run install.sh first."
        exit 1
    fi

    cp -r "$PLOD_HOME/docker" "$CURRENT_DIR/"
    cp "$PLOD_HOME/docker-compose.yml" "$CURRENT_DIR/"
    cp "$PLOD_HOME/.env.example" "$CURRENT_DIR/"
    cp "$PLOD_HOME/.gitignore" "$CURRENT_DIR/"
    cp "$PLOD_HOME/.gitattributes" "$CURRENT_DIR/"
    cp "$PLOD_HOME/.dockerignore" "$CURRENT_DIR/"
    cp "$PLOD_HOME/plod" "$CURRENT_DIR/"
    cp "$PLOD_HOME/plod.bat" "$CURRENT_DIR/"

    if [ ! -d "$CURRENT_DIR/public" ] || [ -z "$(ls -A "$CURRENT_DIR/public" 2>/dev/null)" ]; then
        mkdir -p "$CURRENT_DIR/public"
        cp "$PLOD_HOME/public/index.php" "$CURRENT_DIR/public/"
    fi

    if [ -f "$PLOD_HOME/README.md" ] && [ ! -f "$CURRENT_DIR/README.md" ]; then
        cp "$PLOD_HOME/README.md" "$CURRENT_DIR/"
    fi
    if [ -f "$PLOD_HOME/LICENSE" ] && [ ! -f "$CURRENT_DIR/LICENSE" ]; then
        cp "$PLOD_HOME/LICENSE" "$CURRENT_DIR/"
    fi
    if [ -f "$PLOD_HOME/SECURITY.md" ] && [ ! -f "$CURRENT_DIR/SECURITY.md" ]; then
        cp "$PLOD_HOME/SECURITY.md" "$CURRENT_DIR/"
    fi

    find "$CURRENT_DIR/docker" -name "*.sh" -exec chmod +x {} \;
    chmod +x "$CURRENT_DIR/plod"
    chmod +x "$CURRENT_DIR/docker/php/start-container"

    echo "Project files copied. Running setup wizard..."
    echo ""

    bash "$CURRENT_DIR/docker/scripts/init.sh"
    exit $?
fi

if [ -f "$CURRENT_DIR/plod" ] && [ "$CURRENT_DIR/plod" != "$PLOD_BIN" ]; then
    bash "$CURRENT_DIR/plod" "$@"
    exit $?
fi

if is_plod_project; then
    if [ ! -f "$CURRENT_DIR/plod" ]; then
        cp "$PLOD_HOME/plod" "$CURRENT_DIR/"
        chmod +x "$CURRENT_DIR/plod"
    fi
    bash "$CURRENT_DIR/plod" "$@"
    exit $?
fi

echo "Error: Not in a plod project directory."
echo ""
echo "Run 'plod init' in an empty directory to create a new project,"
echo "or navigate to an existing plod project directory."
exit 1
WRAPPER

chmod +x "$PLOD_BIN"

echo "Global command created."
echo ""
echo "============================================="
echo "  Installation Complete!"
echo "============================================="
echo ""
echo "You can now use plod from anywhere:"
echo ""
echo "  # Create a new project"
echo "  mkdir my-project && cd my-project"
echo "  plod init"
echo ""
echo "  # Use in an existing project"
echo "  cd my-project"
echo "  plod up"
echo "  plod composer install"
echo "  plod npm install"
echo ""
echo "  # Update global template"
echo "  plod update"
echo ""
echo "  # Upgrade an existing project"
echo "  cd my-project && plod upgrade"
echo ""
echo "To uninstall:"
echo "  rm $PLOD_BIN"
echo "  rm -rf $PLOD_HOME"
echo ""
