#!/usr/bin/env bash
# Para quem JÁ TEM o Scada-LTS e quer MANTER o dele: instala o vpn-local, liga-o ao seu Scada-LTS e aplica nele
# a configuração do laboratório (Data Sources, pontos, controles e a tela "Painel de comando"). Nada é parado nem apagado.
#   Cole no terminal do Ubuntu/Kali:
#     sudo apt update && sudo apt install -y curl && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-no-meu-scada.sh | bash
export LAB_MODO=meu-scada
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$AQUI" ] && [ -f "$AQUI/instalar.sh" ]; then exec bash "$AQUI/instalar.sh"; fi
curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar.sh | bash
