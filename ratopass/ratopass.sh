#!/usr/bin/env bash
# =============================================================================
#  ratopass.sh — Gerenciador de senhas via Bitwarden CLI • Arch Linux
#  Dependências (AUR/pacman): bitwarden-cli, jq, fzf, xclip ou wl-clipboard
#
#  Instalar tudo de uma vez:
#    pacman -S jq fzf
#    yay -S bitwarden-cli xclip     # ou wl-clipboard se usar Wayland
# =============================================================================

# ─── [SEC-01] Bash estrito + proteção contra globbing e divisão de palavras ──
# set -e  → aborta em erro
# set -u  → aborta em variável não definida
# set -o pipefail → propaga erros em pipes
# -f      → desabilita globbing (evita expansão inesperada de nomes de arquivo)
set -euo pipefail -f

# ─── [SEC-02] PATH explícito e seguro ────────────────────────────────────────
# Garante que só binários de locais confiáveis do sistema sejam usados,
# prevenindo PATH hijacking via variáveis de ambiente herdadas.
export PATH="/usr/local/bin:/usr/bin:/bin"

# ─── [SEC-03] Limpar variáveis de ambiente sensíveis herdadas ────────────────
# Impede que um ambiente comprometido injete comportamento no script.
unset LD_PRELOAD LD_LIBRARY_PATH CDPATH IFS

# ─── [SEC-04] IFS seguro e explícito ─────────────────────────────────────────
# Define IFS manualmente para evitar word splitting inesperado.
IFS=$' \t\n'

# ─── [SEC-05] Trap: limpeza garantida ao sair (EXIT, INT, TERM, HUP) ────────
# Garante que arquivos temporários e o clipboard sejam limpos mesmo em crash.
_TMPFILES=()
_CLIP_NEEDS_CLEAR=0

_cleanup() {
  # remove todos os arquivos temporários registrados
  for f in "${_TMPFILES[@]+"${_TMPFILES[@]}"}"; do
    [[ -f "$f" ]] && shred -u "$f" 2>/dev/null || rm -f "$f"
  done

  # limpa o clipboard se havia dado sensível
  if [[ "$_CLIP_NEEDS_CLEAR" -eq 1 ]] && [[ -n "${CLIP_CMD:-}" ]]; then
    printf '' | eval "$CLIP_CMD" 2>/dev/null || true
  fi
}

trap '_cleanup' EXIT
trap '_cleanup; exit 130' INT
trap '_cleanup; exit 143' TERM
trap '_cleanup; exit 129' HUP

# ─── Cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─── Configurações ────────────────────────────────────────────────────────────
CLIP_TIMEOUT=${RATOPASS_CLIP_TIMEOUT:-30}

# [SEC-06] Sessão em XDG_RUNTIME_DIR (tmpfs, modo 700 pelo systemd no Arch)
# Fallback para /tmp apenas se necessário, com aviso.
if [[ -d "${XDG_RUNTIME_DIR:-}" && -O "${XDG_RUNTIME_DIR:-}" ]]; then
  SESSION_FILE="${XDG_RUNTIME_DIR}/ratopass_session"
else
  SESSION_FILE="/tmp/ratopass_session_${UID}"
  _WARN_SESSION_FALLBACK=1
fi

CLIP_CMD=""
CLIP_PASTE=""

