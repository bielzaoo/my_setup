#!/usr/bin/env bash
# =============================================================================
#  qemu-setup.sh — Instalação do QEMU + Configuração UFW no Arch Linux
# =============================================================================

set -euo pipefail

# ─── Cores ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Helpers ─────────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERRO]${NC}  $*" >&2; }
step()    { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${NC}"; \
            echo -e "${BOLD}${CYAN}  $*${NC}"; \
            echo -e "${BOLD}${CYAN}══════════════════════════════════════${NC}"; }

confirm() {
    local msg="$1"
    read -rp "$(echo -e "${YELLOW}[?]${NC} ${msg} [s/N]: ")" resp
    [[ "${resp,,}" == "s" ]]
}

# ─── Verificações iniciais ────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script precisa ser executado como root."
        echo -e "  Use: ${BOLD}sudo bash $0${NC}"
        exit 1
    fi
}

check_arch() {
    if ! command -v pacman &>/dev/null; then
        error "Este script é apenas para Arch Linux (pacman não encontrado)."
        exit 1
    fi
}

detect_interface() {
    # Pega a interface padrão de saída para internet
    PHY_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
    if [[ -z "$PHY_IFACE" ]]; then
        warn "Não foi possível detectar a interface de rede automaticamente."
        read -rp "$(echo -e "${YELLOW}[?]${NC} Digite o nome da sua interface física (ex: eth0, enp3s0, wlan0): ")" PHY_IFACE
        if [[ -z "$PHY_IFACE" ]]; then
            error "Interface não informada. Abortando."
            exit 1
        fi
    fi
    success "Interface física detectada: ${BOLD}${PHY_IFACE}${NC}"
}

# ─── Etapas ──────────────────────────────────────────────────────────────────

install_qemu() {
    step "1/6 — Instalando QEMU e dependências"

    local pkgs=(qemu-full virt-manager virt-viewer dnsmasq bridge-utils libvirt edk2-ovmf)

    info "Atualizando base de dados do pacman..."
    pacman -Sy --noconfirm

    info "Instalando pacotes: ${pkgs[*]}"
    pacman -S --noconfirm --needed "${pkgs[@]}"

    success "QEMU e dependências instalados."
}

configure_libvirt() {
    step "2/6 — Configurando libvirt"

    info "Habilitando e iniciando libvirtd..."
    systemctl enable --now libvirtd
    success "libvirtd ativo."

    # Adiciona o usuário sudoer (quem chamou o sudo) ao grupo libvirt
    local REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
    if [[ -n "$REAL_USER" && "$REAL_USER" != "root" ]]; then
        info "Adicionando usuário '${REAL_USER}' ao grupo libvirt..."
        usermod -aG libvirt "$REAL_USER"
        success "Usuário '${REAL_USER}' adicionado ao grupo libvirt."
        warn "Faça logout/login para que o grupo entre em vigor."
    else
        warn "Não foi possível detectar usuário não-root para adicionar ao grupo libvirt."
    fi
}

configure_sysctl() {
    step "3/6 — Habilitando IP Forwarding"

    local sysctl_file="/etc/sysctl.d/99-libvirt.conf"

    if [[ -f "$sysctl_file" ]] && grep -q "net.ipv4.ip_forward" "$sysctl_file"; then
        warn "IP forward já configurado em ${sysctl_file}. Pulando."
    else
        info "Criando ${sysctl_file}..."
        cat > "$sysctl_file" <<EOF
# Habilitado pelo qemu-setup.sh para permitir NAT das VMs
net.ipv4.ip_forward = 1
EOF
        success "Arquivo criado: ${sysctl_file}"
    fi

    info "Aplicando configurações de sysctl..."
    sysctl --system | grep "ip_forward" || true
    success "IP forwarding habilitado: $(sysctl -n net.ipv4.ip_forward)"
}

