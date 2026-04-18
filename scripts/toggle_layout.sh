##!/bin/bash

STATE_FILE="$HOME/.cache/hypr_orientation"

[ ! -f "$STATE_FILE" ] && echo "vertical" >"$STATE_FILE"

state=$(cat "$STATE_FILE")

# sempre força master
hyprctl keyword general:layout master

if [ "$state" = "vertical" ]; then
  hyprctl dispatch layoutmsg orientationtop
  echo "horizontal" >"$STATE_FILE"
else
  hyprctl dispatch layoutmsg orientationleft
  echo "vertical" >"$STATE_FILE"
fi