# ─── Utilitários ─────────────────────────────────────────────────────────────
log_info()    { echo -e "${CYAN}[•]${RESET} $*"; }
log_ok()      { echo -e "${GREEN}[✓]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
log_error()   { echo -e "${RED}[✗]${RESET} $*" >&2; }
log_section() { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━${RESET}"; }
separator()   { echo -e "${DIM}────────────────────────────────────────${RESET}"; }

banner() {
  echo -e "${BOLD}${MAGENTA}"
  cat << 'EOF'
  ██████╗  █████╗ ████████╗ ██████╗ ██████╗  █████╗ ███████╗███████╗
  ██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝
  ██████╔╝███████║   ██║   ██║   ██║██████╔╝███████║███████╗███████╗
  ██╔══██╗██╔══██║   ██║   ██║   ██║██╔═══╝ ██╔══██║╚════██║╚════██║
  ██║  ██║██║  ██║   ██║   ╚██████╔╝██║     ██║  ██║███████║███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝
EOF
  echo -e "${RESET}${DIM}        🐀 password manager via bitwarden-cli • Arch Linux${RESET}\n"
}

# ─── [SEC-07] Verificar permissões do script ─────────────────────────────────
# Impede execução se o script for world-writable (sinal de tampering).
check_script_perms() {
  local script_path
  script_path="$(realpath "${BASH_SOURCE[0]}")"
  local perms
  perms=$(stat -c '%a' "$script_path" 2>/dev/null || echo "000")

  # rejeita se outros (other) têm permissão de escrita
  if [[ "${perms: -1}" =~ [2367] ]]; then
    log_error "RISCO DE SEGURANÇA: o script '$script_path' é gravável por outros usuários!"
    log_error "Corrija com: chmod 750 '$script_path'"
    exit 1
  fi

  # rejeita execução como root (desnecessário e perigoso)
  if [[ "${EUID}" -eq 0 ]]; then
    log_error "Não execute o RatoPass como root."
    exit 1
  fi
}

# ─── Verificação de dependências (Arch-specific) ──────────────────────────────
check_deps() {
  local missing=()

  for cmd in bw jq fzf; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done

  # detecta Wayland ou X11 e escolhe ferramenta de clipboard
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if command -v wl-copy &>/dev/null; then
      CLIP_CMD="wl-copy"
      CLIP_PASTE="wl-paste"
    else
      log_warn "Wayland detectado mas wl-clipboard não encontrado."
      log_warn "  → sudo pacman -S wl-clipboard"
      CLIP_CMD=""
    fi
  elif [[ -n "${DISPLAY:-}" ]]; then
    if command -v xclip &>/dev/null; then
      CLIP_CMD="xclip -selection clipboard"
      CLIP_PASTE="xclip -selection clipboard -o"
    elif command -v xsel &>/dev/null; then
      CLIP_CMD="xsel --clipboard --input"
      CLIP_PASTE="xsel --clipboard --output"
    else
      log_warn "X11 detectado mas xclip/xsel não encontrado."
      log_warn "  → sudo pacman -S xclip"
      CLIP_CMD=""
    fi
  else
    log_warn "Sem display detectado (tty puro). Clipboard desabilitado."
    CLIP_CMD=""
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Dependências faltando: ${missing[*]}"
    echo ""
    echo -e "  ${BOLD}Instale com pacman/yay no Arch:${RESET}"
    echo ""
    for dep in "${missing[@]}"; do
      case "$dep" in
        bw)  echo -e "    ${YELLOW}bw${RESET}  → yay -S bitwarden-cli" ;;
        jq)  echo -e "    ${YELLOW}jq${RESET}  → sudo pacman -S jq" ;;
        fzf) echo -e "    ${YELLOW}fzf${RESET} → sudo pacman -S fzf" ;;
      esac
    done
    echo ""
    echo -e "  ${DIM}Clipboard (escolha um):${RESET}"
    echo -e "    X11:     sudo pacman -S xclip"
    echo -e "    Wayland: sudo pacman -S wl-clipboard"
    echo ""
    exit 1
  fi
}

