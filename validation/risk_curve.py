"""
Curva rischio -> rendimento -> rovina per una sequenza di trade gia' prodotta da una strategia CONGELATA.
Non modifica la strategia: cambia solo la frazione di capitale rischiata per trade (1 R = rischio allo stop).

Metodo
  - input: trade con data di chiusura e R netto per ingresso (net / rischio iniziale)
  - si raggruppano i trade per mese di calendario (mesi senza trade inclusi)
  - bootstrap a blocchi di mesi consecutivi (default 3) per conservare i periodi favorevoli/sfavorevoli
  - per ogni rischio r: equity *= (1 + r * R) trade per trade, nell'ordine; se r*R <= -1 il conto e' azzerato
  - orizzonti 3, 6, 12 mesi e intero periodo; oltre al bootstrap si riporta il percorso storico reale

Metriche per rischio e orizzonte:
  rendimento annualizzato mediano, capitale finale mediano / 5 perc. / 95 perc. (multiplo del capitale iniziale),
  DD massimo mediano e al 95 perc., P(DD>=10/20/30/50%), P(rovina) = P(perdita >= 90% in un qualsiasi momento)

Limite noto: i trade aperti in parallelo su strumenti diversi sono trattati in sequenza (per data di chiusura);
con rischi alti la perdita simultanea di piu' posizioni e' quindi SOTTOSTIMATA. I risultati ai rischi estremi
sono un limite inferiore della pericolosita' reale.
"""
import numpy as np
import pandas as pd

RISKS = [0.25, 0.5, 1, 2, 5, 10, 20, 50]
HORIZONS = [3, 6, 12]
RUIN = 0.90


def monthly_blocks(trades):
    """trades: DataFrame con colonne t_out (datetime) e R. Ritorna lista di array di R per mese (inclusi mesi vuoti)."""
    t = trades.sort_values("t_out")
    m = t.t_out.dt.to_period("M")
    months = pd.period_range(m.min(), m.max(), freq="M")
    by = {k: g.R.values for k, g in t.groupby(m)}
    return [by.get(k, np.array([])) for k in months]


def _path_stats(seq_months, r):
    eq, peak, mdd = 1.0, 1.0, 0.0
    ruined = False
    for arr in seq_months:
        for x in arr:
            eq *= max(1.0 + r * x, 0.0)
            peak = max(peak, eq)
            mdd = max(mdd, 1.0 - eq / peak if peak > 0 else 1.0)
            if eq <= 1.0 - RUIN:
                ruined = True
            if eq <= 0.0:
                return 0.0, 1.0, True
    return eq, mdd, ruined


def curve(trades, risks=RISKS, horizons=HORIZONS, n_sims=4000, block=3, seed=1):
    months = monthly_blocks(trades)
    n_m = len(months)
    rng = np.random.default_rng(seed)
    rows = []
    for h in list(horizons) + ["intero periodo"]:
        H = n_m if h == "intero periodo" else h
        nb = int(np.ceil(H / block))
        starts = rng.integers(0, max(n_m - block + 1, 1), size=(n_sims, nb))
        sims = [[months[s + k] for s in st for k in range(block) if s + k < n_m][:H] for st in starts]
        for rk in risks:
            r = rk / 100.0
            res = np.array([_path_stats(sm, r) for sm in sims], dtype=object)
            fin = res[:, 0].astype(float); mdd = res[:, 1].astype(float); ruin = res[:, 2].astype(bool)
            yrs = H / 12.0
            ann = np.where(fin > 0, fin ** (1 / yrs) - 1, -1.0)
            row = {"orizzonte": f"{h} mesi" if h != "intero periodo" else f"intero periodo ({n_m} mesi)",
                   "rischio/trade %": rk, "rend. annuo mediano": np.median(ann),
                   "capitale mediano (x)": np.median(fin), "5° perc. (x)": np.percentile(fin, 5),
                   "95° perc. (x)": np.percentile(fin, 95), "DD max mediano": np.median(mdd),
                   "DD max 95° perc.": np.percentile(mdd, 95)}
            for d in (0.10, 0.20, 0.30, 0.50):
                row[f"P(DD>={int(d*100)}%)"] = (mdd >= d).mean()
            row["P(rovina: -90%)"] = ruin.mean()
            if h == "intero periodo":
                f_h, m_h, r_h = _path_stats(months, r)
                row["storico: capitale (x)"] = f_h
                row["storico: DD max"] = m_h
            rows.append(row)
    return pd.DataFrame(rows)


def to_markdown(df):
    fmt = df.copy()
    pct = [c for c in fmt.columns if c.startswith("P(") or c.startswith("rend.") or c.startswith("DD") or c == "storico: DD max"]
    for c in pct:
        fmt[c] = fmt[c].map(lambda v: "" if pd.isna(v) else f"{v:.1%}")
    for c in ["capitale mediano (x)", "5° perc. (x)", "95° perc. (x)", "storico: capitale (x)"]:
        if c in fmt:
            fmt[c] = fmt[c].map(lambda v: "" if pd.isna(v) else f"{v:.3g}")
    return fmt.to_markdown(index=False)
