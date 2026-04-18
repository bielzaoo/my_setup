#!/bin/bash

# =============================================================================
#
#   ██████╗ ██╗███████╗██╗     ███████╗ █████╗  ██████╗
#   ██╔══██╗██║██╔════╝██║     ╚════██║██╔══██╗██╔═══██╗
#   ██████╔╝██║█████╗  ██║         ██╔╝███████║██║   ██║
#   ██╔══██╗██║██╔══╝  ██║        ██╔╝ ██╔══██║██║   ██║
#   ██████╔╝██║███████╗███████╗   ██║  ██║  ██║╚██████╔╝
#   ╚═════╝ ╚═╝╚══════╝╚══════╝   ╚═╝  ╚═╝  ╚═╝ ╚═════╝
#
#                   [ setup script by bielzao ]
#              github.com/bielzaoo | arch / cachy os
#
# =============================================================================

set -e

# ─── Cores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ─── Helpers ─────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $*"; exit 1; }

# ─── Flag de distro ──────────────────────────────────────────────────────────
DISTRO=""

usage() {
    echo -e "Uso: ${BOLD}./setup.sh${RESET} ${CYAN}--arch${RESET} | ${CYAN}--cachy${RESET}"
    echo ""
    echo "  --arch    Arch Linux (instalação minimal via archinstall)"
    echo "  --cachy   CachyOS com Hyprland já instalado"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)  DISTRO="arch";  shift ;;
        --cachy) DISTRO="cachy"; shift ;;
        *) usage ;;
    esac
done

[[ -z "$DISTRO" ]] && usage

# ─── Verifica que NÃO está rodando como root ──────────────────────────────────
if [[ "$EUID" -eq 0 ]]; then
    error "Não rode este script como root. Execute como usuário normal."
fi

# ─── Diretório base (onde o repositório está) ─────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Distro: ${YELLOW}${DISTRO^^}${RESET}"
echo -e "${BOLD}  Usuário: ${YELLOW}$(whoami)${RESET}"
echo -e "${BOLD}  Diretório base: ${YELLOW}${REPO_DIR}${RESET}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}"
echo ""

# ─── Função genérica de instalação com retry ─────────────────────────────────
pacman_install() {
    local pkgs=("$@")
    info "Instalando via pacman: ${pkgs[*]}"
    if ! sudo pacman -S --noconfirm --needed "${pkgs[@]}"; then
        warn "Falha ao instalar: ${pkgs[*]}. Tentando novamente..."
        sudo pacman -Sy && sudo pacman -S --noconfirm --needed "${pkgs[@]}" \
            || error "Não foi possível instalar: ${pkgs[*]}"
    fi
    success "Instalado: ${pkgs[*]}"
}

yay_install() {
    local pkgs=("$@")
    info "Instalando via yay: ${pkgs[*]}"
    if ! yay -S --noconfirm --needed "${pkgs[@]}"; then
        warn "Falha ao instalar via yay: ${pkgs[*]}. Tentando novamente..."
        yay -Sy && yay -S --noconfirm --needed "${pkgs[@]}" \
            || error "Não foi possível instalar via yay: ${pkgs[*]}"
    fi
    success "Instalado: ${pkgs[*]}"
}

# =============================================================================
# ETAPA 1 — Atualizar sistema
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 1 ] Atualizando o sistema...${RESET}\n"
sudo pacman -Syu --noconfirm
success "Sistema atualizado."

# =============================================================================
# ETAPA 2 — Instalar yay (AUR helper)
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 2 ] Verificando/instalando yay...${RESET}\n"
if ! command -v yay &>/dev/null; then
    info "yay não encontrado. Instalando dependências de build..."
    sudo pacman -S --noconfirm --needed git base-devel

    TMP_YAY=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$TMP_YAY/yay" \
        || error "Falha ao clonar o repositório do yay."
    cd "$TMP_YAY/yay"
    makepkg -si --noconfirm || error "Falha ao compilar/instalar o yay."
    cd "$REPO_DIR"
    rm -rf "$TMP_YAY"
    success "yay instalado com sucesso."
else
    success "yay já está instalado."
fi

# =============================================================================
# ETAPA 3 — Pacotes base do pacman (comuns a ambas as distros)
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 3 ] Instalando pacotes base via pacman...${RESET}\n"

