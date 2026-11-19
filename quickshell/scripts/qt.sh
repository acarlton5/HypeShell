#!/usr/bin/env bash

CONFIG_DIR="$1"

if [ -z "$CONFIG_DIR" ]; then
    echo "Usage: $0 <config_dir>" >&2
    exit 1
fi

apply_qt_colors() {
    local config_dir="$1"

    set_appearance_key() {
        local config_file="$1"
        local key="$2"
        local value="$3"

        if grep -q "^${key}=" "$config_file"; then
            sed -i "s|^${key}=.*|${key}=${value}|" "$config_file"
        else
            sed -i "/^\[Appearance\]/a ${key}=${value}" "$config_file"
        fi
    }

    update_qt_config() {
        local config_file="$1"
        local color_scheme_path="$2"
        local style_name="$3"

        if [ -f "$config_file" ]; then
            if grep -q '^\[Appearance\]' "$config_file"; then
                set_appearance_key "$config_file" "custom_palette" "true"
                set_appearance_key "$config_file" "color_scheme_path" "$color_scheme_path"
                if [ -n "$style_name" ]; then
                    set_appearance_key "$config_file" "style" "$style_name"
                fi
            else
                {
                    echo ""
                    echo "[Appearance]"
                    echo "custom_palette=true"
                    echo "color_scheme_path=$color_scheme_path"
                    if [ -n "$style_name" ]; then
                        echo "style=$style_name"
                    fi
                } >>"$config_file"
            fi
        else
            {
                echo "[Appearance]"
                echo "custom_palette=true"
                echo "color_scheme_path=$color_scheme_path"
                if [ -n "$style_name" ]; then
                    echo "style=$style_name"
                fi
            } >"$config_file"
        fi
    }

    local qt5_applied=false
    local qt6_applied=false
    local missing_scheme=false
    local qt5_scheme="$config_dir/qt5ct/colors/matugen.conf"
    local qt6_scheme="$config_dir/qt6ct/colors/matugen.conf"
    local qt6_style=""
    if [ -f /usr/lib/qt6/plugins/styles/breeze6.so ] || [ -f /usr/lib64/qt6/plugins/styles/breeze6.so ]; then
        qt6_style="Breeze"
    fi

    if command -v qt5ct >/dev/null 2>&1; then
        if [ -f "$qt5_scheme" ]; then
            mkdir -p "$config_dir/qt5ct"
            update_qt_config "$config_dir/qt5ct/qt5ct.conf" "$qt5_scheme" ""
            echo "Applied Qt5ct configuration"
            qt5_applied=true
        else
            missing_scheme=true
        fi
    fi

    if command -v qt6ct >/dev/null 2>&1; then
        if [ -f "$qt6_scheme" ]; then
            mkdir -p "$config_dir/qt6ct"
            update_qt_config "$config_dir/qt6ct/qt6ct.conf" "$qt6_scheme" "$qt6_style"
            echo "Applied Qt6ct configuration"
            qt6_applied=true
        else
            missing_scheme=true
        fi
    fi

    local kde_scheme="${XDG_DATA_HOME:-$(dirname "$config_dir")/.local/share}/color-schemes/DankMatugen.colors"
    if [ -f "$kde_scheme" ] && command -v kwriteconfig6 >/dev/null 2>&1; then
        kwriteconfig6 --file kdeglobals --group General --key ColorScheme DankMatugen --notify >/dev/null 2>&1 || true
    fi

    if [ "$qt5_applied" = false ] && [ "$qt6_applied" = false ]; then
        if [ "$missing_scheme" = true ]; then
            echo "Error: Qt color scheme matugen.conf not found under $config_dir/qt{5,6}ct/colors/" >&2
            echo "Run matugen first to generate theme files" >&2
        else
            echo "Warning: Neither qt5ct nor qt6ct found" >&2
            echo "Install qt5ct or qt6ct for Qt application theming" >&2
        fi
        exit 1
    fi
}

apply_qt_colors "$CONFIG_DIR"

echo "Qt colors applied successfully"
