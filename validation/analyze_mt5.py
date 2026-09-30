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
from risk_curve import curve as risk_curve, to_markdown as risk_curve_md

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
              "balance", "equity", "slippage_price"]:
        if c not in df:
            df[c] = 0.0                    # log di versioni precedenti dell'EA
        df[c] = pd.to_numeric(df[c], errors="coerce").fillna(0.0)
    return df.sort_values("time")


# categorie dei codici evento scritti dall'EA (CTO/EventLog.mqh)
EVENT_CAT = {
    "NO_SIGNAL": "normale", "SIGNAL": "normale", "TRADE_OPENED": "eseguito", "SHADOW_OPENED": "normale (edge monitor)",
    "DAYTP_NO_REENTRY": "normale (regola C)", "SIGNAL_EXPIRED": "segnale perso",
    "RISK_TOO_HIGH": "CAPITALE", "MARGIN_TOO_HIGH": "CAPITALE/LEVA", "LEVERAGE_LIMIT": "CAPITALE/LEVA",
    "LOT_BELOW_MINIMUM": "GRANULARITA'", "HEAT_LIMIT": "RISCHIO", "RISK_REJECTED": "RISCHIO",
    "ENTRIES_BLOCKED": "RISCHIO (limiti giornalieri)", "MINLOT_OVERRIDE": "ESPERIMENTO (rischio oltre il previsto)",
    "SPREAD_TOO_HIGH": "filtro costo (rinvio)", "ROLLOVER_BLOCKED": "filtro operativo (rinvio)",
    "TRADING_DISABLED": "operativo (rinvio)", "ORDER_FAILED": "operativo (rinvio)",
}
# codici che rendono NON valido il test principale di un simbolo (problemi di capitale, non di strategia)
CAPITAL_CODES = {"RISK_TOO_HIGH", "MARGIN_TOO_HIGH", "LEVERAGE_LIMIT", "LOT_BELOW_MINIMUM", "HEAT_LIMIT", "MINLOT_OVERRIDE"}


def load_events(patterns):
    files = [f for p in patterns for f in glob.glob(p)]
    if not files:
        return pd.DataFrame()
    ev = pd.concat([pd.read_csv(f, sep=";") for f in files], ignore_index=True)
    ev["time"] = pd.to_datetime(ev["time"], format="%Y.%m.%d %H:%M:%S", errors="coerce")
    return ev


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
        slip_cost = (g.slippage_price * g.volume * g.value_per_price_unit).sum()   # > 0 = sfavorevole
        rows.append(dict(
            symbol=sym, position_id=pid, role=i0.role, dir=direction, t_in=i0.time, t_out=outs.time.max(),
            volume=vol, entry=i0.price, balance_in=i0.balance,
            profit=g.profit.sum(), commission=g.commission.sum(), swap=g.swap.sum(), fee=g.fee.sum(),
            spread_cost=spread_cost, slip_cost=slip_cost, risk=risk, reasons=",".join(sorted(set(outs.reason)))))
    p = pd.DataFrame(rows)
    p["net"] = p.profit + p.commission + p.swap + p.fee
    p["gross"] = p.profit + p.spread_cost + p.slip_cost  # prima di spread, slippage, commissioni, swap
    p["R"] = p.net / p.risk
    p["days"] = (p.t_out - p.t_in).dt.total_seconds() / 86400
    return p.sort_values("t_out").reset_index(drop=True)