# ─── [SEC-08] Validar token de sessão antes de usar ──────────────────────────
# Token válido do Bitwarden é um JWT: três partes base64 separadas por ponto.
_validate_session_token() {
  local token="$1"
  # JWT tem exatamente 3 segmentos separados por ponto
  if ! [[ "$token" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
    return 1
  fi
  # não deve ser trivialmente curto
  [[ ${#token} -gt 20 ]]
}

# ─── Sessão / Login ───────────────────────────────────────────────────────────
ensure_session() {
  # aviso de fallback de diretório de sessão
  if [[ "${_WARN_SESSION_FALLBACK:-0}" -eq 1 ]]; then
    log_warn "XDG_RUNTIME_DIR indisponível. Sessão em /tmp (menos seguro)."
  fi

  # 1. usa BW_SESSION do ambiente se válido
  if [[ -n "${BW_SESSION:-}" ]]; then
    if _validate_session_token "$BW_SESSION" && \
       bw status --session "$BW_SESSION" 2>/dev/null \
         | jq -e '.status == "unlocked"' &>/dev/null; then
      return 0
    fi
    unset BW_SESSION
  fi

  # 2. tenta restaurar sessão salva
  if [[ -f "$SESSION_FILE" ]]; then
    # [SEC-06 cont.] verifica que o arquivo pertence ao usuário atual
    local file_owner
    file_owner=$(stat -c '%u' "$SESSION_FILE" 2>/dev/null || echo "0")
    if [[ "$file_owner" != "${UID}" ]]; then
      log_error "Arquivo de sessão '$SESSION_FILE' não pertence ao usuário atual! Removendo."
      rm -f "$SESSION_FILE"
    else
      local saved_token
      saved_token=$(cat "$SESSION_FILE")
      if _validate_session_token "$saved_token"; then
        BW_SESSION="$saved_token"
        export BW_SESSION
        if bw status --session "$BW_SESSION" 2>/dev/null \
             | jq -e '.status == "unlocked"' &>/dev/null; then
          log_ok "Sessão restaurada"
          return 0
        fi
      fi
      # token inválido ou expirado — destrói com shred
      shred -u "$SESSION_FILE" 2>/dev/null || rm -f "$SESSION_FILE"
      unset BW_SESSION
    fi
  fi

  # 3. verifica estado atual do cofre
  local status
  status=$(bw status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "unauthenticated")

  case "$status" in
    "unauthenticated")
      log_info "Fazendo login no Bitwarden..."
      BW_SESSION=$(bw login --raw)
      ;;
    "locked")
      log_info "Cofre bloqueado. Digite sua senha mestra:"
      BW_SESSION=$(bw unlock --raw)
      ;;
    "unlocked")
      log_ok "Cofre desbloqueado"
      return 0
      ;;
    *)
      log_error "Status inesperado: $status"
      exit 1
      ;;
  esac

  # valida o token recém-obtido antes de salvar
  if ! _validate_session_token "$BW_SESSION"; then
    log_error "Token de sessão inválido recebido do Bitwarden CLI."
    exit 1
  fi

  export BW_SESSION

  # salva com permissões restritas desde o início (sem janela de exposição)
  install -m 600 /dev/null "$SESSION_FILE"
  printf '%s' "$BW_SESSION" > "$SESSION_FILE"
  log_ok "Sessão salva em $SESSION_FILE"
}

# ─── [SEC-09] Clipboard com autolimpeza garantida ────────────────────────────
# Usa printf em vez de echo para evitar interpretação de escape sequences.
# Registra flag global para que o trap EXIT também limpe se o script morrer.
copy_to_clip() {
  local value="$1"
  local label="${2:-valor}"

  if [[ -z "$CLIP_CMD" ]]; then
    log_warn "Clipboard indisponível. Exibindo na tela (cuidado!):"
    # [SEC-09] printf para não interpretar escapes de senhas arbitrárias
    printf '%s\n' "$value"
    return
  fi

  printf '%s' "$value" | eval "$CLIP_CMD"
  _CLIP_NEEDS_CLEAR=1

  log_ok "${BOLD}${label}${RESET}${GREEN} copiado para o clipboard"
  log_warn "Autolimpeza em ${CLIP_TIMEOUT}s..."

  (
    sleep "$CLIP_TIMEOUT"
    printf '' | eval "$CLIP_CMD" 2>/dev/null || true
  ) &
  disown
}

# ─── Sincronizar cofre ────────────────────────────────────────────────────────
sync_vault() {
  log_info "Sincronizando com os servidores Bitwarden..."
  bw sync --session "$BW_SESSION" > /dev/null
  log_ok "Cofre sincronizado!"
}

# ─── Busca fuzzy com fzf ──────────────────────────────────────────────────────
fzf_search() {
  local prompt="${1:-Buscar}"
  fzf \
    --prompt=" ${prompt} › " \
    --pointer="▶" \
    --marker="✓" \
    --height=65% \
    --min-height=15 \
    --border=rounded \
    --info=inline \
    --layout=reverse \
    --color="prompt:#a78bfa,pointer:#f472b6,marker:#34d399,border:#6366f1,header:#94a3b8" \
    --header=" [Enter] confirmar  [Esc/Ctrl+C] cancelar" \
    --no-sort \
    --cycle
}

# ─── Listar todos os itens ────────────────────────────────────────────────────
get_items() {
  bw list items --session "$BW_SESSION" 2>/dev/null
}

# ─── [SEC-10] Validador de UUID ───────────────────────────────────────────────
# IDs do Bitwarden são UUIDs v4. Valida antes de passar como argumento ao `bw`.
_assert_uuid() {
  local id="$1"
  [[ "$id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]
}

# ─── Menu principal ───────────────────────────────────────────────────────────
main_menu() {
  local opcao
  opcao=$(printf '%s\n' \
    "🔍  Buscar item" \
    "📋  Listar todos os itens" \
    "🔐  Filtrar por tipo" \
    "📁  Filtrar por pasta" \
    "🏷️   Filtrar por organização" \
    "➕  Gerar senha segura" \
    "🔄  Sincronizar cofre" \
    "ℹ️   Info do sistema" \
    "🔒  Bloquear e sair" \
    "❌  Sair sem bloquear" \
    | fzf_search "🐀 RatoPass") || { exit 0; }

  case "$opcao" in
    "🔍  Buscar item")              menu_search ;;
    "📋  Listar todos os itens")    menu_list_all ;;
    "🔐  Filtrar por tipo")         menu_filter_type ;;
    "📁  Filtrar por pasta")        menu_filter_folder ;;
    "🏷️   Filtrar por organização") menu_filter_org ;;
    "➕  Gerar senha segura")       menu_generate ;;
    "🔄  Sincronizar cofre")        sync_vault; sleep 1; main_menu ;;
    "ℹ️   Info do sistema")          menu_sysinfo ;;
    "🔒  Bloquear e sair")          lock_session ;;
    "❌  Sair sem bloquear")        exit 0 ;;
    *)                              main_menu ;;
  esac
}

