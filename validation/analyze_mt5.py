"""
Analisi della validazione out-of-sample della variante C a partire dai log dell'EA (CTO_trades_<sym>_<magic>_tester.csv).

Uso:
    python analyze_mt5.py --logs "CTO_trades_*_tester.csv" --out report_validazione.md
    python analyze_mt5.py --logs ... --cost-mult 2 3 --risk-levels 0.25 1 5 25 50 --horizon-days 90

Cosa produce (markdown):
  1. metriche per strumento e di portafoglio (netto, lordo, costi separati, PF, win rate, payoff, R medio e test t,
     durata, drawdown, serie negative)
  2. stress dei costi: spread+commissioni x2 e x3, swap negativo x2 (ricalcolati trade per trade)
  3. Monte Carlo sulle sequenze dei trade (bootstrap a blocchi) in unita' R, a diversi livelli di rischio per trade:
     DD al 95/99 percentile, probabilita' di perdere il 25/50/90% del conto, caso peggiore -- sull'intero periodo e
     sull'orizzonte scelto (es. 90 giorni)
  4. esito dei criteri PRE-REGISTRATI (docs/VALIDAZIONE_2020_2026.md), senza possibilita' di modificarli qui.

I test in MT5 vanno fatti un simbolo alla volta, ciascuno con lo stesso deposito: il portafoglio e' la somma delle curve.
"""
import argparse, glob, math, sys
import numpy as np
import pandas as pd

# ---------------------------------------------------------------- criteri pre-registrati (NON modificare dopo i test)
CRITERI = {
    "sharpe_min": 0.5,          # Sharpe annuo netto del portafoglio (P&L giornaliero chiuso)
    "t_min": 2.0,               # t-statistic dell'R medio per ingresso della principale
    "n_min": 200,               # ingressi minimi per giudicare
    "pf_min": 1.15,             # profit factor netto
    "diffusione_min": 0.60,     # quota minima di strumenti con netto > 0
    "concentrazione_max": 0.40,  # quota massima del profitto da un solo strumento
}


def load(patterns):
    files = [f for p in patterns for f in glob.glob(p)]
    if not files:
        sys.exit("nessun log trovato")
    df = pd.concat([pd.read_csv(f, sep=";").assign(file=f) for f in files], ignore_index=True)
    df["time"] = pd.to_datetime(df["time"], format="%Y.%m.%d %H:%M:%S", errors="coerce")
    for c in ["volume", "price", "sl", "profit", "commission", "swap", "fee", "spread_price", "value_per_price_unit",
              "balance", "equity"]:
        df[c] = pd.to_numeric(df[c], errors="coerce").fillna(0.0)
    return df.sort_values("time")


def positions(df):
    """Una riga per posizione (ingresso): P&L netto, costi separati, rischio iniziale (1 R)."""
    rows = []
    for (sym, pid), g in df.groupby(["symbol", "position_id"]):
        ins = g[g.entry == "IN"]
        outs = g[g.entry != "IN"]
        if ins.empty or outs.empty:
            continue                       # posizione ancora aperta a fine test o log incompleto
        i0 = ins.iloc[0]
        direction = 1 if i0.type == "BUY" else -1
        vol = ins.volume.sum()
        risk = abs(i0.price - i0.sl) * vol * i0.value_per_price_unit if i0.sl > 0 else np.nan
        spread_cost = (0.5 * g.spread_price * g.volume * g.value_per_price_unit).sum()
        rows.append(dict(
            symbol=sym, position_id=pid, role=i0.role, dir=direction, t_in=i0.time, t_out=outs.time.max(),
            volume=vol, entry=i0.price, balance_in=i0.balance,
            profit=g.profit.sum(), commission=g.commission.sum(), swap=g.swap.sum(), fee=g.fee.sum(),
            spread_cost=spread_cost, risk=risk, reasons=",".join(sorted(set(outs.reason)))))
    p = pd.DataFrame(rows)
    p["net"] = p.profit + p.commission + p.swap + p.fee
    p["gross"] = p.profit + p.spread_cost               # prima di spread, commissioni, swap
    p["R"] = p.net / p.risk
    p["days"] = (p.t_out - p.t_in).dt.total_seconds() / 86400
    return p.sort_values("t_out").reset_index(drop=True)