def stress(p, cost_mult=1.0, swap_mult=1.0):
    q = p.copy()
    extra = (cost_mult - 1.0) * (q.spread_cost + q.slip_cost.clip(lower=0) + q.commission.abs() + q.fee.abs())
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
    return dict(trade=len(p), lordo=p.gross.sum(), spread=-p.spread_cost.sum(), slippage=-p.slip_cost.sum(),
                commissioni=p.commission.sum() + p.fee.sum(), swap=p.swap.sum(), netto=p.net.sum(),
                netto_pct=p.net.sum() / deposit, expectancy=p.net.mean(), peggior_trade=p.net.min(),
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


def max_risk_for_dd(R, n_trades, max_dd, pct=99, n_sims=4000):
    """Massimo rischio per trade (%) tale che il DD al percentile 'pct' resti <= max_dd (bisezione)."""
    R = np.asarray(pd.Series(R).dropna())
    if len(R) < 10 or n_trades < 1:
        return np.nan, np.nan
    seq = block_bootstrap(R, n_trades, n_sims, rng=np.random.default_rng(11))
    def stats_at(f):
        eq = np.cumprod(np.maximum(1 + f * seq, 0.0), axis=1)
        peak = np.maximum.accumulate(np.concatenate([np.ones((n_sims, 1)), eq], axis=1), axis=1)[:, 1:]
        return np.percentile((1 - eq / peak).max(axis=1), pct), np.median(eq[:, -1] - 1)
    lo, hi = 0.0, 1.0
    for _ in range(30):
        mid = (lo + hi) / 2
        if stats_at(mid)[0] <= max_dd:
            lo = mid
        else:
            hi = mid
    return 100 * lo, stats_at(lo)[1]


# ---------------------------------------------------------------- regola pre-registrata per la scelta del rischio
RISK_RULE = {
    "edge_fraction": 0.5,        # si assume un edge pari al 50% di quello misurato fuori campione
    "p5_12m_min": -0.20,         # 5° percentile del rendimento a 12 mesi >= -20%
    "p_dd50_12m_max": 0.01,      # P(drawdown massimo >= 50% entro 12 mesi) < 1% (lettura piu' severa di "perdita >= 50%")
    "grid": [0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4, 5, 7.5, 10, 15, 20],
    # prerequisito: l'edge dell'insieme considerato deve superare il criterio 2 (altrimenti rischio ammesso = 0)
    "t_min": 2.0,
    "n_min": 200,
    # vincolo di contemporaneita': rischio per trade <= heat massimo dell'EA / posizioni simultanee massime osservate
    "heat_max": 6.0,
}


def max_concurrent(trades):
    """Numero massimo di posizioni aperte contemporaneamente (principale), dai tempi di apertura/chiusura."""
    ev = [(t, 1) for t in trades.t_in] + [(t, -1) for t in trades.t_out]
    ev.sort(key=lambda x: (x[0], x[1]))
    cur = best = 0
    for _, d in ev:
        cur += d
        best = max(best, cur)
    return best


def pre_registered_risk(trades):
    """Applica la regola congelata. Ritorna (tabella, rischio scelto in %, R medio misurato, R medio ipotizzato, Kelly diagnostico)."""
    t = trades[["t_out", "R"]].dropna()
    m = t.R.mean()
    n = len(t)
    tstat = m / (t.R.std(ddof=1) / math.sqrt(n)) if n > 2 and t.R.std() > 0 else np.nan
    if not np.isfinite(m) or m <= 0 or n < RISK_RULE["n_min"] or not (tstat >= RISK_RULE["t_min"]):
        return pd.DataFrame({"motivo": [f"edge non dimostrato: R medio {m:+.4f}, t = {tstat:.2f}, n = {n} "
                                        f"(servono t >= {RISK_RULE['t_min']:g} e n >= {RISK_RULE['n_min']})"]}), 0.0, m, np.nan, 0.0
    R = t.R - (1 - RISK_RULE["edge_fraction"]) * m             # edge ridotto al 50%
    tt = pd.DataFrame({"t_out": t.t_out, "R": R})
    tab = risk_curve(tt, risks=RISK_RULE["grid"], horizons=[12])
    tab = tab[tab.orizzonte == "12 mesi"].copy()
    tab["5° perc. rendimento 12m"] = tab["5° perc. (x)"] - 1
    tab["ammesso"] = (tab["5° perc. rendimento 12m"] >= RISK_RULE["p5_12m_min"]) & (tab["P(DD>=50%)"] < RISK_RULE["p_dd50_12m_max"])
    ok = tab[tab.ammesso]
    # si prende il massimo rischio ammesso tale che anche TUTTI i rischi inferiori siano ammessi (niente "isole")
    chosen = 0.0
    for _, r in tab.sort_values("rischio/trade %").iterrows():
        if not r.ammesso:
            break
        chosen = r["rischio/trade %"]
    kelly = R.mean() / (R ** 2).mean()
    return tab, chosen, m, R.mean(), kelly


def to_md_rule(tab):
    t = tab[["rischio/trade %", "rend. annuo mediano", "5° perc. rendimento 12m", "P(DD>=50%)", "ammesso"]].copy()
    for c in ["rend. annuo mediano", "5° perc. rendimento 12m", "P(DD>=50%)"]:
        t[c] = t[c].map(lambda v: f"{v:.1%}")
    return t.to_markdown(index=False)


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
    ap.add_argument("--start", default=None, help="considera solo le posizioni aperte da questa data (warm-up escluso)")
    ap.add_argument("--end", default=None)
    ap.add_argument("--max-dd", type=float, nargs="+", default=[0.10, 0.20, 0.30],
                    help="drawdown tollerati per il calcolo del rischio massimo per trade (99° percentile)")
    ap.add_argument("--expected", nargs="*", default=[], help="simboli attesi: segnala quelli senza trade")
    ap.add_argument("--events", nargs="*", default=None,
                    help="log eventi dell'EA (default: stessi file dei --logs con 'trades' -> 'events')")
    ap.add_argument("--risk-curve", type=float, nargs="+", default=[0.25, 0.5, 1, 2, 5, 10, 20, 50],
                    help="rischi per trade (%%) della curva rischio -> rendimento -> rovina (bootstrap a blocchi di mesi)")
    ap.add_argument("--out", default="report_validazione.md")
    a = ap.parse_args()

    raw = load(a.logs)
    P = positions(raw)
    if a.start:
        P = P[P.t_in >= pd.Timestamp(a.start)].reset_index(drop=True)
    if a.end:
        P = P[P.t_in <= pd.Timestamp(a.end)].reset_index(drop=True)
    if P.empty:
        sys.exit("nessuna posizione chiusa nel periodo: controllare il journal ('ingresso saltato' = deposito troppo piccolo)")
    core = P[P.role == "CORE"]
    L = []
    L.append("# Report di validazione out-of-sample, variante C\n")
    L.append(f"Log: {len(set(raw.file))} file, {raw.symbol.nunique()} strumenti, periodo {P.t_in.min()} → {P.t_out.max()}, "
             f"{len(P)} posizioni chiuse ({len(core)} principale). Broker: {', '.join(sorted(set(raw.broker.astype(str))))}.\n")

    missing = [x for x in a.expected if x not in set(P.symbol)]
    if missing:
        L.append(f"**ATTENZIONE: nessun trade su {', '.join(missing)}.** Se nel journal compare 'ingresso saltato', il deposito "
                 "del test è troppo piccolo per il lotto minimo: il test di quel simbolo non è valido.\n")
    # 1. metriche
    per = {s: metrics(g, a.deposit) for s, g in P.groupby("symbol")}
    n_sym = len(per)
    port = metrics(P, a.deposit * n_sym)
    port_core = metrics(core, a.deposit * n_sym)
    L.append("## 1. Metriche per strumento (netto di tutti i costi registrati dal broker)\n")
    L.append(fmt(pd.DataFrame(per).T))
    L.append("\n### Portafoglio (somma degli strumenti, deposito totale = %.0f)\n" % (a.deposit * n_sym))
    L.append(fmt(pd.DataFrame({"tutto": port, "solo principale": port_core})))
    L.append("\n### Risultato netto per anno\n")
    yr = P.assign(anno=P.t_out.dt.year).pivot_table(index="anno", columns="symbol", values="net", aggfunc="sum", fill_value=0.0)
    yr["PORTAFOGLIO"] = yr.sum(axis=1)
    yr["PORTAFOGLIO %"] = yr["PORTAFOGLIO"] / (a.deposit * n_sym)
    L.append(fmt(yr))
    by_role = P.groupby("role")[["gross", "spread_cost", "slip_cost", "commission", "swap", "net"]].sum()
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
    L.append("\n### Rischio massimo per trade compatibile con un drawdown tollerato (99° percentile, intero periodo)\n")
    L.append("È la risposta alla domanda \"massima efficienza\": il rendimento si alza solo alzando il rischio, e il limite "
             "lo fissa il caso peggiore, non la media.\n")
    L.append("| DD tollerato (99° perc.) | Rischio max per trade | Rendimento mediano sul periodo |\n|---|---|---|")
    for md in a.max_dd:
        rk, med = max_risk_for_dd(core.R, len(core), md)
        L.append(f"| {md:.0%} | {rk:.2f}% | {med:+.1%} |")
    L.append(f"\nPeggior serie negativa osservata: {port_core.get('serie_neg_max')} trade; peggior trade: {port_core.get('peggior_trade_R', np.nan):.2f} R")

    # 3a. curva rischio -> rendimento -> rovina (strategia invariata, cambia solo il rischio per trade)
    L.append("\n## 3a. Curva rischio → rendimento → rovina (bootstrap a blocchi di 3 mesi, 3/6/12 mesi e intero periodo)\n")
    L.append("Trade trattati in sequenza per data di chiusura: ai rischi alti la perdita simultanea di più posizioni è "
             "sottostimata. Rovina = perdita del 90% in un qualsiasi momento.\n")
    L.append(risk_curve_md(risk_curve(P[["t_out", "R"]].dropna(), risks=a.risk_curve)))

    # 3a-bis. regola pre-registrata di scelta del rischio
    L.append("\n## 3c. Rischio per trade secondo la regola pre-registrata\n")
    L.append("Regola (docs/VALIDAZIONE_2020_2026.md, sezione 6b). Prerequisito: l'edge dell'insieme considerato supera il "
             "criterio 2 (R medio > 0, t >= 2, almeno 200 ingressi), altrimenti il rischio ammesso è 0. Poi: con un edge pari al 50% di quello misurato qui, il massimo "
             "rischio per trade tale che il 5° percentile del rendimento a 12 mesi sia >= -20% e la probabilità di un drawdown "
             ">= 50% entro 12 mesi sia < 1%, con tutti i rischi inferiori anch'essi ammessi.\n")
    for lab, sub in [("portafoglio (tutti i simboli dei log)", P)] + [(f"solo {s_}", g_) for s_, g_ in P.groupby("symbol")]:
        tab, chosen, m_meas, m_used, kelly = pre_registered_risk(sub)
        if "motivo" in tab:
            L.append(f"- **{lab}**: **rischio ammesso 0** ({tab.motivo.iloc[0]}).")
            continue
        top = chosen >= max(RISK_RULE["grid"])
        conc = max_concurrent(sub[sub.role == "CORE"]) if "role" in sub else 1
        cap = RISK_RULE["heat_max"] / max(conc, 1)
        final = min(chosen, cap)
        L.append(f"- **{lab}**: R medio misurato {m_meas:+.4f}, ipotizzato {m_used:+.4f} → curva: {chosen:g}% per trade; "
                 f"posizioni simultanee massime {conc} → limite di heat {RISK_RULE['heat_max']:g}%/{conc} = {cap:.2f}% → "
                 f"**rischio ammesso {final:.2f}% per trade**. "
                 f"Kelly con l'edge ipotizzato: {100 * kelly:.1f}% (solo diagnostico, **non** è un parametro operativo)."
                 + (" ATTENZIONE: raggiunto il massimo della griglia, il limite reale non è stato trovato." if top else ""))
        if lab.startswith("portafoglio"):
            L.append("\n" + to_md_rule(tab) + "\n")

    # 3b. motivi degli ingressi (eventi)
    ev_pat = a.events if a.events is not None else [x.replace("CTO_trades_", "CTO_events_") for x in a.logs]
    EV = load_events(ev_pat)
    cap_bad = pd.DataFrame()
    if not EV.empty:
        if a.start:
            EV = EV[EV.time >= pd.Timestamp(a.start)]
        if a.end:
            EV = EV[EV.time <= pd.Timestamp(a.end) + pd.Timedelta(days=1)]
        L.append("\n## 3b. Motivi di ingressi eseguiti, rinviati e saltati\n")
        cnt = EV.pivot_table(index=["code"], columns="symbol", values="time", aggfunc="count", fill_value=0)
        cnt.insert(0, "categoria", [EVENT_CAT.get(c, "?") for c in cnt.index])
        L.append(fmt(cnt))
        cap_bad = EV[EV.code.isin(CAPITAL_CODES)]
        exp = EV[EV.code == "SIGNAL_EXPIRED"]
        if len(exp):
            L.append("\nSegnali scaduti senza esecuzione (con l'ultimo motivo di rinvio):\n")
            L.append(fmt(exp.groupby(["symbol", "role", "detail"]).size().rename("n").to_frame()))
        if len(cap_bad):
            L.append("\n**Ingressi saltati o alterati per CAPITALE/MARGINE/GRANULARITA'**: il test principale dei simboli "
                     "seguenti non misura la strategia al rischio previsto e va ripetuto con un deposito più alto:\n")
            L.append(fmt(cap_bad.groupby(["symbol", "role", "code"]).size().rename("n").to_frame()))
    else:
        L.append("\n## 3b. Motivi degli ingressi\n\nNessun log eventi trovato (EA precedente alla versione con EventLog).")

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
        ("0 Validità del test: nessun ingresso saltato/alterato per capitale, margine o granularità",
         "nessuno" if cap_bad.empty else f"{len(cap_bad)} eventi su {cap_bad.symbol.nunique()} simboli", cap_bad.empty),
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
