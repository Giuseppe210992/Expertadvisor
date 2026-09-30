"""Profilo statistico degli strumenti: volatilita', persistenza dei trend, laterale, gap."""
import warnings; warnings.filterwarnings("ignore")
import numpy as np, pandas as pd
from engine import load_bars, atr
from instruments import INSTR

rows = []
for sym in INSTR:
    h1, h4, d1 = load_bars(sym)
    c = d1["close"]; r = np.log(c).diff().dropna()
    a = atr(d1, 20)
    vol_ann = r.std() * np.sqrt(252)
    # variance ratio a 20 e 60 giorni: >1 = persistenza (trend), <1 = mean reversion
    vr = {k: (np.log(c).diff(k).dropna().var() / (k * r.var())) for k in (20, 60)}
    # efficiency ratio a 60 giorni: |spostamento| / somma dei movimenti (1 = trend puro, ~0 = laterale)
    er = (c.diff(60).abs() / c.diff().abs().rolling(60).sum()).dropna()
    # gap del lunedi': apertura lunedi' vs chiusura venerdi', in ATR
    mon = d1[d1.index.dayofweek == 0]
    prev_close = c.shift(1).reindex(mon.index)
    gap = ((mon["open"] - prev_close).abs() / a.shift(1).reindex(mon.index)).dropna()
    rows.append(dict(strumento=sym, anni=round((c.index[-1] - c.index[0]).days / 365.25, 1),
                     vol_annua=f"{vol_ann:.1%}", atr_d1_pct=f"{(a / c).median():.2%}",
                     VR20=round(vr[20], 2), VR60=round(vr[60], 2),
                     ER60_medio=round(er.mean(), 2), quota_laterale=f"{(er < 0.15).mean():.0%}",
                     quota_trend=f"{(er > 0.35).mean():.0%}",
                     gap_lun_medio_ATR=round(gap.mean(), 2), gap_lun_max_ATR=round(gap.max(), 1)))
df = pd.DataFrame(rows)
md = df.to_markdown(index=False)
open("results/instrument_profile.md", "w").write(md)
print(md)
