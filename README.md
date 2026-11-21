# Laboratório Virtual de Subestações: Ponte + Scada-LTS em Docker

Pacote Docker que sobe, no computador do aluno, o **Scada-LTS** (com MySQL) e a **Ponte**, a peça que liga o Scada-LTS à simulação 3D do laboratório. Não é preciso instalar nenhum programa no Windows além do WSL e do Docker.

```
Sala 3D (site) ──► Servidor do laboratório ◄── HTTPS (só saída) ── Ponte ◄── Modbus TCP ── Scada-LTS
                                                                  └──────── mesma rede Docker ────────┘
```

| Contêiner | Para quê |
|---|---|
| `ponte` | Expõe o seu laboratório como dispositivos Modbus TCP (`127.0.0.11` a `.14`, porta `5020`) e leva os comandos do Scada-LTS ao servidor |
| `scadalts` | [Scada-LTS](https://github.com/SCADA-LTS/Scada-LTS), o supervisório (mestre Modbus) |
| `mysql` | Banco do Scada-LTS |
| `rede` | Contêiner mínimo dono da rede compartilhada |

## Tutorial completo (PDF)

[`docs/tutorial-instalacao-docker.pdf`](docs/tutorial-instalacao-docker.pdf): passo a passo ilustrado, com solução de problemas.
Manual de registradores: [`docs/registradores-no-scada-lts.pdf`](docs/registradores-no-scada-lts.pdf).

## Início rápido

Pré-requisitos: **WSL** e **Docker** já instalados (`docker compose version` funcionando) e uma conta no site do laboratório. Comandos no terminal do WSL.

```bash
# 1. Baixar o pacote
cd ~
git clone <ENDEREÇO-DESTE-REPOSITÓRIO>
cd <NOME-DA-PASTA>

# 2. Pegar o token: site do laboratório > Meu laboratório > Token de ativação > Copiar token

# 3. Subir (o script pergunta o token e grava o .env)
./iniciar.sh
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

O token só é lido na primeira ativação; depois a Ponte guarda a credencial no volume `scada-lab_ponte_data`. Para trocar de token: `docker compose down`, `docker volume rm scada-lab_ponte_data`, ajuste `CHAVE` e `docker compose up -d`.

## Comandos do dia a dia

| Quero… | Comando |
|---|---|
| Ver o que a Ponte faz | `docker logs -f ponte` |
| Reiniciar a Ponte / o Scada-LTS | `docker restart ponte` / `docker restart scadalts` |
| Parar tudo (guarda os dados) | `docker compose down` |
| Apagar tudo, inclusive banco e credencial | `docker compose down -v` |
| Atualizar o pacote | `git pull && docker compose up -d --build` |

## Conteúdo

```
iniciar.sh               # pergunta o token, grava o .env e sobe tudo
docker-compose.yml       # rede, mysql, ponte, scadalts
.env.example             # modelo de configuração (copie para .env)
ponte/                   # Dockerfile e ponte-service.cjs (a Ponte como serviço, gerado)
scada-lts/               # scada-lts-import.json: 3 Data Sources e 18 pontos
docs/                    # tutoriais em PDF
```

## Segurança

O `.env` e a credencial da Ponte (guardada em texto no volume Docker) são pessoais: não compartilhe nem faça commit do `.env` (já está no `.gitignore`). O banco usa `root`/`root` e só é acessível dentro do Docker.
