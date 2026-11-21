# Laboratório Virtual de Subestações: vpn-local + Scada-LTS em Docker

Pacote Docker que sobe, no computador do aluno, o **Scada-LTS** (com MySQL) e a **vpn-local**, a peça que liga o Scada-LTS à simulação 3D do laboratório. Não é preciso instalar nenhum programa no Windows além do WSL e do Docker.

```
Sala 3D (site) ──► Servidor do laboratório ◄── HTTPS (só saída) ── vpn-local ◄── Modbus TCP ── Scada-LTS
                                                                  └──────── mesma rede Docker ────────┘
```

| Contêiner | Para quê |
|---|---|
| `vpn-local` | Expõe o seu laboratório como dispositivos Modbus TCP (`127.0.0.11` a `.14`, porta `5020`) e leva os comandos do Scada-LTS ao servidor |
| `scadalts` | [Scada-LTS](https://github.com/SCADA-LTS/Scada-LTS), o supervisório (mestre Modbus) |
| `mysql` | Banco do Scada-LTS |
| `rede` | Contêiner mínimo dono da rede compartilhada |

## Tutorial completo (PDF)

0. [`docs/03-instalacao-simples-vpn-local.pdf`](docs/03-instalacao-simples-vpn-local.pdf): **comece por aqui**: instalação simples, para quem não é técnico.
1. [`docs/01-instalacao-wsl-docker-scada-vpn-local.pdf`](docs/01-instalacao-wsl-docker-scada-vpn-local.pdf): instalar WSL, Docker, Scada-LTS e a vpn-local, passo a passo com espaços para print.
2. [`docs/02-primeiros-passos-no-scada-lts.pdf`](docs/02-primeiros-passos-no-scada-lts.pdf): usuários e senhas, Data Source e registradores Modbus TCP no Scada-LTS.

Manual de registradores: [`docs/registradores-no-scada-lts.pdf`](docs/registradores-no-scada-lts.pdf) (documento anterior, ainda usa o nome antigo "Ponte").

## Início rápido

Pré-requisitos: **WSL** e **Docker** já instalados (`docker compose version` funcionando) e uma conta no site do laboratório. Comandos no terminal do WSL.

```bash
# 1. Baixar o pacote
cd ~
git clone https://github.com/grei-ufc/scsep-scada-view.git
cd scsep-scada-view

# 2. Pegar o token: site do laboratório > Meu laboratório > Token de ativação > Copiar token

# 3. Instalar e subir: instala o Docker se faltar e pergunta o token
./instalar.sh        # nas próximas vezes: ./iniciar.sh
```

Depois de 1 a 3 minutos, abra **http://localhost:8080/Scada-LTS/** (`admin` / `admin`; troque a senha) e importe `scada-lts/scada-lts-import.json` em **Import/Export**.

## Onde fica o token

No arquivo `.env`, na linha `CHAVE=`. Sem o script: `cp .env.example .env`, edite e rode `docker compose up -d --build`.

| Variável | Significado | Padrão |
|---|---|---|
| `SERVIDOR` | Endereço do site do laboratório | `https://scsep.joaopedromagalhaes.com.br` |
| `CHAVE` | **Token de ativação** (`ak_…`) de "Meu laboratório" | vazio |
| `NOME` | Nome desta instalação | `Scada-LTS (Docker)` |
| `SCADA_PORT` | Porta do Scada-LTS no seu computador | `8080` |

O token só é lido na primeira ativação; depois a vpn-local guarda a credencial no volume `scada-lab_vpn-local_data`. Para trocar de token: `docker compose down`, `docker volume rm scada-lab_vpn-local_data`, ajuste `CHAVE` e `docker compose up -d`.

## Comandos do dia a dia

| Quero… | Comando |
|---|---|
| Ver o que a vpn-local faz | `docker logs -f vpn-local` |
| Reiniciar a vpn-local / o Scada-LTS | `docker restart vpn-local` / `docker restart scadalts` |
| Parar tudo (guarda os dados) | `docker compose down` |
| Apagar tudo, inclusive banco e credencial | `docker compose down -v` |
| Atualizar o pacote | `git pull && docker compose up -d --build` |

## Conteúdo

```
instalar.sh              # instala o Docker (se faltar) e chama o iniciar.sh
iniciar.sh               # pergunta o token, grava o .env e sobe tudo
docker-compose.yml       # rede, mysql, vpn-local, scadalts
.env.example             # modelo de configuração (copie para .env)
vpn-local/                   # Dockerfile e vpn-local-service.cjs (a vpn-local como serviço, gerado)
scada-lts/               # scada-lts-import.json: 4 Data Sources, 25 pontos, 14 point links e a tela gráfica "Painel de comando"
docs/                    # tutoriais em PDF
```

## Segurança

O `.env` e a credencial da vpn-local (guardada em texto no volume Docker) são pessoais: não compartilhe nem faça commit do `.env` (já está no `.gitignore`). O banco usa `root`/`root` e só é acessível dentro do Docker.
