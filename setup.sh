#!/usr/bin/env bash

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/ronema"
SRC_DIR="src"

function copy_files() {
    local source_path=$1
    local destination_path=$2
    local item=$3

    if cp -r "$source_path/$item" "$destination_path"; then
        echo "Copied $item to $destination_path."
    else
        echo "Error: Failed to copy $item to $destination_path."
        exit 1
    fi
}

function copy_main_script() {
    local source_path=$1
    local destination_path=$2

    if [ ! -w "$destination_path" ]; then
        echo "Info: You do not have write permissions for $destination_path."
        echo "Attempting to use sudo to copy and change permissions."
        sudo cp "$source_path/ronema" "$destination_path"
        sudo chmod +x "$destination_path/ronema"
        echo "Changed permissions of ronema to executable using sudo."
    else
        cp "$source_path/ronema" "$destination_path"
        chmod +x "$destination_path/ronema"
        echo "Copied ronema to $destination_path."
        echo "Changed permissions of ronema to executable."
    fi
}

function install() {
    mkdir -p "$CONFIG_DIR"

    copy_main_script "$SRC_DIR" "$INSTALL_DIR"

    for item in languages themes icons ronema.conf; do
        copy_files "$SRC_DIR" "$CONFIG_DIR" "$item"
    done

    echo "Ronema has been successfully installed"
    echo "Configuration files are stored in $CONFIG_DIR."
    echo "You can execute 'ronema' to run the program."
}

function uninstall() {
    local remove_conf=false

    while getopts ":h-:" opt; do
        case $opt in
            -)
                case $OPTARG in
                    remove_config)
                        remove_conf=true
                        ;;
                    *)
                        echo "Invalid option: --$OPTARG" >&2
                        exit 1
                        ;;
                esac
                ;;
            h)
                echo "Usage: $0 uninstall [--remove_config]" >&2
                exit
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done

    sudo rm -f "$INSTALL_DIR/ronema"

    if [ "$remove_conf" = true ]; then
        sudo rm -rf "$CONFIG_DIR"
    fi

    echo "Ronema has been successfully uninstalled."
    if [ "$remove_conf" = true ]; then
        echo "Configuration files have been removed."
    else
        echo "Configuration files remain in $CONFIG_DIR."
    fi
}

function update() {
    local override_conf=false
    while getopts ":h-:" opt; do
        case $opt in
            -)
                case $OPTARG in
                    override_conf)
                        override_conf=true
                        ;;
                    *)
                        echo "Invalid option: --$OPTARG" >&2
                        exit 1
                        ;;
                esac
                ;;
            h)
                echo "Usage: $0 update [--override_conf]" >&2
                exit
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done

    copy_main_script "$SRC_DIR" "$INSTALL_DIR"
    for item in languages themes icons; do
        copy_files "$SRC_DIR" "$CONFIG_DIR" "$item"
    done
    if [ "$override_conf" = true ]; then
        copy_files "$SRC_DIR" "$CONFIG_DIR" "ronema.conf"
    else
        echo "Skipping copying ronema.conf as --override_conf option is not provided."
    fi
    echo "Ronema has been successfully updated."
    echo "Configuration files are stored in $CONFIG_DIR."
    echo "You can execute 'ronema' to run the program."
}

case "$1" in
    install)
        install
        ;;
    uninstall)
        shift
        uninstall "$@"
        ;;
    update)
        shift
        update "$@"
        ;;
    *)
        echo "Usage: $0 {install|uninstall [--remove_config]|update [--override_conf]}" >&2
        exit 1
        ;;
esac
