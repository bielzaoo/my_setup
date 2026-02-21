Servidor de áudio: 
- pipewire

Kernels: 
- habilitar LTS
Particionamento: 
- padrão para melhor desempenho
Rede: 
- usar Network Manager
Repositórios adicionariamos:
- multlib

---

Atualize o sistema: 
`sudo pacman -Syu`

Instale as fonts
`sudo pacman -S ttf-jetbrains-mono ttf-dejavu oto-fonts noto-fonts-emoji ttf-liberation` 

Instale CODECs
`sudo pacman -S gst-libav gst-plugins-bad gs-plugins-good gst-plugins-ugly ffmpeg gstreamer` 


Instale o Hyprland e o kitty
`sudo pacman -S hyprland kitty`

Instale os portais
`sudo pacman -S xdg-desktop-portal xdg-desktop-portal-hyprland` 

Agora Inicie o Hyprland:
`Hyprland`

Editar o arquivo /etc/pacman.conf
```plaintext
Descomente a linha Color
Configure ParallelDownloads = 15
E Logo após adicione a linha
 ILoveCandy
```

Instale a s ferramentas de compactação
`sudo pacman -S zip unzip p7zip unrar tar gzip` 

Instale o dolphin, flatpack e o firefox
`sudo pacman -S --needed dolphin firefox flatpak` 

Instale o micro code do processador (Wiki Arch Linux)

Instale o wofi
`sudo pacman -S wofi` 

Instale a Waybar
`sudo pacman -S waybar`
Copie o arquivo de configuração da waybar

Instale o nwg-bar
`sudo pacman -S nwg-bar` 

Instale o hyprpaper
`sudo pacma -S hyprpaper` 

Instale os pacotes essenciais
`sudo pacman -S cliphist wl-clipboard dnust network-manager-applet polkit-kde-agent`

Instale o hyprlock
`sudo pacman -S hyprlock`

Para captura de tela:
`sudo pacman -S grim slurp`

Instale o UFW:
```plaintext
sudo pacman -S ufw
sudo systemctl enable --now ufw.service
suod ufw enable

```

Instale yay:
```plaintext
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
yay -Y --gendb

```

Para instalar tema de aplicativos:
`sudo pacman -S kvantum kvantum-qt5 qt5ct qt6ct nwg-llok arc-gtk-theme`

Para resolver o bug das coresdo Dolphin:
1. Edite o arquivo .config/dolphinrc
2. Adicione a secao:
```plaintext
[UiSettings]
ColorScheme=<mesmo_tema_global>

```

Para verfiicar CPU:
`sudo pacman -S psensor`
`sudo pacman -S --needed lm_sensors`

OUTROS PROGRAMAS
```plaintext
sudo pacman -S ristretto
sudo pacmna -S galculator
sudo pacman -S pavucontrol
sudo pacman -S gnome-disk-utility
sudo pacman -S btop
sudo pacman -S print-manager

```
