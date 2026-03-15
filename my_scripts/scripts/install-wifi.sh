#!/bin/sh

sudo pacman -S --noconfirm iwd impala
sudo systemctl enable --now iwd
sudo systemctl restart NetworkManager

