"""
Esperimento 12: e' possibile RADDOPPIARE 50 EUR in pochi mesi con un EA?

Dati EURUSD M15 2005-2020, una partenza all'inizio di ogni mese, orizzonte 3 e 6 mesi.
Metodi:
  M1 bold play ESMA (leva 1:30): una posizione 0,01 lotti (il massimo consentito dal margine) nella
     direzione del trend D1 (EMA50/EMA200), tenuta fino a raddoppio (100 EUR) o stop-out (livello di margine 50%)
  M2 come M1 ma direzione opposta al trend (serve a vedere se il trend aiuta; la media M1/M2 = direzione casuale)
  M3 bold play leva 1:500 (broker non UE): 0,05 lotti nella direzione del trend
  M4 griglia martingala leva 1:500 (tipico EA "raddoppia conto"): 0,01 lotti nel trend, raddoppio del lotto
     ogni 20 pip contro, chiusura del cesto a +1 USD, ripartenza, fino a raddoppio o stop-out
  (con leva 1:30 la martingala non e' eseguibile: il secondo livello richiede 117 USD di margine su 58,5)
  M5 variante C al lotto minimo (Monte Carlo sugli R per ingresso EURUSD della ricerca)
Costi: ECN 1,1 pip A+C (conto UE), standard 1,5 pip (conto 1:500); swap storico con markup (instruments.py).
Conto in EUR: 50 EUR = 58,5 USD (EURUSD 1,17); obiettivo 117 USD.
"""
import warnings; warnings.filterwarnings("ignore")
import numpy as np, pandas as pd
from dataclasses import replace
from engine import load_bars, run, P
from instruments import swap_rates

EURUSD = 1.17
EQ0, TARGET = 50 * EURUSD, 100 * EURUSD
PIP = 0.0001

m15 = pd.read_csv("data/EUR_USD_M15.csv.gz", parse_dates=["time"], index_col="time")
T = m15.index; O = m15.open.values; H = m15.high.values; L = m15.low.values; C = m15.close.values
DAY = ((T + pd.Timedelta(hours=2)).floor("D")).values.astype("datetime64[D]").astype(np.int64)
YEAR = T.year.values
h1, h4, d1 = load_bars("EUR_USD")
ema50 = d1.close.ewm(span=50, adjust=False).mean(); ema200 = d1.close.ewm(span=200, adjust=False).mean()
reg_d = np.sign(ema50 - ema200)
dkeys = d1.index.values.astype("datetime64[D]").astype(np.int64)
pos = np.searchsorted(dkeys, DAY, side="left") - 1          # ultimo giorno COMPLETATO
REG = np.where(pos >= 0, reg_d.values[np.clip(pos, 0, None)], 0).astype(int)
REG[REG == 0] = 1
SW = {y: swap_rates("EUR_USD", min(max(y, 2005), 2020)) for y in range(2005, 2021)}


def swap_night(i, lots, d):
    sl, ss = SW[YEAR[i]]
    return lots * 1e5 * C[max(i - 1, 0)] * (sl if d > 0 else ss) / 365.0


def bold(s, e3, e6, d, lots, lev, cost_pips):
    units = lots * 1e5
    entry = O[s]
    fixed = -cost_pips * lots * 10
    sw = 0.0
    last = DAY[s]
    out3 = None
    for i in range(s, e6):
        if DAY[i] != last:
            sw += swap_night(i, lots, d) * (DAY[i] - last); last = DAY[i]
        adv = L[i] if d > 0 else H[i]
        fav = H[i] if d > 0 else L[i]
        eq_adv = EQ0 + fixed + sw + d * (adv - entry) * units
        lvl = 0.5 * units * adv / lev
        if eq_adv <= lvl:
            eq_open = EQ0 + fixed + sw + d * (O[i] - entry) * units
            res = ("rovina", max(min(lvl, eq_open), 0.0), i)
            return res, (out3 or res)
        if EQ0 + fixed + sw + d * (fav - entry) * units >= TARGET:
            res = ("raddoppio", TARGET, i)
            return res, (out3 or res)
        if i == e3 - 1 and out3 is None:
            out3 = ("in corso", EQ0 + fixed + sw + d * (C[i] - entry) * units, i)
    res = ("in corso", EQ0 + fixed + sw + d * (C[e6 - 1] - entry) * units, e6 - 1)
    return res, (out3 or res)


