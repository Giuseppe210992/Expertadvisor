"""
Esperimento 5 (finale): portafoglio 12 strumenti, variante ORIGINALE vs PROPOSTA.
Sezioni: A scomposizione e metriche | B test statistici e ipotesi nulla | C livelli di rischio / 10%
         D stress costi | E regimi di mercato | F target giornaliero | G walk-forward | H Monte Carlo
"""
import itertools, json, warnings
warnings.filterwarnings('ignore')
from multiprocessing import Pool
from scipy import stats as st
from exp_common import *

d1ov = dict(n_ov=120, n_ov_exit=60, k_ov_stop=4.0)
ORIG = P()                                                                    # idea originale (overlay H4, hedge)
PROP = replace(P(), **d1ov, ov_against="short_core", hedge_mode="net", edge_n=20)  # variante proposta
CORE = replace(P(), ov_mode="none", hedge_mode="net")

def run_all(p, label, syms=SYMS):
    with Pool(4) as pool:
        return pool.map(_run1, [(s, p, label) for s in syms])

def _run1(a):
    s, p, lab = a
    r = run(s, p)
    return dict(sym=s, label=lab, stats=stats(r, lab), daily=r["daily"], trades=r["trades"], acc=r["acc"])

def portfolio(results):
    eq = pd.concat({r["sym"]: r["daily"]["equity"] for r in results}, axis=1).sort_index().ffill()
    eq = eq.fillna(100_000.0)
    tot = eq.sum(axis=1)
    return tot

def pstats(tot, results=None):
    ret = tot.pct_change().dropna()
    peak = tot.cummax(); dd = 1 - tot / peak
    yrs = (tot.index[-1] - tot.index[0]).days / 365.25
    cagr = (tot.iloc[-1] / tot.iloc[0]) ** (1 / yrs) - 1 if tot.iloc[-1] > 0 else -1
    m = tot.resample("ME").last().pct_change().dropna()
    out = dict(net_pct=tot.iloc[-1] / tot.iloc[0] - 1, cagr=cagr, daily_mean=ret.mean(), monthly_mean=m.mean(),
               sharpe=ret.mean() / ret.std() * np.sqrt(252) if ret.std() > 0 else 0, max_dd=dd.max(),
               avg_dd=dd[dd > 0].mean() if (dd > 0).any() else 0, pos_days=(ret > 0).mean(),
               best_day=ret.max(), worst_day=ret.min(), mar=cagr / dd.max() if dd.max() > 0 else np.nan,
               pos_months=(m > 0).mean())
    if results:
        acc = pd.DataFrame([r["acc"] for r in results]).sum()
        tr = pd.concat([r["trades"] for r in results if len(r["trades"])])
        w = tr[tr.net > 0]; l = tr[tr.net <= 0]
        out.update(gross_core=acc.gross_core, gross_ov=acc.gross_ov,
                   exec_core=acc.spread_core + acc.comm_core + acc.slip_core,
                   exec_ov=acc.spread_ov + acc.comm_ov + acc.slip_ov,
                   spread=acc.spread_core + acc.spread_ov, comm=acc.comm_core + acc.comm_ov, slip=acc.slip_core + acc.slip_ov,
                   swap_core=acc.swap_core, swap_ov=acc.swap_ov,
                   n_trades=len(tr), n_core=(tr.kind == "core").sum(), n_ov=(tr.kind == "ov").sum(),
                   win_rate=len(w) / len(tr), pf=w.net.sum() / -l.net.sum(), payoff=w.net.mean() / -l.net.mean(),
                   recovery=(tot.iloc[-1] - tot.iloc[0]) / ((1 - tot / tot.cummax()) * tot.cummax()).max())
        out["net_core"] = out["gross_core"] - out["exec_core"] + out["swap_core"]
        out["net_ov"] = out["gross_ov"] - out["exec_ov"] + out["swap_ov"]
        out["gross_to_cost"] = (out["gross_core"] + out["gross_ov"]) / (out["exec_core"] + out["exec_ov"] - min(out["swap_core"] + out["swap_ov"], 0))
    return out

def show(d):
    return "\n".join(f"  {k:16s} {v:>14,.4f}" if isinstance(v, (float, np.floating)) else f"  {k:16s} {v!s:>14}" for k, v in d.items())

