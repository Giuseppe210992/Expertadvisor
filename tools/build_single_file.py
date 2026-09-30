"""
Genera una versione in UN SOLO FILE dell'EA (tutti i moduli CTO inclusi nel sorgente), da incollare
in un file creato con la procedura guidata di MetaEditor. Il codice e' quello dei moduli, copiato
meccanicamente: nessuna modifica alla logica. Resta solo #include <Trade\\Trade.mqh> (libreria standard MT5).

Uso: python tools/build_single_file.py  ->  MQL5/Experts/CTO/CoreTrendOverlay_single.mq5
"""
import os, re, hashlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "MQL5")
INC = os.path.join(ROOT, "Include", "CTO")
SRC = os.path.join(ROOT, "Experts", "CTO", "CoreTrendOverlay.mq5")
OUT = os.path.join(ROOT, "Experts", "CTO", "CoreTrendOverlay_single.mq5")
pat = re.compile(r'^\s*#include\s+(?:<CTO/([^>]+)>|"([^"]+)")\s*$')
done = set()


def inline(path):
    out = []
    for line in open(path, encoding="utf-8"):
        m = pat.match(line)
        if m:
            name = m.group(1) or m.group(2)
            if name not in done:
                done.add(name)
                out.append(f"//=== inizio {name} " + "=" * max(1, 60 - len(name)) + "\n")
                out.extend(inline(os.path.join(INC, name)))
                out.append(f"//=== fine {name} " + "=" * max(1, 62 - len(name)) + "\n")
            continue
        out.append(line)
    return out


body = inline(SRC)
header = ("//+------------------------------------------------------------------+\n"
          "//| CoreTrendOverlay - VERSIONE IN UN SOLO FILE (generata)            |\n"
          "//| Generata da tools/build_single_file.py a partire da               |\n"
          "//| Experts/CTO/CoreTrendOverlay.mq5 + Include/CTO/*.mqh.             |\n"
          "//| Non modificare questo file: modificare i sorgenti e rigenerarlo. |\n"
          "//+------------------------------------------------------------------+\n")
text = header + "".join(body)
open(OUT, "w", encoding="utf-8").write(text)
print(OUT, len(text.splitlines()), "righe, moduli inclusi:", ", ".join(sorted(done)),
      "sha1", hashlib.sha1(text.encode()).hexdigest()[:10])
