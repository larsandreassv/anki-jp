#!/usr/bin/env bash

ankijp_die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

ankijp_anki_bin() {
    local candidate=${ANKI_BIN:-}

    if [ -n "$candidate" ]; then
        [ -x "$candidate" ] || ankijp_die "ANKI_BIN is set but not executable: $candidate"
        printf '%s\n' "$candidate"
        return 0
    fi

    candidate=$(command -v anki || true)
    [ -n "$candidate" ] || ankijp_die "anki not found on PATH; install the core anki CLI or set ANKI_BIN"
    printf '%s\n' "$candidate"
}

ankijp_config_path() {
    printf '%s\n' "${ANKI_JP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/anki-jp/config}"
}

ankijp_load_config() {
    local config_path
    config_path=$(ankijp_config_path)
    [ -f "$config_path" ] || ankijp_die "missing config: $config_path; run 'anki-jp init' first"

    # shellcheck disable=SC1090
    . "$config_path"
}

ankijp_prompt() {
    local prompt=$1
    local placeholder=$2
    local default_value=${3:-}

    if [ "${ANKI_JP_DISABLE_GUM:-0}" != '1' ] && command -v gum >/dev/null 2>&1; then
        gum input --prompt "$prompt: " --placeholder "$placeholder" --value "$default_value"
        return 0
    fi

    local answer
    if [ -n "$default_value" ]; then
        printf '%s [%s]: ' "$prompt" "$default_value" >&2
    else
        printf '%s: ' "$prompt" >&2
    fi
    IFS= read -r answer

    if [ -n "$answer" ]; then
        printf '%s\n' "$answer"
    else
        printf '%s\n' "$default_value"
    fi
}

ankijp_kakasi_bin() {
    local candidate=${ANKI_JP_KAKASI_BIN:-}

    if [ -n "$candidate" ]; then
        [ -x "$candidate" ] || ankijp_die "ANKI_JP_KAKASI_BIN is set but not executable: $candidate"
        printf '%s\n' "$candidate"
        return 0
    fi

    candidate=$(command -v kakasi || true)
    [ -n "$candidate" ] || return 1
    printf '%s\n' "$candidate"
}

ankijp_text_is_kana() {
    local text=$1
    [ -n "$text" ] || return 1
    printf '%s\n' "$text" | grep -Pq '^[\p{Hiragana}\p{Katakana}ー・ヽヾゝゞ]+$'
}

ankijp_text_to_hiragana() {
    local text=$1
    local kakasi_bin output

    [ -n "$text" ] || {
        printf '\n'
        return 0
    }

    kakasi_bin=$(ankijp_kakasi_bin) || return 1
    output=$(printf '%s\n' "$text" | "$kakasi_bin" -JH -KH -i utf8 -o utf8) || ankijp_die "kakasi failed to convert text: $text"
    printf '%s\n' "$output" | tr -d '[:space:]'
}

ankijp_require_hiragana() {
    local text=$1
    local output

    output=$(ankijp_text_to_hiragana "$text") || ankijp_die "kakasi is required for automatic reading conversion; install kakasi or provide the reading explicitly"
    printf '%s\n' "$output"
}

ankijp_validate_value_in_list() {
    local label=$1
    local needle=$2
    shift 2

    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done

    ankijp_die "$label not found in Anki: $needle"
}

ankijp_write_config() {
    local config_path config_dir
    config_path=$(ankijp_config_path)
    config_dir=$(dirname -- "$config_path")
    mkdir -p "$config_dir"

    umask 077
    {
        printf 'ANKI_JP_RTK_DECK=%q\n' "$ANKI_JP_RTK_DECK"
        printf 'ANKI_JP_RTK_MODEL=%q\n' "$ANKI_JP_RTK_MODEL"
        printf 'ANKI_JP_RTK_KEYWORD_FIELD=%q\n' "$ANKI_JP_RTK_KEYWORD_FIELD"
        printf 'ANKI_JP_RTK_KANJI_FIELD=%q\n' "$ANKI_JP_RTK_KANJI_FIELD"
        printf 'ANKI_JP_WW_DECK=%q\n' "$ANKI_JP_WW_DECK"
        printf 'ANKI_JP_WW_MODEL=%q\n' "$ANKI_JP_WW_MODEL"
        printf 'ANKI_JP_WW_READING_FIELD=%q\n' "$ANKI_JP_WW_READING_FIELD"
        printf 'ANKI_JP_WW_DEFINITION_FIELD=%q\n' "$ANKI_JP_WW_DEFINITION_FIELD"
        printf 'ANKI_JP_WW_KANJI_FIELD=%q\n' "$ANKI_JP_WW_KANJI_FIELD"
    } >"$config_path"
}