def grid(s, e3, e6, lev=500, base=0.01, mult=2.0, step=20, tp=1.0, cost_pips=1.5):
    cash = EQ0
    basket = []          # (entry, lots)
    d = REG[s]
    last = DAY[s]
    out3 = None
    for i in range(s, e6):
        if not basket:
            d = REG[i]
            basket = [(O[i], base)]
            cash -= cost_pips * base * 10
        if DAY[i] != last:
            cash += sum(swap_night(i, lt, d) for _, lt in basket) * (DAY[i] - last); last = DAY[i]
        adv = L[i] if d > 0 else H[i]
        # nuovi livelli attraversati nella barra (prezzo contro)
        while True:
            e_last, l_last = basket[-1]
            nxt = e_last - d * step * PIP
            if (d > 0 and adv > nxt) or (d < 0 and adv < nxt):
                break
            nl = round(l_last * mult, 2)
            fl = sum(d * (nxt - e) * lt * 1e5 for e, lt in basket)
            used = sum(lt * 1e5 * nxt / lev for _, lt in basket)
            if cash + fl - used < nl * 1e5 * nxt / lev:
                break                                   # margine insufficiente: niente nuovo livello
            basket.append((nxt, nl))
            cash -= cost_pips * nl * 10
        fl_adv = sum(d * (adv - e) * lt * 1e5 for e, lt in basket)
        margin = sum(lt * 1e5 * adv / lev for _, lt in basket)
        if cash + fl_adv <= 0.5 * margin:
            res = ("rovina", max(cash + fl_adv, 0.0), i)
            return res, (out3 or res)
        fl_c = sum(d * (C[i] - e) * lt * 1e5 for e, lt in basket)
        if fl_c >= tp:
            cash += fl_c
            basket = []
            if cash >= TARGET:
                res = ("raddoppio", cash, i)
                return res, (out3 or res)
        if i == e3 - 1 and out3 is None:
            out3 = ("in corso", cash + fl_c, i)
    fl_c = sum(d * (C[e6 - 1] - e) * lt * 1e5 for e, lt in basket)
    res = ("in corso", cash + fl_c, e6 - 1)
    return res, (out3 or res)


# partenze: primo bar di ogni mese 2006-01 .. 2019-11
starts = []
for ym in pd.period_range("2006-01", "2019-11", freq="M"):
    t0 = ym.start_time
    s = int(np.searchsorted(T.values, np.datetime64(t0)))
    e3 = int(np.searchsorted(T.values, np.datetime64(t0 + pd.DateOffset(months=3))))
    e6 = int(np.searchsorted(T.values, np.datetime64(t0 + pd.DateOffset(months=6))))
    if e6 < len(T):
        starts.append((s, e3, e6))

rows = []
for name, fn in [
    ("M1 ESMA 1:30, 0,01 lotti, nel trend", lambda s, e3, e6: bold(s, e3, e6, REG[s], 0.01, 30, 1.1)),
    ("M2 ESMA 1:30, 0,01 lotti, contro il trend", lambda s, e3, e6: bold(s, e3, e6, -REG[s], 0.01, 30, 1.1)),
    ("M3 leva 1:500, 0,05 lotti, nel trend", lambda s, e3, e6: bold(s, e3, e6, REG[s], 0.05, 500, 1.5)),
    ("M4 martingala 1:500 (griglia 20 pip, lotto x2)", lambda s, e3, e6: grid(s, e3, e6)),
]:
    r6, r3 = zip(*[fn(*x) for x in starts])
    for hz, rr in [("3 mesi", r3), ("6 mesi", r6)]:
        out = pd.DataFrame(rr, columns=["esito", "eq", "i"])
        eq_eur = out["eq"] / EURUSD
        days = [(T[i] - T[s]).days for (s, _, _), i in zip(starts, out.i)]
        rows.append(dict(metodo=name, orizzonte=hz, P_raddoppio=(out.esito == "raddoppio").mean(),
                         P_rovina=(out.esito == "rovina").mean(), P_in_corso=(out.esito == "in corso").mean(),
                         capitale_finale_medio=eq_eur.mean(), capitale_finale_mediano=eq_eur.median(),
                         P_sotto_25=(eq_eur < 25).mean(),
                         giorni_mediani_al_raddoppio=np.median([dd for dd, x in zip(days, out.esito) if x == "raddoppio"]) if (out.esito == "raddoppio").any() else np.nan))

# M5: variante C al lotto minimo (R per ingresso EURUSD della ricerca), stessi orizzonti
C5 = replace(P(), n_ov=120, n_ov_exit=60, k_ov_stop=4.0, ov_against="short_core", hedge_mode="net", edge_n=20, day_tp_atr=0.5)
tr = run("EUR_USD", C5)["trades"]; tr = tr[tr.kind == "core"]
g = tr.groupby("leg_id").agg(net=("net", "sum"), risk=("risk0", "first"), t=("t_out", "max"))
R = (g.net / g.risk).values
per_month = len(R) / ((g.t.max() - g.t.min()).days / 30.44)
rng = np.random.default_rng(5)
risk_eur, block_eur = 26.2, 33.3 * 1.1
for hz, m in [("3 mesi", 3), ("6 mesi", 6)]:
    fin = []
    for _ in range(20000):
        eq = 50.0
        for _ in range(rng.poisson(per_month * m)):
            if eq < block_eur or eq >= 100:
                break
            eq += rng.choice(R) * risk_eur
        fin.append(eq)
    fin = np.array(fin)
    rows.append(dict(metodo="M5 variante C, 0,01 lotti (ESMA)", orizzonte=hz, P_raddoppio=(fin >= 100).mean(),
                     P_rovina=(fin < block_eur).mean(), P_in_corso=((fin >= block_eur) & (fin < 100)).mean(),
                     capitale_finale_medio=fin.mean(), capitale_finale_mediano=np.median(fin), P_sotto_25=(fin < 25).mean(),
                     giorni_mediani_al_raddoppio=np.nan))
df = pd.DataFrame(rows)
pd.set_option("display.width", 250)
print(f"Partenze: {len(starts)} (una al mese, 2006-2019)\n")
print(df.to_string(float_format=lambda x: f"{x:,.3f}"))
df.to_csv("results/exp12_double_50.csv", index=False)