BASE_PACMAN_PKGS=(
    # Hyprland ecosystem
    hypridle
    hyprlock
    hyprpaper

    # Shell & terminal
    zsh
    kitty
    tmux

    # Editor
    neovim

    # Dev tools
    gcc
    git
    wget
    stow
    nodejs
    npm

    # CLI utilities
    zoxide
    eza
    fd
    ripgrep
    fzf
    btop

    # Wayland / screenshot
    grim
    slurp
    wl-clipboard
    cliphist
    xdg-desktop-portal
    xdg-desktop-portal-hyprland

    # Notificação
    mako

    # Rofi launcher
    rofi

    # Waybar
    waybar

    # Fontes
    ttf-jetbrains-mono-nerd
    ttf-dejavu
    noto-fonts
    noto-fonts-emoji
    ttf-liberation

    # Qt theming
    kvantum
    qt5ct
    qt6ct

    # Multimídia / codecs
    gst-libav
    gst-plugins-bad
    gst-plugins-good
    gst-plugins-ugly
    ffmpeg
    gstreamer

    # Arquivadores
    zip
    unzip
    p7zip
    unrar
    tar
    gzip

    # Extras (do script base)
    gnome-keyring
    nautilus
    ufw
    flatpak
    feh
    galculator
    gnome-disk-utility
    iwd
    nwg-look
)

# Pacotes exclusivos do Arch (hyprland não vem pré-instalado)
ARCH_ONLY_PACMAN_PKGS=(
    hyprland
)

if [[ "$DISTRO" == "arch" ]]; then
    pacman_install "${BASE_PACMAN_PKGS[@]}" "${ARCH_ONLY_PACMAN_PKGS[@]}"
else
    pacman_install "${BASE_PACMAN_PKGS[@]}"
fi

# =============================================================================
# ETAPA 4 — Pacotes via AUR (yay)
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 4 ] Instalando pacotes via AUR (yay)...${RESET}\n"

# bitwarden-cli → AUR em ambas as distros
yay_install bitwarden-cli

# lazygit → AUR
yay_install lazygit

# wiremix → AUR (plugin pavucontrol-like para waybar / pipewire)
yay_install wiremix

# impala → AUR (gerenciador WiFi TUI)
yay_install impala

# kvantum-qt5 → pode já estar no pacman, mas garantimos via yay se faltar
yay_install kvantum-qt5 || true

# Brave Browser: no Arch vem do AUR; no Cachy do repo oficial
if [[ "$DISTRO" == "arch" ]]; then
    yay_install brave-bin
else
    info "Instalando Brave Browser via repositório oficial do CachyOS..."
    pacman_install brave-bin
fi

# Tema Yaru Dark (GTK + ícones) → AUR
yay_install yaru-gtk-theme yaru-icon-theme

success "Todos os pacotes AUR instalados."

# =============================================================================
# ETAPA 5 — Aplicar tema Yaru Dark
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 5 ] Aplicando tema Yaru Dark...${RESET}\n"

if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme  "Yaru-dark"      || warn "Falha ao setar gtk-theme"
    gsettings set org.gnome.desktop.interface icon-theme "Yaru"           || warn "Falha ao setar icon-theme"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"  || warn "Falha ao setar color-scheme"
    success "Tema Yaru Dark aplicado via gsettings."
else
    warn "gsettings não encontrado — configure o tema manualmente via nwg-look."
fi

# Aplica também via GTK2 settings
GTK2_FILE="$HOME/.gtkrc-2.0"
cat > "$GTK2_FILE" <<EOF
gtk-theme-name="Yaru-dark"
gtk-icon-theme-name="Yaru"
gtk-font-name="Noto Sans 10"
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintfull"
EOF
success "~/.gtkrc-2.0 configurado."

# GTK3 settings
GTK3_DIR="$HOME/.config/gtk-3.0"
mkdir -p "$GTK3_DIR"
cat > "$GTK3_DIR/settings.ini" <<EOF
[Settings]
gtk-theme-name=Yaru-dark
gtk-icon-theme-name=Yaru
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=1
EOF
success "~/.config/gtk-3.0/settings.ini configurado."

# =============================================================================
# ETAPA 6 — ZSH + Oh My Zsh + Starship + Catppuccin Mocha
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 6 ] Configurando ZSH, Oh My Zsh e Starship...${RESET}\n"

# ─── ZSH como shell padrão ───────────────────────────────────────────────────
if command -v zsh &>/dev/null; then
    if [[ "$SHELL" != "$(which zsh)" ]]; then
        chsh -s "$(which zsh)" || warn "Não foi possível mudar o shell padrão. Rode: chsh -s $(which zsh)"
        success "Shell padrão alterado para ZSH."
    else
        success "ZSH já é o shell padrão."
    fi
fi

ZSHRC="$HOME/.zshrc"

# ─── Oh My Zsh ───────────────────────────────────────────────────────────────
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Instalando Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        || error "Falha ao instalar Oh My Zsh."
    success "Oh My Zsh instalado."
