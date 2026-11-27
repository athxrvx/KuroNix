#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
selected=()
while IFS= read -r path; do
  [[ -n "$path" ]] && selected+=("$path")
done <<< "${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-}"

current_dir="${HOME}"
current_uri="${NAUTILUS_SCRIPT_CURRENT_URI:-}"
if [[ -n "$current_uri" ]]; then
  decoded="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(urllib.parse.urlparse(sys.argv[1]).path))' "$current_uri")"
  [[ -d "$decoded" ]] && current_dir="$decoded"
fi

fail() {
  zenity --error --title="Kuro file action" --text="$1" 2>/dev/null || true
  exit 1
}

need_selection() {
  ((${#selected[@]} > 0)) || fail "Select at least one file first."
}

is_image_file() {
  case "${1,,}" in
    *.jpg|*.jpeg|*.png|*.webp|*.tif|*.tiff|*.svg) return 0 ;;
    *) return 1 ;;
  esac
}

is_wallpaper_file() {
  case "${1,,}" in
    *.jpg|*.jpeg|*.png|*.webp|*.tif|*.tiff|*.svg|*.mp4|*.mkv|*.webm|*.mov|*.avi|*.m4v) return 0 ;;
    *) return 1 ;;
  esac
}

validate_selection() {
  local file predicate="$1" message="$2"
  need_selection
  for file in "${selected[@]}"; do
    [[ -f "$file" ]] || continue
    "$predicate" "$file" || fail "$message: $(basename -- "$file")"
  done
}

output_for() {
  local file="$1" suffix="$2" extension="${3:-}" name stem directory output index
  name="$(basename -- "$file")"
  directory="$(dirname -- "$file")"
  if [[ "$name" == *.* ]]; then
    stem="${name%.*}"
    [[ -n "$extension" ]] || extension="${name##*.}"
  else
    stem="$name"
    [[ -n "$extension" ]] || extension="png"
  fi
  output="$directory/$stem-$suffix.$extension"
  index=2
  while [[ -e "$output" ]]; do
    output="$directory/$stem-$suffix-$index.$extension"
    ((index += 1))
  done
  printf '%s\n' "$output"
}