def stress(p, cost_mult=1.0, swap_mult=1.0):
    q = p.copy()
    extra = (cost_mult - 1.0) * (q.spread_cost + q.commission.abs() + q.fee.abs())
    q["net"] = q.net - extra + (swap_mult - 1.0) * q.swap.clip(upper=0)
    q["R"] = q.net / q.risk
    return q


def max_streak(neg):
    m = c = 0
    for v in neg:
        c = c + 1 if v else 0
        m = max(m, c)
    return m


def metrics(p, deposit):
    if p.empty:
        return {}
    w, l = p[p.net > 0], p[p.net <= 0]
    eq = deposit + p.net.cumsum()
    dd = 1 - eq / np.maximum.accumulate(np.r_[deposit, eq.values])[1:]
    daily = p.set_index("t_out").net.resample("D").sum()
    days = pd.date_range(daily.index.min(), daily.index.max(), freq="B")
    daily = daily.reindex(days, fill_value=0.0)
    ret = daily / deposit
    R = p.R.dropna()
    t = R.mean() / (R.std(ddof=1) / math.sqrt(len(R))) if len(R) > 2 and R.std() > 0 else np.nan
    return dict(trade=len(p), netto=p.net.sum(), netto_pct=p.net.sum() / deposit, lordo=p.gross.sum(),
                spread=-p.spread_cost.sum(), commissioni=p.commission.sum(), swap=p.swap.sum(),
                win_rate=len(w) / len(p), pf=w.net.sum() / -l.net.sum() if l.net.sum() < 0 else np.inf,
                payoff=(w.net.mean() / -l.net.mean()) if len(w) and len(l) else np.nan,
                R_medio=R.mean(), t_R=t, durata_media_g=p.days.mean(),
                dd_max=dd.max(), serie_neg_max=max_streak((p.net <= 0).values),
                sharpe=ret.mean() / ret.std() * math.sqrt(252) if ret.std() > 0 else 0.0,
                peggior_trade_R=R.min(), rend_giornaliero_medio=ret.mean())


def block_bootstrap(R, n, n_sims, block=5, rng=None):
    rng = rng or np.random.default_rng(7)
    R = np.asarray(R)
    nb = int(math.ceil(n / block))
    starts = rng.integers(0, max(len(R) - block, 1), size=(n_sims, nb))
    idx = (starts[..., None] + np.arange(block)).reshape(n_sims, -1)[:, :n]
    return R[np.minimum(idx, len(R) - 1)]


def monte_carlo(R, n_trades, risk_levels, n_sims=10000):
    out = []
    R = np.asarray(pd.Series(R).dropna())
    if len(R) < 10 or n_trades < 1:
        return pd.DataFrame()
    seq = block_bootstrap(R, n_trades, n_sims)
    for rk in risk_levels:
        f = rk / 100.0
        eq = np.cumprod(np.maximum(1 + f * seq, 0.0), axis=1)       # rischio fisso sull'equity corrente
        peak = np.maximum.accumulate(np.concatenate([np.ones((n_sims, 1)), eq], axis=1), axis=1)[:, 1:]
        mdd = (1 - eq / peak).max(axis=1)
        fin = eq[:, -1] - 1
        out.append({"rischio/trade %": rk, "rend. mediano": np.median(fin), "rend. 5° perc.": np.percentile(fin, 5),
                    "caso peggiore (1° perc.)": np.percentile(fin, 1), "DD mediano": np.median(mdd),
                    "DD 95° perc.": np.percentile(mdd, 95), "DD 99° perc.": np.percentile(mdd, 99),
                    "P(DD>=25%)": (mdd >= 0.25).mean(), "P(DD>=50%)": (mdd >= 0.50).mean(),
                    "P(DD>=90%)": (mdd >= 0.90).mean()})
    return pd.DataFrame(out)