else
    success "Oh My Zsh já está instalado."
fi

# ─── Plugins: zsh-autosuggestions e zsh-syntax-highlighting ─────────────────
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    info "Clonando zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
        || warn "Falha ao clonar zsh-autosuggestions."
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    info "Clonando zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
        || warn "Falha ao clonar zsh-syntax-highlighting."
fi

success "Plugins do Oh My Zsh prontos."

# ─── Starship ────────────────────────────────────────────────────────────────
if ! command -v starship &>/dev/null; then
    info "Instalando Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes \
        || error "Falha ao instalar Starship."
    success "Starship instalado."
else
    success "Starship já está instalado."
fi

# ─── Catppuccin Mocha para Starship ──────────────────────────────────────────
STARSHIP_CFG_DIR="$HOME/.config"
mkdir -p "$STARSHIP_CFG_DIR"

info "Baixando preset Catppuccin Mocha para Starship..."
starship preset catppuccin-powerline -o "$STARSHIP_CFG_DIR/starship.toml" 2>/dev/null || {
    # Fallback: baixa direto do repositório oficial do catppuccin/starship
    curl -fsSL \
        "https://raw.githubusercontent.com/catppuccin/starship/main/themes/mocha.toml" \
        -o "$STARSHIP_CFG_DIR/starship.toml" \
        || warn "Falha ao baixar tema Catppuccin Mocha. Configure manualmente em ~/.config/starship.toml"
}
success "Catppuccin Mocha aplicado ao Starship (~/.config/starship.toml)."

# ─── Configurar .zshrc ───────────────────────────────────────────────────────
info "Configurando .zshrc para Oh My Zsh + Starship..."

# Garante que o tema do OMZ está como 'robbyrussell' (starship substitui o prompt)
if [[ -f "$ZSHRC" ]]; then
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' "$ZSHRC"
fi

# Garante que os plugins estão setados
if grep -q '^plugins=' "$ZSHRC" 2>/dev/null; then
    sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$ZSHRC"
else
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> "$ZSHRC"
fi

# Adiciona eval do Starship ao final (apenas uma vez)
if ! grep -q 'starship init zsh' "$ZSHRC" 2>/dev/null; then
    {
        echo ""
        echo "# >>> Starship prompt <<<"
        echo 'eval "$(starship init zsh)"'
        echo "# <<< Starship prompt <<<"
    } >> "$ZSHRC"
    success "Starship inicializado no .zshrc."
else
    success "Starship já configurado no .zshrc."
fi

# ─── shell_confs.txt ─────────────────────────────────────────────────────────
SHELL_CONFS="$REPO_DIR/shell_confs.txt"

if [[ -f "$SHELL_CONFS" ]]; then
    info "Adicionando configurações de $SHELL_CONFS ao $ZSHRC..."
    touch "$ZSHRC"
    if ! grep -q "# >>> bielzao shell_confs <<<" "$ZSHRC"; then
        {
            echo ""
            echo "# >>> bielzao shell_confs <<<"
            cat "$SHELL_CONFS"
            echo "# <<< bielzao shell_confs <<<"
        } >> "$ZSHRC"
        success "shell_confs.txt adicionado ao .zshrc."
    else
        warn "shell_confs já presente no .zshrc, pulando."
    fi
else
    warn "shell_confs.txt não encontrado em $REPO_DIR."
fi

# =============================================================================
# ETAPA 7 — Copiar scripts para ~/.local/bin/
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 7 ] Copiando scripts para ~/.local/bin/...${RESET}\n"

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

