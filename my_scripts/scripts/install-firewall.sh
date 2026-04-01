#!/bin/sh

set -e
sudo pacman -S --nocconfirm ufw
sudo systemctl enable --now ufw.service
sudo ufw enable

echo "[+] Detectando interface de internet..."
WAN_IF=$(ip route | awk '/default/ {print $5}' | head -n1)

if [ -z "$WAN_IF" ]; then
  echo "[-] Não foi possível detectar interface de internet."
  exit 1
fi

echo "[+] Interface detectada: $WAN_IF"

echo "[+] Detectando bridge do libvirt..."
BRIDGE=$(ip -br a | grep virbr | awk '{print $1}' | head -n1)

if [ -z "$BRIDGE" ]; then
  echo "[-] Nenhuma bridge virbr encontrada."
  exit 1
fi

echo "[+] Bridge detectada: $BRIDGE"

echo "[+] Detectando rede da bridge..."
NETWORK=$(ip -4 addr show $BRIDGE | grep inet | awk '{print $2}')

if [ -z "$NETWORK" ]; then
  echo "[-] Não foi possível detectar rede da bridge."
  exit 1
fi

echo "[+] Rede detectada: $NETWORK"

echo "[+] Liberando tráfego no UFW..."
sudo ufw allow in on $BRIDGE
sudo ufw allow out on $BRIDGE

echo "[+] Ajustando política de forwarding..."

sudo sed -i \
  's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' \
  /etc/default/ufw

echo "[+] Verificando regra NAT..."

if ! grep -q "$NETWORK" /etc/ufw/before.rules; then

  echo "[+] Adicionando NAT ao UFW..."

  sudo sed -i "/\*filter/i \
*nat\n\
:POSTROUTING ACCEPT [0:0]\n\
-A POSTROUTING -s $NETWORK -o $WAN_IF -j MASQUERADE\n\
COMMIT\n" /etc/ufw/before.rules

else
  echo "[+] Regra NAT já existe."
fi

echo "[+] Recarregando UFW..."
sudo ufw reload

echo ""
echo "[✓] Rede das VMs configurada com sucesso!"
echo "Bridge: $BRIDGE"
echo "Rede: $NETWORK"
echo "Saída para internet: $WAN_IF"
