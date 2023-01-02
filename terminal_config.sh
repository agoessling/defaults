#!/bin/bash

get_param() {
  gsettings get org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:"$1"/ "$2" | tr -d "'"
}

set_param() {
  gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:"$1"/ "$2" "$3"
}

default_profile_uuid() {
  gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'"
}

get_profile_name() {
  get_param "$1" "visible-name"
}

default_profile_name() {
  local uuid=$(default_profile_uuid)
  get_profile_name ${uuid}
}

get_profile_uuid() {
  local profiles=$(gsettings get org.gnome.Terminal.ProfilesList list | tr "',[]" " ")
  for profile in ${profiles[@]}; do
    if [ "$(get_profile_name "$profile")" = "$1" ]; then
      echo $profile
    fi
  done
}

set_default_profile() {
  gsettings set org.gnome.Terminal.ProfilesList default "$1"
}

set_font() {
  set_param "$1" "font" "'$2'"
  set_param "$1" "use-system-font" false
}

setup_gruvbox_colors() {
  uuid=$(default_profile_uuid)
  set_param "$uuid" use-theme-colors "false"
  set_param "$uuid" use-theme-transparency "false"
  set_param "$uuid" background-color "#32302f"
  set_param "$uuid" foreground-color "#ddc7a1"
  set_param "$uuid" cursor-colors-set "true"
  set_param "$uuid" cursor-background-color "#ddc7a1"
  set_param "$uuid" cursor-foreground-color "#32302f"
  set_param "$uuid" "palette" "[\
'#282828', \
'#cc241d', \
'#98971a', \
'#d79921', \
'#458588', \
'#b16286', \
'#689d6a', \
'#a89984', \
'#928374', \
'#fb4934', \
'#b8bb26', \
'#fabd2f', \
'#83a598', \
'#d3869b', \
'#8ec07c', \
'#ebdbb2']"
}