SCRIPTS_DIR="$REPO_DIR/scripts"
if [[ -d "$SCRIPTS_DIR" ]]; then
    cp -v "$SCRIPTS_DIR"/* "$LOCAL_BIN/" || error "Falha ao copiar scripts."
    chmod +x "$LOCAL_BIN"/*
    success "Scripts copiados para $LOCAL_BIN."
else
    warn "Diretório $SCRIPTS_DIR não encontrado."
fi

# ─── ratopass ────────────────────────────────────────────────────────────────
RATOPASS_SRC="$REPO_DIR/ratopass/ratopass.sh"
if [[ -f "$RATOPASS_SRC" ]]; then
    cp -v "$RATOPASS_SRC" "$LOCAL_BIN/ratopass" || error "Falha ao copiar ratopass."
    chmod +x "$LOCAL_BIN/ratopass"
    success "ratopass copiado para $LOCAL_BIN/ratopass."
else
    warn "ratopass.sh não encontrado em $REPO_DIR/ratopass/."
fi

# Garante que ~/.local/bin está no PATH do .zshrc
if ! grep -q 'LOCAL_BIN\|\.local/bin' "$ZSHRC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
    success "~/.local/bin adicionado ao PATH no .zshrc."
fi

# =============================================================================
# ETAPA 8 — Copiar wallpapers para ~/Imagens/
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 8 ] Copiando wallpapers...${RESET}\n"

WALLPAPERS_DST="$HOME/Imagens"
mkdir -p "$WALLPAPERS_DST"

WALLPAPERS_SRC="$REPO_DIR/wallpapers"
if [[ -d "$WALLPAPERS_SRC" ]]; then
    cp -rv "$WALLPAPERS_SRC"/* "$WALLPAPERS_DST/" || error "Falha ao copiar wallpapers."
    success "Wallpapers copiados para $WALLPAPERS_DST."
else
    warn "Diretório wallpapers não encontrado em $REPO_DIR."
fi

# =============================================================================
# ETAPA 9 — Clonar dotfiles e aplicar com stow
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 9 ] Clonando e aplicando dotfiles...${RESET}\n"

DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_REPO="https://github.com/bielzaoo/dotfiles"

if [[ -d "$DOTFILES_DIR" ]]; then
    warn "Diretório $DOTFILES_DIR já existe. Atualizando via git pull..."
    git -C "$DOTFILES_DIR" pull || warn "Falha ao atualizar dotfiles. Verifique manualmente."
else
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || error "Falha ao clonar dotfiles."
    success "Dotfiles clonados em $DOTFILES_DIR."
fi

info "Aplicando dotfiles com stow..."
cd "$DOTFILES_DIR"

# Aplica stow em todos os subdiretórios (exclui arquivos soltos na raiz)
STOW_TARGETS=()
for d in */; do
    [[ -d "$d" ]] && STOW_TARGETS+=("${d%/}")
done

if [[ ${#STOW_TARGETS[@]} -gt 0 ]]; then
    stow --target="$HOME" --restow "${STOW_TARGETS[@]}" \
        || error "Falha ao aplicar stow. Verifique conflitos de arquivos."
    success "Dotfiles linkados com sucesso via stow."
else
    # Fallback: tenta stow . na raiz
    stow --target="$HOME" --restow . \
        || error "Falha ao aplicar stow."
    success "Dotfiles linkados com sucesso (stow .)."
fi

cd "$REPO_DIR"

# =============================================================================
# ETAPA 10 — QEMU / Virtualização
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 10 ] Instalando QEMU e ferramentas de virtualização...${RESET}\n"

pacman_install qemu-full virt-manager virt-viewer libvirt dnsmasq edk2-ovmf

info "Habilitando serviço libvirtd..."
sudo systemctl enable --now libvirtd || error "Falha ao habilitar libvirtd."
success "libvirtd habilitado."

info "Adicionando usuário '$(whoami)' aos grupos libvirt e kvm..."
sudo usermod -aG libvirt,kvm "$USER" || error "Falha ao adicionar usuário aos grupos libvirt/kvm."
success "Usuário adicionado aos grupos libvirt e kvm."

# =============================================================================
# ETAPA 11 — Docker
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 11 ] Instalando Docker...${RESET}\n"

pacman_install docker docker-compose

info "Habilitando serviço Docker..."
sudo systemctl enable --now docker || error "Falha ao habilitar docker."
success "Docker habilitado."

info "Adicionando usuário '$(whoami)' ao grupo docker..."
sudo usermod -aG docker "$USER" || error "Falha ao adicionar usuário ao grupo docker."
success "Usuário adicionado ao grupo docker."

# =============================================================================
# ETAPA 12 — Habilitar serviços gerais
# =============================================================================
echo -e "\n${BOLD}${CYAN}[ ETAPA 12 ] Habilitando serviços gerais...${RESET}\n"

# iwd (gerenciador de rede)
sudo systemctl enable --now iwd || warn "Falha ao habilitar iwd."
success "iwd habilitado."

# ufw (firewall)
sudo systemctl enable --now ufw || warn "Falha ao habilitar ufw."
sudo ufw --force enable         || warn "Falha ao ativar ufw."
success "ufw habilitado e ativo."

# =============================================================================
# FINALIZADO
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║         Setup concluído com sucesso, bielzao!        ║${RESET}"
echo -e "${GREEN}${BOLD}║                                                      ║${RESET}"
echo -e "${GREEN}${BOLD}║  ⚠  Reinicie a sessão (ou o sistema) para aplicar   ║${RESET}"
echo -e "${GREEN}${BOLD}║     todas as mudanças de shell, tema e grupos        ║${RESET}"
echo -e "${GREEN}${BOLD}║     (docker, libvirt, kvm).                          ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
