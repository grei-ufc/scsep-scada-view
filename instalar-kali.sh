#!/usr/bin/env bash
# Instalador para KALI LINUX (base Debian; também serve para o Kali no WSL). Faz o mesmo que o instalar.sh,
# com os pacotes do Debian/Kali (docker.io + docker-compose) e o conserto da chave do apt, se precisar.
#   Cole no terminal do Kali:
#     sudo apt update && sudo apt install -y curl && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-kali.sh | bash
export LAB_KALI=1
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$AQUI" ] && [ -f "$AQUI/instalar.sh" ]; then exec bash "$AQUI/instalar.sh"; fi
curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar.sh | bash
