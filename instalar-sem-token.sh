#!/usr/bin/env bash
# Instala o laboratório em Debian, Ubuntu ou derivados (Kali): identifica a distribuição, PARA o Scada-LTS que você já
# tem (sem apagar nada; você pode voltar a ele) e sobe o nosso, já com as conexões Modbus e a configuração prontas.
# O TOKEN fica para depois: quando tiver, rode ./adicionar-token.sh na pasta ~/scsep-scada-view.
#   Cole no terminal:
#     sudo apt update && sudo apt install -y curl && curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar-sem-token.sh | bash
export LAB_SEM_TOKEN=1 LAB_PARAR_TUDO=1
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
# só usa o instalar.sh local se este script foi executado a partir do pacote (e não colado por "curl | bash")
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -n "$AQUI" ] && [ -f "$AQUI/instalar.sh" ] && [ -f "$AQUI/iniciar.sh" ]; then exec bash "$AQUI/instalar.sh"; fi
curl -fsSL https://raw.githubusercontent.com/grei-ufc/scsep-scada-view/main/instalar.sh | bash