if __name__ == "__main__":
    OUT = {}
    # ------------------------------------------------------------------ A
    print("=" * 100 + "\nA. SCOMPOSIZIONE E METRICHE DI PORTAFOGLIO (12 x 100k, rischio 1% per sleeve, 2005-2020.05)\n" + "=" * 100)
    RES = {}
    for lab, p in [("CORE_ONLY", CORE), ("ORIGINALE", ORIG), ("PROPOSTA", PROP)]:
        RES[lab] = run_all(p, lab)
        tot = portfolio(RES[lab])
        ps = pstats(tot, RES[lab])
        OUT[lab] = ps
        tot.to_csv(f"results/equity_{lab}.csv")
        print(f"\n--- {lab}\n" + show(ps))
        rows = pd.DataFrame([r["stats"] for r in RES[lab]])
        rows.to_csv(f"results/per_instrument_{lab}.csv", index=False)
    print("\n--- Metriche per strumento, variante PROPOSTA")
    rows = pd.DataFrame([r["stats"] for r in RES["PROPOSTA"]])
    print(rows[["label", "net_pct", "cagr", "max_dd", "sharpe", "pf", "win_rate", "payoff", "net_core", "net_ov",
                "costs_exec", "swap", "n_core", "n_ov", "dur_core_d", "dur_ov_d", "exp_gross_avg", "margin_max"]]
          .assign(label=[r["sym"] for r in RES["PROPOSTA"]]).to_string(float_format=lambda x: f"{x:,.3f}"))

    # ------------------------------------------------------------------ B
    print("\n" + "=" * 100 + "\nB. TEST STATISTICI: gli overlay hanno un vantaggio proprio?\n" + "=" * 100)
    for lab in ["ORIGINALE", "PROPOSTA", "CORE_ONLY"]:
        tr = pd.concat([r["trades"].assign(sym=r["sym"]) for r in RES[lab] if len(r["trades"])])
        for kind in ["core", "ov"]:
            t_ = tr[tr.kind == kind]
            g_ = t_.groupby(["sym", "leg_id"]).agg(net=("net", "sum"), risk0=("risk0", "first"))
            x = g_["net"] / g_["risk0"]
            if len(x) > 2:
                t, pv = st.ttest_1samp(x, 0)
                print(f"  {lab:10s} {kind:4s}: n={len(x):5d}  media R netto={x.mean():+.3f}  t={t:+.2f}  p={pv:.3f}")
    # ipotesi nulla: stesso motore, ingressi overlay casuali (50 semi)
    print("\n  Ipotesi nulla: overlay H4 con ingressi CASUALI (stessi stop/uscite), 30 semi")
    orig_ov = sum(r["stats"]["net_ov"] for r in RES["ORIGINALE"])
    jobs = [(s, replace(ORIG, ov_mode="random", random_p=0.02, seed=k, virtual_core=True), f"rnd{k}") for k in range(30) for s in SYMS]
    rnd = batch(jobs)
    dist = rnd.groupby("label")["net_ov"].sum()
    ntr = rnd.groupby("label")["n_ov"].sum().mean()
    print(f"  overlay reale (ORIGINALE, virtual core) netto = {orig_ov:,.0f}  | casuale: media {dist.mean():,.0f}, "
          f"dev.std {dist.std():,.0f}, n trade medi {ntr:.0f}; percentile del reale = {(dist < orig_ov).mean()*100:.0f}%")
    OUT["null"] = dict(real=orig_ov, rnd_mean=dist.mean(), rnd_std=dist.std(), pct=(dist < orig_ov).mean())

    # ------------------------------------------------------------------ C
    print("\n" + "=" * 100 + "\nC. LIVELLI DI RISCHIO E TARGET 10% GIORNALIERO (variante PROPOSTA)\n" + "=" * 100)
    print("  rischio/trade per sleeve -> equivalente sul capitale totale = rischio/12 per posizione")
    rows = []
    for rk in [0.01, 0.02, 0.04, 0.08, 0.16, 0.32]:
        res = run_all(replace(PROP, core_risk=rk, max_lev_use=30.0), f"r{rk}")
        tot = portfolio(res); ps = pstats(tot)
        ps["risk_sleeve"] = rk
        ps["max_gross_lev"] = max(r["stats"]["exp_gross_max"] for r in res)
        ps["max_margin"] = max(r["stats"]["margin_max"] for r in res)
        rows.append(ps)
        tot.to_csv(f"results/equity_risk_{rk}.csv")
    rk = pd.DataFrame(rows).set_index("risk_sleeve")
    print(rk[["daily_mean", "monthly_mean", "cagr", "max_dd", "avg_dd", "sharpe", "worst_day", "best_day", "pos_days",
              "max_gross_lev", "max_margin"]].to_string(float_format=lambda x: f"{x:,.4f}"))
    rk.to_csv("results/risk_levels.csv")
    # giorni con >= 10% su singolo sleeve a rischio massimo
    OUT["risk"] = rk.to_dict()

    # ------------------------------------------------------------------ D
    print("\n" + "=" * 100 + "\nD. STRESS TEST DEI COSTI (netto di portafoglio, % sul capitale 1.2M)\n" + "=" * 100)
    SC = {"base": {}, "spread x2": dict(m_spread=2), "spread x3": dict(m_spread=3), "commissioni x2": dict(m_comm=2),
          "slippage x3": dict(m_slip=3), "swap x2": dict(m_swap=2), "carry avverso +2%": dict(carry_adverse=0.02),
          "tutto peggiorato": dict(m_spread=2, m_comm=1.5, m_slip=3, m_swap=1.5, carry_adverse=0.01),
          "zero costi (solo lordo)": dict(m_spread=0, m_comm=0, m_slip=0, m_swap=0)}
    rows = []
    for name, kw in SC.items():
        for lab, p in [("ORIGINALE", ORIG), ("PROPOSTA", PROP), ("CORE_ONLY", CORE)]:
            if name == "zero costi (solo lordo)":
                p = replace(p, **kw)
                # azzera anche lo swap attivo (tassi): approssimazione con markup e tassi nulli non disponibile;
            else:
                p = replace(p, **kw)
            res = run_all(p, lab)
            ps = pstats(portfolio(res), res)
            rows.append(dict(scenario=name, variant=lab, net_pct=ps["net_pct"], cagr=ps["cagr"], max_dd=ps["max_dd"],
                             sharpe=ps["sharpe"], net_ov=ps["net_ov"]))
    sd = pd.DataFrame(rows).pivot(index="scenario", columns="variant", values=["net_pct", "sharpe", "max_dd"])
    print(sd.to_string(float_format=lambda x: f"{x:,.4f}"))
    sd.to_csv("results/stress_costs.csv")

    # ------------------------------------------------------------------ E
    print("\n" + "=" * 100 + "\nE. REGIMI DI MERCATO (P&L netto per trade, variante PROPOSTA e ORIGINALE)\n" + "=" * 100)
    for lab in ["ORIGINALE", "PROPOSTA"]:
        tr = pd.concat([r["trades"].assign(sym=r["sym"]) for r in RES[lab] if len(r["trades"])])
        tr["year"] = tr.t_out.dt.year
        print(f"\n  {lab}: netto per anno (core / overlay)")
        print(tr.pivot_table(index="year", columns="kind", values="net", aggfunc="sum").fillna(0).T.to_string(float_format=lambda x: f"{x:,.0f}"))
        tot = portfolio(RES[lab])
        for nm, a, b in [("GFC 2008-09", "2008-06-01", "2009-03-31"), ("Rally 2009-10", "2009-04-01", "2010-04-30"),
                         ("Crisi euro 2011", "2011-07-01", "2011-12-31"), ("Laterale 2012-13", "2012-01-01", "2013-12-31"),
                         ("Trend USD 2014-15", "2014-07-01", "2015-03-31"), ("Crash ago 2015", "2015-08-01", "2015-09-30"),
                         ("Q4 2018", "2018-10-01", "2018-12-31"), ("Laterale 2019", "2019-01-01", "2019-12-31"),
                         ("COVID feb-mag 2020", "2020-02-15", "2020-05-14")]:
            seg = tot[a:b]
            if len(seg) > 2:
                ddm = (1 - seg / seg.cummax()).max()
                print(f"    {nm:20s}: rendimento {seg.iloc[-1]/seg.iloc[0]-1:+.2%}  max DD {ddm:.2%}")
    # gap: stop eseguiti oltre il livello
    tr = pd.concat([r["trades"].assign(sym=r["sym"]) for r in RES["PROPOSTA"] if len(r["trades"])])
    stp = tr[tr.reason == "stop"].copy()
    stp["gap_R"] = -stp.dir * (stp.exit - stp.stop) / (stp.stop - stp.entry).abs().replace(0, np.nan)
    print(f"\n  Stop eseguiti con gap (oltre lo stop): {(stp.gap_R > 0.01).sum()} su {len(stp)}; peggior gap = {stp.gap_R.max():.2f} R")
    # serie negative consecutive
    s_ = (tr.groupby(["sym", "leg_id"]).agg(net=("net", "sum"), t=("t_out", "max")).sort_values("t").net <= 0).astype(int).values
    mx = cur = 0
    for v in s_:
        cur = cur + 1 if v else 0; mx = max(mx, cur)
    print(f"  Massima serie di trade negativi consecutivi (portafoglio): {mx}")

    # ------------------------------------------------------------------ F
    print("\n" + "=" * 100 + "\nF. TARGET GIORNALIERO (variante PROPOSTA a rischio 4%/sleeve)\n" + "=" * 100)
    rows = []
    for tgt, mode in [(0, "-"), (0.005, "close_overlay"), (0.01, "close_overlay"), (0.005, "close_all"),
                      (0.01, "close_all"), (0.02, "close_all"), (0.005, "block"), (0.01, "block")]:
        p = replace(PROP, core_risk=0.04, daily_target=tgt, target_mode=mode if tgt else "block")
        res = run_all(p, "t")
        ps = pstats(portfolio(res), res)
        rows.append(dict(target=tgt, mode=mode, net_pct=ps["net_pct"], cagr=ps["cagr"], sharpe=ps["sharpe"],
                         max_dd=ps["max_dd"], pos_days=ps["pos_days"], n_trades=ps["n_trades"]))
    print(pd.DataFrame(rows).to_string(float_format=lambda x: f"{x:,.4f}"))
    pd.DataFrame(rows).to_csv("results/daily_target.csv", index=False)

    # ------------------------------------------------------------------ G
    print("\n" + "=" * 100 + "\nG. WALK-FORWARD (IS 4 anni -> OOS 1 anno, parametri principale)\n" + "=" * 100)
    grid = list(itertools.product([40, 55, 80, 100], [3.0, 4.0, 5.0]))
    curves = {}
    for ne, kt in grid:
        res = run_all(replace(PROP, n_entry=ne, k_trail=kt), f"{ne}_{kt}")
        curves[(ne, kt)] = portfolio(res).pct_change().fillna(0)
    R = pd.DataFrame(curves)
    oos = []
    log = []
    for y in range(2009, 2021):
        ins = R[f"{y-4}-01-01":f"{y-1}-12-31"]
        score = ins.mean() / ins.std() * np.sqrt(252)
        best = score.idxmax()
        o = R.loc[f"{y}-01-01":f"{y}-12-31", best]
        oos.append(o)
        fixed = R.loc[f"{y}-01-01":f"{y}-12-31", (55, 4.0)]
        log.append(dict(year=y, best=str(best), is_sharpe=score.max(), oos_ret=(1 + o).prod() - 1, fixed_55_4=(1 + fixed).prod() - 1))
    wf = pd.DataFrame(log)
    print(wf.to_string(float_format=lambda x: f"{x:,.4f}"))
    o = pd.concat(oos)
    print(f"  WFA stitched OOS 2009-2020: rendimento {(1+o).prod()-1:+.2%}, Sharpe {o.mean()/o.std()*np.sqrt(252):.2f}"
          f" | parametri fissi 55/4: {(1+R.loc['2009':, (55,4.0)]).prod()-1:+.2%}, Sharpe {R.loc['2009':, (55,4.0)].mean()/R.loc['2009':, (55,4.0)].std()*np.sqrt(252):.2f}")
    print("  Sharpe full-period dell'intera griglia (stabilita' dei parametri):")
    print((R.mean() / R.std() * np.sqrt(252)).unstack().to_string(float_format=lambda x: f"{x:,.2f}"))
    wf.to_csv("results/walk_forward.csv", index=False)

    # ------------------------------------------------------------------ H
    print("\n" + "=" * 100 + "\nH. MONTE CARLO (ricampionamento dei trade, variante PROPOSTA, rischio 1% e 4%)\n" + "=" * 100)
    tr = pd.concat([r["trades"].assign(sym=r["sym"]) for r in RES["PROPOSTA"] if len(r["trades"])])
    g_ = tr.groupby(["sym", "leg_id"]).agg(net=("net", "sum"), risk0=("risk0", "first"), t=("t_out", "max")).sort_values("t")
    rm = (g_["net"] / g_["risk0"]).values
    rng = np.random.default_rng(1)
    n = len(rm)
    for risk_port in [0.01 / 12 * 1, 0.04 / 12, 0.02, 0.05]:
        finals, mdds = [], []
        for _ in range(5000):
            x = rng.choice(rm, n, replace=True)
            eq = np.cumprod(1 + risk_port * x)
            mdds.append((1 - eq / np.maximum.accumulate(eq)).max()); finals.append(eq[-1])
        print(f"  rischio per trade sul capitale totale {risk_port:.4%}: rend. mediano {np.median(finals)-1:+.1%}, "
              f"P(perdita) {np.mean(np.array(finals)<1):.1%}, DD mediano {np.median(mdds):.1%}, DD 95° perc. {np.percentile(mdds,95):.1%}")
    json.dump({k: {kk: (float(vv) if isinstance(vv, (int, float, np.floating, np.integer)) else str(vv)) for kk, vv in v.items()}
               for k, v in OUT.items() if k in ("CORE_ONLY", "ORIGINALE", "PROPOSTA", "null")}, open("results/summary.json", "w"), indent=1)
