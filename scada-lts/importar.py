#!/usr/bin/env python3
"""Importa a configuração (Data Sources, pontos, controles e tela gráfica) no Scada-LTS.

Faz o mesmo que colar o JSON em Import/Export > Import. Uso:
    python3 scada-lts/importar.py [arquivo.json] [http://localhost:8080/Scada-LTS]
Entra como admin/admin. Se você já trocou a senha do admin, use as variáveis SCADA_USER e SCADA_SENHA.
"""
import http.cookiejar
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ARQ = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "scada-lts-import.json")
BASE = (sys.argv[2] if len(sys.argv) > 2 else "http://localhost:8080/Scada-LTS").rstrip("/")
USUARIO = os.environ.get("SCADA_USER", "admin")
SENHA = os.environ.get("SCADA_SENHA", "admin")


def conectar(tentativas=90):
    """Espera o Scada-LTS terminar de iniciar e entra com o usuário. Devolve (opener, sessão)."""
    ultimo = ""
    recusas = 0
    for _ in range(tentativas):
        try:
            cj = http.cookiejar.CookieJar()
            op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
            op.open(BASE + "/login.htm", timeout=10).read()
            op.open(urllib.request.Request(BASE + "/login.htm", urllib.parse.urlencode({"username": USUARIO, "password": SENHA}).encode()), timeout=10).read()
            eng = op.open(BASE + "/dwr/engine.js", timeout=10).read().decode()
            sid = re.search(r'_origScriptSessionId\s*=\s*"([^"]+)"', eng).group(1) + "123"
            jsess = [c.value for c in cj if c.name == "JSESSIONID"][0]
            # confirma que o login valeu (página de importação só abre logado)
            pagina = op.open(BASE + "/emport.shtm", timeout=10).read().decode("utf-8", "replace")
            if "EmportDwr" not in pagina:
                raise RuntimeError("login recusado (usuário ou senha do admin diferentes?)")
            return op, sid, jsess
        except RuntimeError as e:
            recusas += 1
            ultimo = str(e)
            if recusas >= 4:
                sys.exit("Não consegui entrar no Scada-LTS: " + ultimo + ". Se você trocou a senha do admin, rode: SCADA_SENHA=suasenha python3 scada-lts/importar.py")
            time.sleep(2)
        except (urllib.error.URLError, OSError, AttributeError, IndexError) as e:
            ultimo = str(e)
            time.sleep(2)
    sys.exit(f"Scada-LTS não respondeu a tempo ({ultimo})")


def chamar(op, sid, jsess, metodo, params, lote):
    linhas = ["callCount=1", "page=/" + BASE.split("/", 3)[3] + "/emport.shtm", "httpSessionId=" + jsess, "scriptSessionId=" + sid,
              "c0-scriptName=EmportDwr", "c0-methodName=" + metodo, "c0-id=0"]
    linhas += [f"c0-param{i}=string:" + urllib.parse.quote(p, safe="") for i, p in enumerate(params)]
    linhas += ["batchId=%d" % lote, ""]
    req = urllib.request.Request(BASE + f"/dwr/call/plaincall/EmportDwr.{metodo}.dwr", "\n".join(linhas).encode(), {"Content-Type": "text/plain"})
    return re.sub(r"\s+", " ", op.open(req, timeout=60).read().decode("utf-8", "replace"))


def main():
    dados = open(ARQ, encoding="utf-8").read()
    op, sid, jsess = conectar()
    r = chamar(op, sid, jsess, "importData", [dados], 0)
    if "importStarted=true" not in r:
        sys.exit("O Scada-LTS não iniciou a importação: " + r[-200:])
    ultimo = ""
    for i in range(1, 300):
        r = chamar(op, sid, jsess, "importUpdate", [], i)
        if "noImport=true" in r:
            break
        ultimo = r
        if "complete=true" in r or "cancelled=true" in r:
            break
        time.sleep(0.2)
    msgs = [m.replace("\\'", "'") for m in re.findall(r'genericMessage="((?:[^"\\]|\\.)*)"', ultimo)]
    erros = [m for m in msgs if not re.search(r"\b(saved|added)\b", m)]
    for m in erros:
        print("  ERRO:", m)
    ok = len(msgs) - len(erros)
    print(f"Importação concluída: {ok} itens salvos, {len(erros)} erros.")
    sys.exit(1 if erros or ok == 0 else 0)


if __name__ == "__main__":
    main()
