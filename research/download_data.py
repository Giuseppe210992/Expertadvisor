"""
Scarica dati storici Oanda al minuto (2005-2020) dal repository pubblico
FutureSharks/financial-data e li ricampiona a M15, salvandoli in research/data/<SYM>_M15.csv.gz

Uso: python download_data.py EUR_USD XAU_USD ...
Il file-list viene ottenuto da un clone "blobless" (git ls-tree), vedi README.
"""
import sys, io, os, subprocess, concurrent.futures as cf
import pandas as pd, requests

RAW = "https://raw.githubusercontent.com/FutureSharks/financial-data/master/"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "data")

def file_list():
    p = "/tmp/fd_files.txt"
    if not os.path.exists(p):
        subprocess.run("git clone --depth 1 --filter=blob:none --no-checkout "
                       "https://github.com/FutureSharks/financial-data.git /tmp/fd && "
                       "cd /tmp/fd && git ls-tree -r --name-only HEAD > /tmp/fd_files.txt", shell=True, check=True)
    return [l.strip() for l in open(p) if "/oanda/" in l]

def fetch(path):
    for _ in range(4):
        try:
            r = requests.get(RAW + path, timeout=60)
            if r.status_code == 200:
                df = pd.read_csv(io.StringIO(r.text), parse_dates=["time"], index_col="time")
                return df.resample("15min").agg({"open": "first", "high": "max", "low": "min",
                                                 "close": "last", "volume": "sum"}).dropna()
        except Exception:
            pass
    print("FAILED", path, flush=True)
    return None

def main(syms):
    files = file_list()
    os.makedirs(OUT, exist_ok=True)
    for s in syms:
        dst = os.path.join(OUT, f"{s}_M15.csv.gz")
        if os.path.exists(dst):
            print("skip", s); continue
        paths = [f for f in files if f"/oanda/{s}/" in f and f.endswith(".csv")]
        with cf.ThreadPoolExecutor(12) as ex:
            parts = [p for p in ex.map(fetch, paths) if p is not None]
        df = pd.concat(parts).sort_index()
        df = df[~df.index.duplicated()]
        df.to_csv(dst, compression="gzip")
        print(s, len(paths), "files", df.index[0], "->", df.index[-1], len(df), "bars", flush=True)

if __name__ == "__main__":
    main(sys.argv[1:])