ankijp_init() {
    local anki_bin
    anki_bin=$(ankijp_anki_bin)

    local deck_names cardtype_names rtk_fields ww_fields
    mapfile -t deck_names < <("$anki_bin" deck list)
    mapfile -t cardtype_names < <("$anki_bin" cardtype list)

    ANKI_JP_RTK_DECK=$(ankijp_prompt "RTK deck" "Existing deck name" "${ANKI_JP_RTK_DECK:-}")
    ANKI_JP_RTK_MODEL=$(ankijp_prompt "RTK card type" "Existing card type name" "${ANKI_JP_RTK_MODEL:-RTK}")
    mapfile -t rtk_fields < <("$anki_bin" cardtype fields list --cardtype "$ANKI_JP_RTK_MODEL")
    ANKI_JP_RTK_KEYWORD_FIELD=$(ankijp_prompt "RTK keyword field" "Field for the English keyword" "${ANKI_JP_RTK_KEYWORD_FIELD:-}")
    ANKI_JP_RTK_KANJI_FIELD=$(ankijp_prompt "RTK kanji field" "Field for the kanji" "${ANKI_JP_RTK_KANJI_FIELD:-}")

    ANKI_JP_WW_DECK=$(ankijp_prompt "WordWrite deck" "Existing deck name" "${ANKI_JP_WW_DECK:-}")
    ANKI_JP_WW_MODEL=$(ankijp_prompt "WordWrite card type" "Existing card type name" "${ANKI_JP_WW_MODEL:-WordWrite}")
    mapfile -t ww_fields < <("$anki_bin" cardtype fields list --cardtype "$ANKI_JP_WW_MODEL")
    ANKI_JP_WW_READING_FIELD=$(ankijp_prompt "WordWrite reading field" "Field for the hiragana reading" "${ANKI_JP_WW_READING_FIELD:-}")
    ANKI_JP_WW_DEFINITION_FIELD=$(ankijp_prompt "WordWrite definition field" "Optional short definition field; leave blank if unused" "${ANKI_JP_WW_DEFINITION_FIELD:-}")
    ANKI_JP_WW_KANJI_FIELD=$(ankijp_prompt "WordWrite kanji field" "Field for the kanji word" "${ANKI_JP_WW_KANJI_FIELD:-}")

    ankijp_validate_value_in_list "RTK deck" "$ANKI_JP_RTK_DECK" "${deck_names[@]}"
    ankijp_validate_value_in_list "RTK card type" "$ANKI_JP_RTK_MODEL" "${cardtype_names[@]}"
    ankijp_validate_value_in_list "RTK keyword field" "$ANKI_JP_RTK_KEYWORD_FIELD" "${rtk_fields[@]}"
    ankijp_validate_value_in_list "RTK kanji field" "$ANKI_JP_RTK_KANJI_FIELD" "${rtk_fields[@]}"
    ankijp_validate_value_in_list "WordWrite deck" "$ANKI_JP_WW_DECK" "${deck_names[@]}"
    ankijp_validate_value_in_list "WordWrite card type" "$ANKI_JP_WW_MODEL" "${cardtype_names[@]}"
    ankijp_validate_value_in_list "WordWrite reading field" "$ANKI_JP_WW_READING_FIELD" "${ww_fields[@]}"
    if [ -n "$ANKI_JP_WW_DEFINITION_FIELD" ]; then
        ankijp_validate_value_in_list "WordWrite definition field" "$ANKI_JP_WW_DEFINITION_FIELD" "${ww_fields[@]}"
    fi
    ankijp_validate_value_in_list "WordWrite kanji field" "$ANKI_JP_WW_KANJI_FIELD" "${ww_fields[@]}"

    ankijp_write_config
    printf 'saved config to %s\n' "$(ankijp_config_path)"
}

ankijp_add_rtk() {
    local anki_bin
    anki_bin=$(ankijp_anki_bin)
    ankijp_load_config

    local keyword=${1:-}
    local kanji=${2:-}

    [ -n "$keyword" ] || keyword=$(ankijp_prompt "Keyword" "English keyword")
    [ -n "$kanji" ] || kanji=$(ankijp_prompt "Kanji" "Single kanji or text")

    "$anki_bin" card add \
        --deck "$ANKI_JP_RTK_DECK" \
        --cardtype "$ANKI_JP_RTK_MODEL" \
        --field "$ANKI_JP_RTK_KEYWORD_FIELD" "$keyword" \
        --field "$ANKI_JP_RTK_KANJI_FIELD" "$kanji"
}

ankijp_add_wordwrite() {
    local anki_bin
    anki_bin=$(ankijp_anki_bin)
    ankijp_load_config

    local arg1=${1:-}
    local arg2=${2:-}
    local arg3=${3:-}
    local reading=''
    local kanji=''
    local definition=''
    local reading_default=''
    local args=()

    case "$#" in
        0)
            ;;
        1)
            if ankijp_text_is_kana "$arg1"; then
                reading=$arg1
            else
                kanji=$arg1
                reading=$(ankijp_require_hiragana "$kanji")
            fi
            ;;
        2)
            if ankijp_text_is_kana "$arg1"; then
                reading=$arg1
                kanji=$arg2
            else
                kanji=$arg1
                definition=$arg2
                reading=$(ankijp_require_hiragana "$kanji")
            fi
            ;;
        3)
            reading=$arg1
            kanji=$arg2
            definition=$arg3
            ;;
    esac

    [ -n "$kanji" ] || kanji=$(ankijp_prompt "Written form" "Word written with kanji or kana")

    if [ -z "$reading" ]; then
        reading_default=$(ankijp_text_to_hiragana "$kanji" || true)
        reading=$(ankijp_prompt "Reading" "Hiragana reading" "$reading_default")
    fi

    if [ -n "$ANKI_JP_WW_DEFINITION_FIELD" ] && [ -z "$definition" ]; then
        definition=$(ankijp_prompt "Definition" "Optional short definition")
    fi

    args+=(
        --deck "$ANKI_JP_WW_DECK"
        --cardtype "$ANKI_JP_WW_MODEL"
        --field "$ANKI_JP_WW_READING_FIELD" "$reading"
        --field "$ANKI_JP_WW_KANJI_FIELD" "$kanji"
    )

    if [ -n "$definition" ]; then
        [ -n "$ANKI_JP_WW_DEFINITION_FIELD" ] || ankijp_die "a definition was provided, but no WordWrite definition field is configured; rerun 'anki-jp init'"
        args+=(--field "$ANKI_JP_WW_DEFINITION_FIELD" "$definition")
    fi

    "$anki_bin" card add "${args[@]}"
}
