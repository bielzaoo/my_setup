#!/bin/bash

#!/bin/bash

STATE_FILE="/tmp/hypr_orientation"

if [ ! -f "$STATE_FILE" ]; then
  echo "vertical" >"$STATE_FILE"
fi

state=$(cat "$STATE_FILE")

if [ "$state" = "vertical" ]; then
  hyprctl dispatch layoutmsg orientationtop
  echo "horizontal" >"$STATE_FILE"
else
  hyprctl dispatch layoutmsg orientationleft
  echo "vertical" >"$STATE_FILE"
fi
