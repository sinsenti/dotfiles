paste_image() {
    local filename basename

    printf 'Image filename (leave blank for timestamped default): '
    IFS= read -r filename || return 1

    if [[ -z "$filename" ]]; then
        filename="image_$(date +'%Y-%m-%d_%H-%M-%S').png"
    else
        basename="${filename##*/}"
        if [[ "$basename" != *.* || "$basename" == .* || "$basename" == *. ]]; then
            filename="${filename%.}.png"
        fi
    fi

    if wl-paste > "$filename"; then
        printf 'Saved clipboard image to %s\n' "$filename"
    else
        return 1
    fi
}
