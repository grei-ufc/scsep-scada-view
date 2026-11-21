#!/usr/bin/env bash
# Instala o laboratório em Debian, Ubuntu ou derivados (Kali): identifica a distribuição, PARA o Scada-LTS que você já
# tem (sem apagar nada; você pode voltar a ele) e sobe o nosso, já com as conexões Modbus e a configuração prontas.
# O TOKEN fica para depois: quando tiver, rode ./adicionar-token.sh na pasta ~/scsep-scada-view.
#   Cole no terminal:
#     sudo apt update && sudo apt install -y curl && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-sem-token.sh | bash
export LAB_SEM_TOKEN=1 LAB_PARAR_TUDO=1
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$AQUI" ] && [ -f "$AQUI/instalar.sh" ]; then exec bash "$AQUI/instalar.sh"; fi
curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar.sh | bash