# ─── Busca geral ──────────────────────────────────────────────────────────────
menu_search() {
  local items
  items=$(get_items)

  local selected
  selected=$(echo "$items" \
    | jq -r '.[] | "\(.id)\t\(.name)\t\(.login.username // "—")\t\(.login.uris[0].uri // "—")"' \
    | column -t -s $'\t' \
    | fzf_search "Buscar") || { main_menu; return; }

  local item_id
  item_id=$(echo "$selected" | awk '{print $1}')
  [[ -z "$item_id" ]] && { main_menu; return; }
  _assert_uuid "$item_id" || { log_error "ID inválido selecionado."; main_menu; return; }

  show_item_menu "$item_id" "$items"
}

# ─── Listar todos ─────────────────────────────────────────────────────────────
menu_list_all() {
  local items
  items=$(get_items)

  local count
  count=$(echo "$items" | jq 'length')
  log_info "Total no cofre: ${BOLD}${count} itens${RESET}"

  local selected
  selected=$(echo "$items" \
    | jq -r '.[] | [
        .id,
        (.type | if . == 1 then "🔑login" elif . == 2 then "📝nota" elif . == 3 then "💳cartão" else "👤identity" end),
        .name,
        (.login.username // .card.cardholderName // "—")
      ] | @tsv' \
    | column -t -s $'\t' \
    | fzf_search "Todos os itens ($count)") || { main_menu; return; }

  local item_id
  item_id=$(echo "$selected" | awk '{print $1}')
  [[ -z "$item_id" ]] && { main_menu; return; }
  _assert_uuid "$item_id" || { log_error "ID inválido."; main_menu; return; }

  show_item_menu "$item_id" "$items"
}

# ─── Filtrar por tipo ─────────────────────────────────────────────────────────
menu_filter_type() {
  local escolha
  escolha=$(printf '%s\n' \
    "1  🔑  Login / Senha" \
    "2  📝  Nota Segura" \
    "3  💳  Cartão de Crédito" \
    "4  👤  Identidade" \
    | fzf_search "Tipo de item") || { main_menu; return; }

  local tipo
  tipo=$(echo "$escolha" | awk '{print $1}')
  [[ -z "$tipo" ]] && { main_menu; return; }

  # [SEC-10] valida que tipo é exatamente 1-4
  if ! [[ "$tipo" =~ ^[1-4]$ ]]; then
    log_error "Tipo inválido."
    main_menu; return
  fi

  local items
  items=$(get_items)

  local selected
  selected=$(echo "$items" \
    | jq -r --argjson t "$tipo" \
      '.[] | select(.type == $t) | "\(.id)\t\(.name)\t\(.login.username // .card.cardholderName // "—")"' \
    | column -t -s $'\t' \
    | fzf_search "Tipo $escolha") || { menu_filter_type; return; }

  local item_id
  item_id=$(echo "$selected" | awk '{print $1}')
  [[ -z "$item_id" ]] && { menu_filter_type; return; }
  _assert_uuid "$item_id" || { log_error "ID inválido."; menu_filter_type; return; }

  show_item_menu "$item_id" "$items"
}

# ─── Filtrar por pasta ────────────────────────────────────────────────────────
menu_filter_folder() {
  local folders
  folders=$(bw list folders --session "$BW_SESSION" 2>/dev/null)

  local folder_name
  folder_name=$(echo "$folders" \
    | jq -r '.[].name' \
    | fzf_search "Selecionar pasta") || { main_menu; return; }

  [[ -z "$folder_name" ]] && { main_menu; return; }

  local folder_id
  folder_id=$(echo "$folders" \
    | jq -r --arg n "$folder_name" '.[] | select(.name == $n) | .id')

  # "No Folder" usa null — permitido; outros devem ser UUID
  if [[ "$folder_id" != "null" ]]; then
    _assert_uuid "$folder_id" || { log_error "ID de pasta inválido."; main_menu; return; }
  fi

  local items
  items=$(get_items)

  local selected
  selected=$(echo "$items" \
    | jq -r --arg fid "$folder_id" \
      '.[] | select(.folderId == $fid or ($fid == "null" and .folderId == null))
           | "\(.id)\t\(.name)\t\(.login.username // "—")"' \
    | column -t -s $'\t' \
    | fzf_search "📁 $folder_name") || { menu_filter_folder; return; }

  local item_id
  item_id=$(echo "$selected" | awk '{print $1}')
  [[ -z "$item_id" ]] && { menu_filter_folder; return; }
  _assert_uuid "$item_id" || { log_error "ID inválido."; menu_filter_folder; return; }

  show_item_menu "$item_id" "$items"
}

# ─── Filtrar por organização ──────────────────────────────────────────────────
menu_filter_org() {
  local orgs
  orgs=$(bw list organizations --session "$BW_SESSION" 2>/dev/null)

  if [[ $(echo "$orgs" | jq 'length') -eq 0 ]]; then
    log_warn "Nenhuma organização encontrada."
    sleep 1; main_menu; return
  fi

  local org_name
  org_name=$(echo "$orgs" \
    | jq -r '.[].name' \
    | fzf_search "Selecionar organização") || { main_menu; return; }

  [[ -z "$org_name" ]] && { main_menu; return; }

  local org_id
  org_id=$(echo "$orgs" \
    | jq -r --arg n "$org_name" '.[] | select(.name == $n) | .id')

  _assert_uuid "$org_id" || { log_error "ID de organização inválido."; main_menu; return; }

  local items
  items=$(get_items)

  local selected
  selected=$(echo "$items" \
    | jq -r --arg oid "$org_id" \
      '.[] | select(.organizationId == $oid) | "\(.id)\t\(.name)\t\(.login.username // "—")"' \
    | column -t -s $'\t' \
    | fzf_search "🏷️  $org_name") || { menu_filter_org; return; }

  local item_id
  item_id=$(echo "$selected" | awk '{print $1}')
  [[ -z "$item_id" ]] && { menu_filter_org; return; }
  _assert_uuid "$item_id" || { log_error "ID inválido."; menu_filter_org; return; }

  show_item_menu "$item_id" "$items"
}

# ─── Menu de ação do item ─────────────────────────────────────────────────────
show_item_menu() {
  local item_id="$1"
  local items="$2"

  # [SEC-10] revalida UUID a cada chamada
  _assert_uuid "$item_id" || { log_error "ID inválido."; main_menu; return; }

  local item
  item=$(echo "$items" | jq -r --arg id "$item_id" '.[] | select(.id == $id)')

  if [[ -z "$item" ]]; then
    log_error "Item não encontrado."
    main_menu; return
  fi

  local name type username url
  name=$(echo "$item" | jq -r '.name')
  type=$(echo "$item" | jq -r '.type')
  username=$(echo "$item" | jq -r '.login.username // "—"')
  url=$(echo "$item" | jq -r '.login.uris[0].uri // "—"')

  echo ""
  echo -e "  ${BOLD}${CYAN}$name${RESET}"
  [[ "$username" != "—" ]] && echo -e "  ${DIM}usuário :${RESET} $username"
  [[ "$url"      != "—" ]] && echo -e "  ${DIM}url     :${RESET} $url"
  separator

  local options=()

  if [[ "$type" == "1" ]]; then
    options+=(
      "🔑  Copiar senha"
      "👤  Copiar usuário"
      "🔗  Copiar URL"
    )
  fi

  if [[ "$type" == "3" ]]; then
    options+=(
      "💳  Copiar número do cartão"
      "📅  Copiar validade"
      "🔢  Copiar CVV"
      "🧾  Copiar titular"
    )
  fi

  local has_totp
  has_totp=$(echo "$item" | jq -r '.login.totp // empty')
  [[ -n "$has_totp" ]] && options+=("⏱️   Copiar código TOTP (2FA)")

  local custom_count
  custom_count=$(echo "$item" | jq '[.fields // [] | .[] | select(.type == 0)] | length')
  [[ "$custom_count" -gt 0 ]] && options+=("🧩  Copiar campo customizado")

  local has_notes
  has_notes=$(echo "$item" | jq -r '.notes // empty')
  [[ -n "$has_notes" ]] && options+=("📋  Ver notas")

  options+=(
    "👁️   Ver detalhes completos (cuidado!)"
    "✏️   Editar no \$EDITOR"
    "🗑️   Excluir item"
    "⬅️   Voltar ao menu"
  )

  local acao
  acao=$(printf '%s\n' "${options[@]}" \
    | fzf_search "$name") || { main_menu; return; }

  case "$acao" in
    "🔑  Copiar senha")
      copy_to_clip "$(echo "$item" | jq -r '.login.password')" "Senha de $name"
      ;;
    "👤  Copiar usuário")
      copy_to_clip "$username" "Usuário de $name"
      ;;
    "🔗  Copiar URL")
      copy_to_clip "$url" "URL de $name"
      ;;
    "💳  Copiar número do cartão")
      copy_to_clip "$(echo "$item" | jq -r '.card.number')" "Número do cartão"
      ;;
    "📅  Copiar validade")
      copy_to_clip "$(echo "$item" | jq -r '"\(.card.expMonth)/\(.card.expYear)"')" "Validade"
      ;;
    "🔢  Copiar CVV")
      copy_to_clip "$(echo "$item" | jq -r '.card.code')" "CVV"
      ;;
    "🧾  Copiar titular")
      copy_to_clip "$(echo "$item" | jq -r '.card.cardholderName')" "Titular"
      ;;
    "⏱️   Copiar código TOTP (2FA)")
      local totp
      totp=$(bw get totp "$item_id" --session "$BW_SESSION" 2>/dev/null)
      copy_to_clip "$totp" "TOTP"
      ;;
    "🧩  Copiar campo customizado")
      local campo
      campo=$(echo "$item" \
        | jq -r '[.fields // [] | .[] | select(.type == 0)] | .[] | "\(.name)\t\(.value)"' \
        | column -t -s $'\t' \
        | fzf_search "Campo customizado") || { show_item_menu "$item_id" "$items"; return; }
      local field_name
      field_name=$(echo "$campo" | awk '{print $1}')
      local field_val
      field_val=$(echo "$item" \
        | jq -r --arg n "$field_name" '.fields[] | select(.name == $n) | .value')
      copy_to_clip "$field_val" "Campo '$field_name'"
      ;;
    "📋  Ver notas")
      echo ""
      echo "$item" | jq -r '.notes' | less -R
      ;;
    "👁️   Ver detalhes completos (cuidado!)")
      log_warn "Exibindo dados sensíveis! Pressione Q para fechar."
      sleep 1
      echo "$item" | jq '.' | less -R
      ;;
    "✏️   Editar no \$EDITOR")
      # [SEC-11] arquivo temporário com permissão restrita desde a criação,
      # registrado para shred no trap EXIT
      local tmpfile
      tmpfile=$(mktemp "${SESSION_FILE%/*}/ratopass.XXXXXX.json")
      chmod 600 "$tmpfile"
      _TMPFILES+=("$tmpfile")

      echo "$item" | jq '.' > "$tmpfile"
      ${EDITOR:-vim} "$tmpfile"

      # [SEC-11] valida que o JSON editado ainda é válido antes de enviar
      if ! jq empty "$tmpfile" 2>/dev/null; then
        log_error "JSON inválido após edição. Abortando envio ao Bitwarden."
      else
        bw edit item "$item_id" --session "$BW_SESSION" < "$tmpfile" > /dev/null
        log_ok "Item '$name' atualizado!"
      fi

      # destrói o arquivo temporário com shred (sobrescreve antes de deletar)
      shred -u "$tmpfile" 2>/dev/null || rm -f "$tmpfile"
      _TMPFILES=("${_TMPFILES[@]/$tmpfile}")
      sleep 1
      items=$(get_items)
      ;;
    "🗑️   Excluir item")
      echo ""
      echo -e "  ${RED}${BOLD}Confirmar exclusão de '$name'? [s/N]${RESET} "
      read -r confirm
      if [[ "$confirm" =~ ^[sS]$ ]]; then
        bw delete item "$item_id" --session "$BW_SESSION" > /dev/null
        log_ok "Item '$name' excluído."
        sleep 1
        main_menu
        return
      else
        log_warn "Cancelado."
      fi
      ;;
    "⬅️   Voltar ao menu"|"")
      main_menu
      return
      ;;
  esac

  show_item_menu "$item_id" "$items"
}