wallpaper_directory() {
  local configured=""
  if [[ -f "$HOME/.cache/kuro/theme.json" ]]; then
    configured="$(jq -r '.apps.wallpaperDir // empty' "$HOME/.cache/kuro/theme.json")"
  fi
  configured="${configured:-$HOME/Pictures/Wallpaper}"
  case "$configured" in
    '~') configured="$HOME" ;;
    '~/'*) configured="$HOME/${configured#\~/}" ;;
    /*) ;;
    *) configured="$HOME/$configured" ;;
  esac
  printf '%s\n' "$configured"
}

git_root_for() {
  local path="$1"
  [[ -d "$path" ]] || path="$(dirname -- "$path")"
  git -C "$path" rev-parse --show-toplevel 2>/dev/null
}

selected_or_current_dir() {
  if ((${#selected[@]} == 1)) && [[ -d "${selected[0]}" ]]; then
    printf '%s\n' "${selected[0]}"
  elif ((${#selected[@]} > 0)); then
    dirname -- "${selected[0]}"
  else
    printf '%s\n' "$current_dir"
  fi
}

image_operation() {
  validate_selection is_image_file "Select image files"
  local file output geometry format extension details="" operation="${action#image-}"
  case "$action" in
    image-rotate-left|image-rotate-right|image-flip-horizontal|image-flip-vertical|image-strip-metadata)
      for file in "${selected[@]}"; do
        [[ -f "$file" ]] || continue
        case "$operation" in
          rotate-left) output="$(output_for "$file" rotated-left)"; magick "$file" -auto-orient -rotate -90 "$output" ;;
          rotate-right) output="$(output_for "$file" rotated-right)"; magick "$file" -auto-orient -rotate 90 "$output" ;;
          flip-horizontal) output="$(output_for "$file" flipped-horizontal)"; magick "$file" -auto-orient -flop "$output" ;;
          flip-vertical) output="$(output_for "$file" flipped-vertical)"; magick "$file" -auto-orient -flip "$output" ;;
          strip-metadata) output="$(output_for "$file" metadata-free)"; magick "$file" -auto-orient -strip "$output" ;;
        esac
      done
      ;;
    image-resize)
      geometry="$(zenity --entry --title="Resize images" --text="Enter a percentage (50%) or maximum dimensions (1600x1200):" --entry-text="50%")" || exit 0
      [[ "$geometry" =~ ^[0-9]+([.][0-9]+)?%$ || "$geometry" =~ ^[0-9]+x[0-9]+$ ]] || fail "Use a percentage such as 50% or dimensions such as 1600x1200."
      for file in "${selected[@]}"; do
        [[ -f "$file" ]] || continue
        magick "$file" -auto-orient -resize "$geometry" "$(output_for "$file" resized)"
      done
      ;;
    image-convert)
      format="$(zenity --list --radiolist --title="Convert images" --text="Choose an output format:" --column="Select" --column="Format" TRUE PNG FALSE JPEG FALSE WebP --width=400 --height=280)" || exit 0
      case "$format" in PNG) extension=png ;; JPEG) extension=jpg ;; WebP) extension=webp ;; *) exit 0 ;; esac
      for file in "${selected[@]}"; do
        [[ -f "$file" ]] || continue
        output="$(output_for "$file" converted "$extension")"
        case "$format" in
          JPEG) magick "$file" -auto-orient -background white -alpha remove -alpha off -quality 88 "$output" ;;
          WebP) magick "$file" -auto-orient -quality 88 "$output" ;;
          PNG) magick "$file" -auto-orient "$output" ;;
        esac
      done
      ;;
    image-details)
      for file in "${selected[@]}"; do
        [[ -f "$file" ]] || continue
        details+="$(identify -format '%f  ·  %m  ·  %wx%h  ·  %b\n' "$file")"$'\n'
      done
      [[ -n "$details" ]] && zenity --info --title="Image details" --text="$details" --width=620 || true
      ;;
    *) fail "Unknown image action: $action" ;;
  esac
}

case "$action" in
  set-wallpaper)
    validate_selection is_wallpaper_file "Choose an image or video file"
    for path in "${selected[@]}"; do
      [[ -f "$path" ]] || continue
      qs -c shell ipc call wallpaper set "$path"
    done
    ;;
  add-wallpaper)
    validate_selection is_wallpaper_file "Choose an image or video file"
    destination="$(wallpaper_directory)"
    mkdir -p -- "$destination"
    for path in "${selected[@]}"; do
      [[ -f "$path" ]] || continue
      [[ "$(dirname -- "$path")" == "$destination" ]] && continue
      name="$(basename -- "$path")"
      target="$destination/$name"
      if [[ -e "$target" ]]; then
        if [[ "$name" == *.* ]]; then stem="${name%.*}"; extension=".${name##*.}"; else stem="$name"; extension=""; fi
        index=2
        target="$destination/$stem-$index$extension"
        while [[ -e "$target" ]]; do ((index += 1)); target="$destination/$stem-$index$extension"; done
      fi
      mv -- "$path" "$target"
    done
    ;;
  copy-path)
    need_selection
    printf '%s\n' "${selected[@]}" | wl-copy
    ;;
  copy-name)
    need_selection
    for path in "${selected[@]}"; do basename -- "$path"; done | wl-copy
    ;;
  checksum)
    need_selection
    report="$(sha256sum -- "${selected[@]}")"
    zenity --text-info --title="SHA-256 checksums" --width=760 --height=420 --filename=<(printf '%s\n' "$report")
    ;;
  archive)
    need_selection
    directory="$(dirname -- "${selected[0]}")"
    names=()
    for path in "${selected[@]}"; do
      [[ "$(dirname -- "$path")" == "$directory" ]] || fail "Select files from the same folder to create one archive."
      names+=("./$(basename -- "$path")")
    done
    format="$(zenity --list --radiolist --title="Create archive" --text="Choose an archive format:" --column="Select" --column="Format" TRUE ZIP FALSE "TAR.GZ" FALSE "TAR.XZ" --width=400 --height=280)" || exit 0
    [[ -n "$format" ]] || exit 0
    archive_name="$(zenity --entry --title="Create archive" --text="Archive name (saved beside the selected files):" --entry-text="archive")" || exit 0
    [[ -n "$archive_name" && "$archive_name" != */* && "$archive_name" != .* ]] || fail "Enter a plain archive name without a path."
    case "$format" in ZIP) extension=zip ;; "TAR.GZ") extension=tar.gz ;; "TAR.XZ") extension=tar.xz ;; *) exit 0 ;; esac
    output="$directory/$archive_name.$extension"
    index=2
    while [[ -e "$output" ]]; do output="$directory/$archive_name-$index.$extension"; ((index += 1)); done
    case "$format" in
      ZIP) (cd -- "$directory" && zip -r "$output" -- "${names[@]}") ;;
      "TAR.GZ") tar -czf "$output" -C "$directory" -- "${names[@]}" ;;
      "TAR.XZ") tar -cJf "$output" -C "$directory" -- "${names[@]}" ;;
    esac
    ;;
  extract)
    need_selection
    for archive in "${selected[@]}"; do
      [[ -f "$archive" ]] || continue
      directory="$(dirname -- "$archive")"
      name="$(basename -- "$archive")"
      lower="${name,,}"
      case "$lower" in
        *.tar.gz) stem="${name:0:${#name}-7}" ;;
        *.tgz) stem="${name:0:${#name}-4}" ;;
        *.tar.xz) stem="${name:0:${#name}-7}" ;;
        *.tar) stem="${name:0:${#name}-4}" ;;
        *.zip) stem="${name:0:${#name}-4}" ;;
        *) fail "Unsupported archive: $name" ;;
      esac
      target="$directory/$stem"
      index=2
      while [[ -e "$target" ]]; do target="$directory/$stem-$index"; ((index += 1)); done
      mkdir -p -- "$target"
      case "$lower" in
        *.zip) unzip -q "$archive" -d "$target" ;;
        *.tar.gz|*.tgz) tar -xzf "$archive" -C "$target" ;;
        *.tar.xz) tar -xJf "$archive" -C "$target" ;;
        *.tar) tar -xf "$archive" -C "$target" ;;
      esac
    done
    ;;
  kitty-here)
    directory="$(selected_or_current_dir)"
    exec kitty --directory "$directory"
    ;;
  nvim)
    need_selection
    exec kitty --directory "$(dirname -- "${selected[0]}")" -e nvim -- "${selected[@]}"
    ;;
  git-status|git-copy-root|git-terminal|git-nvim|git-init|git-clone)
    directory="$(selected_or_current_dir)"
    root="$(git_root_for "$directory")" || root=""
    case "$action" in
      git-status)
        [[ -n "$root" ]] || fail "This folder is not inside a Git repository."
        report="$(git -C "$root" status --short --branch; printf '\nRecent commits:\n'; git -C "$root" log -5 --oneline 2>/dev/null || true)"
        zenity --text-info --title="Git status · $(basename -- "$root")" --width=760 --height=480 --filename=<(printf '%s\n' "$report")
        ;;
      git-copy-root)
        [[ -n "$root" ]] || fail "This folder is not inside a Git repository."
        printf '%s\n' "$root" | wl-copy
        ;;
      git-terminal)
        [[ -n "$root" ]] || fail "This folder is not inside a Git repository."
        exec kitty --directory "$root"
        ;;
      git-nvim)
        [[ -n "$root" ]] || fail "This folder is not inside a Git repository."
        exec kitty --directory "$root" -e nvim .
        ;;
      git-init)
        if [[ -n "$root" ]]; then fail "This folder is already inside a Git repository."; fi
        if zenity --question --title="Initialize Git repository" --text="Create a Git repository in $directory?"; then
          git -C "$directory" init
        fi
        ;;
      git-clone)
        url="$(zenity --entry --title="Clone Git repository" --text="Repository URL:")" || exit 0
        [[ -n "$url" ]] || exit 0
        exec kitty --directory "$directory" -e git clone -- "$url"
        ;;
    esac
    ;;
  image-*) image_operation ;;
  *) fail "Unknown file action: $action" ;;
esac
