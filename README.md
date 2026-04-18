<div align="center">

```
██████╗ ██╗███████╗██╗     ███████╗ █████╗  ██████╗ 
██╔══██╗██║██╔════╝██║     ╚══███╔╝██╔══██╗██╔═══██╗
██████╔╝██║█████╗  ██║       ███╔╝ ███████║██║   ██║
██╔══██╗██║██╔══╝  ██║      ███╔╝  ██╔══██║██║   ██║
██████╔╝██║███████╗███████╗███████╗██║  ██║╚██████╔╝
╚═════╝ ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝
  ```

**setup script by bielzao**

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![CachyOS](https://img.shields.io/badge/CachyOS-00BFFF?style=for-the-badge&logo=linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=for-the-badge&logo=wayland&logoColor=black)
![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)

*Script de setup automatizado para Arch Linux e CachyOS com Hyprland.*

</div>

---

## Estrutura do repositório

```
.
├── setup.sh              ← você está aqui
├── ratopass/
│   └── ratopass.sh       ← gerenciador de senhas (Bitwarden CLI)
├── scripts/              ← utilitários para waybar e sistema
│   ├── brightness-down
│   ├── brightness-notify
│   ├── brightness-up
│   ├── discord-wayland
│   ├── toggle_layout.sh
│   ├── volume-down
│   ├── volume-mute
│   ├── volume-notify
│   └── volume-up
├── shell_confs.txt        ← aliases, funções e exports para o .zshrc
└── wallpapers/            ← copiados para ~/Imagens/
    ├── batman.jpg
    ├── ela_v1.png
    ├── ela_v2.png
    ├── us.png
    ├── us_v2.png
    └── us_v3.png
```

---

## Pré-requisitos

- Arch Linux com instalação minimal via `archinstall` **ou** CachyOS com Hyprland
- Conexão com a internet
- Usuário **comum** (não rode como root)
- `sudo` configurado para o seu usuário

---

## Como usar

Clone o repositório e execute o script passando a flag da sua distro:

```bash
git clone https://github.com/bielzaoo/my_setup ~/my_setup
cd ~/my_setup
chmod +x setup.sh
```

**Arch Linux:**
```bash
./setup.sh --arch
```

**CachyOS:**
```bash
./setup.sh --cachy
```

> Ao final, **reinicie a sessão ou o sistema** para aplicar as mudanças de shell, tema e grupos (`docker`, `libvirt`, `kvm`).

---

## O que o script faz

| Etapa | Descrição |
|-------|-----------|
| 1 | Atualiza o sistema (`pacman -Syu`) |
| 2 | Instala o `yay` (AUR helper) caso não esteja presente |
| 3 | Instala pacotes base via `pacman` |
| 4 | Instala pacotes do AUR via `yay` |
| 5 | Aplica o tema **Yaru Dark** (GTK2, GTK3 e gsettings) |
| 6 | Configura **ZSH** + **Oh My Zsh** + **Starship** com tema Catppuccin Mocha |
| 7 | Copia scripts para `~/.local/bin/` e instala o `ratopass` |
| 8 | Copia wallpapers para `~/Imagens/` |
| 9 | Clona o repositório de dotfiles e aplica com `stow` |
| 10 | Instala **QEMU** e ferramentas de virtualização |
| 11 | Instala **Docker** e `docker-compose` |
| 12 | Habilita serviços: `iwd`, `ufw` |

---

## Pacotes instalados

### Via pacman

| Categoria | Pacotes |
|-----------|---------|
| Hyprland | `hyprland`*, `hypridle`, `hyprlock`, `hyprpaper` |
| Shell & terminal | `zsh`, `kitty`, `tmux` |
| Editor | `neovim` |
| Dev | `gcc`, `git`, `wget`, `stow`, `nodejs`, `npm` |
| CLI utilities | `zoxide`, `eza`, `fd`, `ripgrep`, `fzf`, `btop` |
| Wayland | `grim`, `slurp`, `wl-clipboard`, `cliphist`, `xdg-desktop-portal`, `xdg-desktop-portal-hyprland` |
| Notificações | `mako` |
| Launcher | `rofi` |
| Bar | `waybar` |
| Fontes | `ttf-jetbrains-mono-nerd`, `ttf-dejavu`, `noto-fonts`, `noto-fonts-emoji`, `ttf-liberation` |
| Qt theming | `kvantum`, `qt5ct`, `qt6ct` |
| Codecs | `gst-libav`, `gst-plugins-*`, `ffmpeg`, `gstreamer` |
| Arquivadores | `zip`, `unzip`, `p7zip`, `unrar`, `tar`, `gzip` |
| Extras | `gnome-keyring`, `nautilus`, `ufw`, `flatpak`, `feh`, `galculator`, `gnome-disk-utility`, `iwd`, `nwg-look` |
| Virtualização | `qemu-full`, `virt-manager`, `virt-viewer`, `libvirt`, `dnsmasq`, `edk2-ovmf` |
| Containers | `docker`, `docker-compose` |

> *`hyprland` só é instalado no modo `--arch`. No CachyOS já vem pré-instalado.

### Via AUR (yay)

| Pacote | Descrição |
|--------|-----------|
| `brave-bin` | Brave Browser |
| `bitwarden-cli` | CLI do Bitwarden |
| `lazygit` | TUI para Git |
| `wiremix` | Mixer de áudio para Waybar / Pipewire |
| `impala` | Gerenciador de Wi-Fi TUI |
| `yaru-gtk-theme` | Tema GTK Yaru Dark |
| `yaru-icon-theme` | Ícones Yaru |

> No **CachyOS**, o `brave-bin` é instalado via repositório oficial da distro (pacman).

---

## Shell

O script configura o ambiente de shell completo:

- **Oh My Zsh** com plugins `git`, `zsh-autosuggestions` e `zsh-syntax-highlighting`
- **Starship** como prompt, com tema **Catppuccin Mocha** em `~/.config/starship.toml`
- Aliases, funções e exports do `shell_confs.txt` injetados no `.zshrc`
- `~/.local/bin` adicionado ao `PATH`

---

## Dotfiles

Os dotfiles são clonados de [github.com/bielzaoo/dotfiles](https://github.com/bielzaoo/dotfiles) em `~/dotfiles` e linkados via `stow`:

```bash
stow --target="$HOME" --restow <subdiretórios>
```

Se o repositório já existir localmente, o script faz `git pull` para atualizar.

---

## ratopass

Gerenciador de senhas pessoal baseado no Bitwarden CLI. Instalado em `~/.local/bin/ratopass`.

```bash
ratopass
```

---

<div align="center">

feito com 🤍 por **bielzao** — [github.com/bielzaoo](https://github.com/bielzaoo)

</div>
