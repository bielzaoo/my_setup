#!/bin/sh

BASE_DIR=$(pwd)

echo "[+] Atualizando o sistema..."
sudo pacman -Syu --noconfirm

echo "[+] Instalando Intel Microcode"
sudo pacman -S --noconfirm intel-ucode

echo "[+] Instalando yay..."
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..

echo "[+] Configurando Wi-Fi..."
$BASE_DIR/scripts/install-wifi.sh

echo "[+] Configurando Som..."
$BASE_DIR/scripts/install-sound.sh

echo "[+] Instalando fonts..."
$BASE_DIR/scripts/install-fonts.sh

echo "[+] Instalando clipboard..."
$BASE_DIR/scripts/install-clipboard.sh

echo "[+] Instalando notificações..."
$BASE_DIR/scripts/install-notifications.sh

echo "[+] Instalando screenshots feature..."
$BASE_DIR/scripts/install-screenshot.sh

echo "[+] Instalando CODECs..."
$BASE_DIR/scripts/install-codecs.sh

echo "[+] Instalando Hyprland e seu ambiente..."
$BASE_DIR/scripts/install-hyprland_environment.sh

echo "[+] Instalando monitor de recursos..."
$BASE_DIR/scripts/install-cpu-monitor.sh

echo "[+] Instalando Waybar..."
$BASE_DIR/scripts/install-waybar.sh

echo "[+] Instalando Power Menu..."
$BASE_DIR/scripts/install-powermenu.sh

echo "[+] Instalando portais..."
$BASE_DIR/scripts/install-portals.sh

echo "[+] Instalando compress tools..."
$BASE_DIR/scripts/install-compress-tools.sh

echo "[+] Instalando Browser..."
$BASE_DIR/scripts/install-browser.sh

echo "[+] Instalando File Manager..."
$BASE_DIR/scripts/install-filemanager.sh

echo "[+] Instalando Launcher..."
$BASE_DIR/scripts/install-launcher.sh

echo "[+] Instalando Firewall..."
$BASE_DIR/scripts/install-firewall.sh

echo "[+] Para configurar temas..."
$BASE_DIR/scripts/install-forthemes.sh

echo "[+] Instalando outros utilitarios..."
$BASE_DIR/scripts/install-utilitarios.sh