configure_ufw() {
    step "4/6 — Configurando UFW"

    # Instala ufw se não estiver presente
    if ! command -v ufw &>/dev/null; then
        info "UFW não encontrado. Instalando..."
        pacman -S --noconfirm --needed ufw
    fi

    # Habilitar UFW caso esteja inativo
    local ufw_status
    ufw_status=$(ufw status 2>/dev/null | head -1)
    if echo "$ufw_status" | grep -qi "inactive"; then
        warn "UFW está inativo. Habilitando..."
        ufw --force enable
    fi

    info "Liberando tráfego na interface virbr0..."
    ufw allow in  on virbr0
    ufw allow out on virbr0

    info "Configurando DEFAULT_FORWARD_POLICY=ACCEPT em /etc/default/ufw..."
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
    success "Forward policy configurada."

    # Regra NAT em before.rules
    local before_rules="/etc/ufw/before.rules"
    local nat_marker="# QEMU NAT — adicionado por qemu-setup.sh"

    if grep -q "$nat_marker" "$before_rules" 2>/dev/null; then
        warn "Regra NAT já existe em ${before_rules}. Pulando."
    else
        info "Adicionando regra MASQUERADE em ${before_rules}..."

        # Faz backup
        cp "$before_rules" "${before_rules}.bak.$(date +%Y%m%d%H%M%S)"
        info "Backup criado: ${before_rules}.bak.*"

        # Insere bloco *nat antes do *filter
        sed -i "/^\*filter/i \\
${nat_marker}\\
*nat\\
:POSTROUTING ACCEPT [0:0]\\
-A POSTROUTING -s 192.168.122.0\\/24 -o ${PHY_IFACE} -j MASQUERADE\\
COMMIT\\
" "$before_rules"

        success "Regra NAT adicionada para interface ${PHY_IFACE}."
    fi

    info "Reiniciando UFW para aplicar todas as regras..."
    ufw disable
    ufw --force enable
    success "UFW reconfigurado."
}

configure_libvirt_network() {
    step "5/6 — Ativando rede virtual padrão do libvirt"

    # Garante que virsh está disponível
    if ! command -v virsh &>/dev/null; then
        warn "virsh não encontrado. Pulando configuração da rede virtual."
        return
    fi

    local net_state
    net_state=$(virsh net-list --all 2>/dev/null | awk '/default/ {print $2}')

    if [[ "$net_state" == "active" ]]; then
        success "Rede 'default' já está ativa."
    else
        info "Iniciando rede virtual 'default'..."
        virsh net-start default 2>/dev/null || warn "Não foi possível iniciar a rede default agora (pode ser normal antes do reboot)."
    fi

    info "Configurando rede 'default' para iniciar automaticamente..."
    virsh net-autostart default 2>/dev/null || true
    success "Rede 'default' configurada para autostart."
}

show_summary() {
    step "6/6 — Resumo da instalação"

    echo -e ""
    echo -e "  ${GREEN}${BOLD}✔ QEMU/libvirt instalado${NC}"
    echo -e "  ${GREEN}${BOLD}✔ libvirtd habilitado${NC}"
    echo -e "  ${GREEN}${BOLD}✔ IP Forwarding ativado${NC}  (/etc/sysctl.d/99-libvirt.conf)"
    echo -e "  ${GREEN}${BOLD}✔ UFW configurado${NC}        (virbr0 liberada + NAT via ${PHY_IFACE})"
    echo -e "  ${GREEN}${BOLD}✔ Rede virtual 'default'${NC} (192.168.122.0/24)"
    echo -e ""
    echo -e "  ${YELLOW}${BOLD}Próximos passos:${NC}"
    echo -e "  1. Faça ${BOLD}logout/login${NC} para o grupo libvirt entrar em vigor"
    echo -e "  2. Verifique com: ${CYAN}sudo ufw status verbose${NC}"
    echo -e "  3. Inicie o virt-manager: ${CYAN}virt-manager${NC}"
    echo -e ""
    echo -e "  ${BLUE}Topologia de rede:${NC}"
    echo -e "  VM (192.168.122.x) → virbr0 → NAT → ${PHY_IFACE} → Internet"
    echo -e ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║     QEMU + UFW Setup — Arch Linux            ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_root
    check_arch
    detect_interface

    echo ""
    warn "Este script irá:"
    echo "  • Instalar qemu-full, libvirt, virt-manager e dependências"
    echo "  • Habilitar libvirtd"
    echo "  • Configurar IP forwarding"
    echo "  • Configurar UFW (regras de forward + NAT via ${BOLD}${PHY_IFACE}${NC})"
    echo ""

    if ! confirm "Deseja continuar?"; then
        echo "Cancelado."
        exit 0
    fi

    install_qemu
    configure_libvirt
    configure_sysctl
    configure_ufw
    configure_libvirt_network
    show_summary
}

main "$@"