# ─── Gerador de senhas ────────────────────────────────────────────────────────
menu_generate() {
  log_section "Gerador de Senhas"

  local tipo
  tipo=$(printf '%s\n' \
    "password    — Senha aleatória com símbolos" \
    "passphrase  — Frase de senha (mais fácil de lembrar)" \
    | fzf_search "Tipo") || { main_menu; return; }

  tipo=$(echo "$tipo" | awk '{print $1}')
  [[ -z "$tipo" ]] && { main_menu; return; }

  # [SEC-10] valida que tipo é exatamente password ou passphrase
  if [[ "$tipo" != "password" && "$tipo" != "passphrase" ]]; then
    log_error "Tipo inválido."
    main_menu; return
  fi

  local generated

  if [[ "$tipo" == "passphrase" ]]; then
    echo -n "  Quantidade de palavras [4]: "
    read -r words
    words=${words:-4}
    # [SEC-10] valida intervalo numérico
    if ! [[ "$words" =~ ^[0-9]+$ ]] || (( words < 3 || words > 20 )); then
      log_warn "Valor inválido. Usando 4."
      words=4
    fi
    echo -n "  Separador (1 char) [-]: "
    read -r sep
    sep=${sep:--}
    # [SEC-10] restringe separador a 1 caractere não especial de shell
    if [[ ${#sep} -ne 1 ]] || [[ "$sep" =~ [\"\'\\;|&\`\$\(\)] ]]; then
      log_warn "Separador inválido. Usando '-'."
      sep="-"
    fi
    generated=$(bw generate \
      --passphrase \
      --words "$words" \
      --separator "$sep" \
      --session "$BW_SESSION" 2>/dev/null)
  else
    echo -n "  Comprimento [20]: "
    read -r length
    length=${length:-20}
    # [SEC-10] valida intervalo numérico
    if ! [[ "$length" =~ ^[0-9]+$ ]] || (( length < 8 || length > 128 )); then
      log_warn "Comprimento inválido. Usando 20."
      length=20
    fi
    generated=$(bw generate \
      --length "$length" \
      --uppercase \
      --lowercase \
      --number \
      --special \
      --session "$BW_SESSION" 2>/dev/null)
  fi

  echo ""
  echo -e "  ${BOLD}${GREEN}Senha gerada:${RESET}"
  # [SEC-09] printf para não interpretar escapes da senha gerada
  printf '  %s\n' "$generated"
  echo ""

  local acao
  acao=$(printf '%s\n' \
    "📋  Copiar para clipboard" \
    "🔁  Gerar outra" \
    "⬅️   Voltar" \
    | fzf_search "O que fazer?") || { main_menu; return; }

  case "$acao" in
    "📋  Copiar para clipboard") copy_to_clip "$generated" "Senha gerada" ;;
    "🔁  Gerar outra")           menu_generate; return ;;
  esac

  main_menu
}

# ─── Info do sistema ──────────────────────────────────────────────────────────
menu_sysinfo() {
  log_section "Info do Sistema"

  local bw_ver kernel display
  bw_ver=$(bw --version 2>/dev/null || echo "desconhecido")
  kernel=$(uname -r)
  display="${WAYLAND_DISPLAY:-}${DISPLAY:-}"

  echo -e "  ${DIM}bitwarden-cli:${RESET} $bw_ver"
  echo -e "  ${DIM}kernel       :${RESET} $kernel"
  echo -e "  ${DIM}display      :${RESET} ${display:-nenhum detectado}"
  echo -e "  ${DIM}clipboard    :${RESET} ${CLIP_CMD:-desabilitado}"
  echo -e "  ${DIM}sessão salva :${RESET} ${SESSION_FILE}"
  echo -e "  ${DIM}autolimpeza  :${RESET} ${CLIP_TIMEOUT}s"
  echo -e "  ${DIM}editor       :${RESET} ${EDITOR:-vim (padrão)}"
  separator

  local status_json
  status_json=$(bw status --session "${BW_SESSION:-}" 2>/dev/null || echo '{}')
  local vault_status user_email
  vault_status=$(echo "$status_json" | jq -r '.status // "desconhecido"')
  user_email=$(echo "$status_json" | jq -r '.userEmail // "—"')

  echo -e "  ${DIM}status cofre :${RESET} ${vault_status}"
  echo -e "  ${DIM}conta        :${RESET} ${user_email}"
  echo ""
  echo -e "  ${DIM}Pressione Enter para voltar...${RESET}"
  read -r
  main_menu
}

# ─── Bloquear sessão ──────────────────────────────────────────────────────────
lock_session() {
  bw lock 2>/dev/null || true
  # [SEC-11] destrói arquivo de sessão de forma segura com shred
  [[ -f "$SESSION_FILE" ]] && { shred -u "$SESSION_FILE" 2>/dev/null || rm -f "$SESSION_FILE"; }
  unset BW_SESSION
  echo ""
  log_ok "Cofre bloqueado. Até logo! 🐀"
  echo ""
  exit 0
}

# ─── Ponto de entrada ─────────────────────────────────────────────────────────
main() {
  clear
  banner
  check_script_perms  # [SEC-07]
  check_deps
  ensure_session
  echo ""
  main_menu
}

main "$@"
