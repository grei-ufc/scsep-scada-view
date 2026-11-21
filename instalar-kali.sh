#!/usr/bin/env bash
# Instalador para KALI LINUX (base Debian; também serve para o Kali no WSL). Faz o mesmo que o instalar.sh,
# com os pacotes do Debian/Kali (docker.io + docker-compose) e o conserto da chave do apt, se precisar.
#   Cole no terminal do Kali:
#     sudo apt update && sudo apt install -y curl && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-kali.sh | bash
export LAB_KALI=1
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
# só usa o instalar.sh local se este script foi executado a partir do pacote (e não colado por "curl | bash")
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -n "$AQUI" ] && [ -f "$AQUI/instalar.sh" ] && [ -f "$AQUI/iniciar.sh" ]; then exec bash "$AQUI/instalar.sh"; fi
curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar.sh | bash
