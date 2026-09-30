"""Test dello script di analisi: converte i trade del backtest Python (variante C) nel formato di log dell'EA.
Uso (da research/):  python ../validation/tests/make_synthetic_logs.py OUTDIR"""
import sys, os, warnings
warnings.filterwarnings("ignore")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "research"))
import pandas as pd
from dataclasses import replace
from engine import run, P

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
C = replace(P(), n_ov=120, n_ov_exit=60, k_ov_stop=4.0, ov_against="short_core", hedge_mode="net", edge_n=20,
            day_tp_atr=0.5, start="2017-01-01", end="2020-05-14", compound=False)
for sym in ["EUR_USD", "GBP_USD", "XAU_USD", "NAS100_USD", "SPX500_USD", "WTICO_USD"]:
    r = run(sym, C, capital=10000.0)
    tr = r["trades"]
    rows, bal = [], 10000.0
    for lid, g in tr.groupby("leg_id", sort=False):
        g0 = g.iloc[0]
        units0 = g.units.sum()
        R = g0.risk0 / units0
        rows.append(dict(time=g0.t_in, symbol=sym, magic=710100, role="CORE" if g0.kind == "core" else "OVERLAY",
                         position_id=lid, entry="IN", type="BUY" if g0.dir > 0 else "SELL", volume=units0, price=g0.entry,
                         sl=g0.entry - g0.dir * R, profit=0.0, commission=0.0, swap=0.0, fee=0.0, reason="DEAL_REASON_EXPERT",
                         spread_price=0.0, value_per_price_unit=1.0, balance=bal, equity=bal, account_currency="USD",
                         broker="SINTETICO", server="test"))
        for _, x in g.iterrows():
            bal += x.net
            rows.append(dict(time=x.t_out, symbol=sym, magic=710100, role=rows[-1]["role"], position_id=lid, entry="OUT",
                             type="SELL" if x.dir > 0 else "BUY", volume=x.units, price=x.exit, sl=0.0, profit=x.gross,
                             commission=-x.cost, swap=x.swap, fee=0.0, reason=x.reason, spread_price=0.0,
                             value_per_price_unit=1.0, balance=bal, equity=bal, account_currency="USD", broker="SINTETICO",
                             server="test"))
    df = pd.DataFrame(rows).sort_values("time")
    df["time"] = pd.to_datetime(df.time).dt.strftime("%Y.%m.%d %H:%M:%S")
    df.to_csv(f"{out}/CTO_trades_{sym}_710100_tester.csv", sep=";", index=False)
    print(sym, len(df), "deal", "netto", round(tr.net.sum(), 2))