def fmt(df):
    return df.to_markdown(floatfmt=".4f")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs", nargs="+", required=True)
    ap.add_argument("--deposit", type=float, default=10000.0, help="deposito iniziale di OGNI test per simbolo")
    ap.add_argument("--cost-mult", type=float, nargs="+", default=[2.0, 3.0])
    ap.add_argument("--risk-levels", type=float, nargs="+", default=[0.25, 1, 5, 25, 50])
    ap.add_argument("--horizon-days", type=int, default=90)
    ap.add_argument("--split", default="2023-01-01", help="data che divide l'OOS in due meta' (stabilita')")
    ap.add_argument("--out", default="report_validazione.md")
    a = ap.parse_args()

    raw = load(a.logs)
    P = positions(raw)
    core = P[P.role == "CORE"]
    L = []
    L.append("# Report di validazione out-of-sample, variante C\n")
    L.append(f"Log: {len(set(raw.file))} file, {raw.symbol.nunique()} strumenti, periodo {P.t_in.min()} → {P.t_out.max()}, "
             f"{len(P)} posizioni chiuse ({len(core)} principale). Broker: {', '.join(sorted(set(raw.broker.astype(str))))}.\n")

    # 1. metriche
    per = {s: metrics(g, a.deposit) for s, g in P.groupby("symbol")}
    n_sym = len(per)
    port = metrics(P, a.deposit * n_sym)
    port_core = metrics(core, a.deposit * n_sym)
    L.append("## 1. Metriche per strumento (netto di tutti i costi registrati dal broker)\n")
    L.append(fmt(pd.DataFrame(per).T))
    L.append("\n### Portafoglio (somma degli strumenti, deposito totale = %.0f)\n" % (a.deposit * n_sym))
    L.append(fmt(pd.DataFrame({"tutto": port, "solo principale": port_core})))
    by_role = P.groupby("role")[["gross", "net", "commission", "swap", "spread_cost"]].sum()
    L.append("\n### Principale vs overlay vs costi\n")
    L.append(fmt(by_role))

    # 2. stress
    L.append("\n## 2. Stress dei costi\n")
    rows = {"base": port}
    for k in a.cost_mult:
        rows[f"spread+commissioni x{k:g}"] = metrics(stress(P, cost_mult=k), a.deposit * n_sym)
    rows["swap negativo x2"] = metrics(stress(P, swap_mult=2.0), a.deposit * n_sym)
    rows["tutto x2 (costi e swap)"] = metrics(stress(P, cost_mult=2.0, swap_mult=2.0), a.deposit * n_sym)
    st = pd.DataFrame(rows).T[["netto", "netto_pct", "pf", "R_medio", "t_R", "sharpe", "dd_max"]]
    L.append(fmt(st))
    per_stress = {s: metrics(stress(g, cost_mult=max(a.cost_mult)), a.deposit)["netto"] for s, g in P.groupby("symbol")}
    L.append(f"\nNetto per strumento con costi x{max(a.cost_mult):g}: " +
             ", ".join(f"{s} {v:,.0f}" for s, v in per_stress.items()))

    # 3. Monte Carlo
    span_days = max((P.t_out.max() - P.t_in.min()).days, 1)
    per_day = len(core) / span_days
    n_h = max(int(round(per_day * a.horizon_days)), 1)
    L.append("\n## 3. Monte Carlo sulle sequenze dei trade (bootstrap a blocchi di 5, 10.000 simulazioni)\n")
    L.append("Unità: R netti per ingresso della principale; il rischio per trade è applicato all'equity corrente. "
             "Con un conto da 50 € il lotto minimo corrisponde tipicamente a un rischio del 25-50% o più per trade "
             "(vedi CTO_CostReport, colonna risk_min_lot_pct_capital).\n")
    L.append(f"### Intero periodo ({len(core)} trade)\n")
    L.append(fmt(monte_carlo(core.R, len(core), a.risk_levels)))
    L.append(f"\n### Orizzonte {a.horizon_days} giorni (~{n_h} trade sull'insieme degli strumenti testati)\n")
    L.append(fmt(monte_carlo(core.R, n_h, a.risk_levels)))
    L.append(f"\nPeggior serie negativa osservata: {port_core.get('serie_neg_max')} trade; peggior trade: {port_core.get('peggior_trade_R', np.nan):.2f} R")

    # 4. criteri
    L.append("\n## 4. Criteri pre-registrati\n")
    c = CRITERI
    pos = {s: m["netto"] for s, m in per.items()}
    tot_pos = sum(v for v in pos.values() if v > 0)
    conc = max(pos.values()) / tot_pos if tot_pos > 0 else np.inf
    h1 = metrics(P[P.t_out < a.split], a.deposit * n_sym).get("netto", np.nan)
    h2 = metrics(P[P.t_out >= a.split], a.deposit * n_sym).get("netto", np.nan)
    s2 = rows[f"spread+commissioni x2"] if 2.0 in a.cost_mult else metrics(stress(P, cost_mult=2.0), a.deposit * n_sym)
    checks = [
        ("1 Sharpe netto portafoglio >= %.2f" % c["sharpe_min"], port["sharpe"], port["sharpe"] >= c["sharpe_min"]),
        ("2 R medio principale > 0 con t >= %.1f (n >= %d)" % (c["t_min"], c["n_min"]),
         f"R={port_core['R_medio']:.3f}, t={port_core['t_R']:.2f}, n={port_core['trade']}",
         port_core["R_medio"] > 0 and port_core["t_R"] >= c["t_min"] and port_core["trade"] >= c["n_min"]),
        ("4 Profit factor >= %.2f" % c["pf_min"], port["pf"], port["pf"] >= c["pf_min"]),
        ("5a Netto > 0 con spread+commissioni x2", s2["netto"], s2["netto"] > 0),
        ("5b Netto > 0 con swap negativo x2", rows["swap negativo x2"]["netto"], rows["swap negativo x2"]["netto"] > 0),
        ("6a Strumenti positivi >= %.0f%%" % (100 * c["diffusione_min"]), f"{sum(v > 0 for v in pos.values())}/{len(pos)}",
         sum(v > 0 for v in pos.values()) / len(pos) >= c["diffusione_min"]),
        ("6b Nessuno strumento > %.0f%% del profitto" % (100 * c["concentrazione_max"]), f"{conc:.0%}", conc <= c["concentrazione_max"]),
        ("7 Positivo in entrambe le metà dell'OOS (split %s)" % a.split, f"{h1:,.0f} / {h2:,.0f}", h1 > 0 and h2 > 0),
    ]
    L.append("| Criterio | Valore | Esito |\n|---|---|---|")
    for name, val, ok in checks:
        v = f"{val:.3f}" if isinstance(val, (float, np.floating)) else str(val)
        L.append(f"| {name} | {v} | {'SUPERATO' if ok else 'NON SUPERATO'} |")
    passed = all(ok for _, _, ok in checks)
    L.append(f"\n**Esito complessivo: {'SUPERATO' if passed else 'NON SUPERATO'}.** "
             "Criteri 3 (overlay), 8 (parametri vicini), 9 (DD reale vs Monte Carlo) e 10 (live vs backtest) "
             "si valutano con test separati (vedi protocollo).")
    open(a.out, "w").write("\n".join(L) + "\n")
    print("\n".join(L))


if __name__ == "__main__":
    main()
