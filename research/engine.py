"""
Motore di backtest della strategia "Core Trend + Counter-Trend Overlay" (CTO).

Risoluzione: barre H1 (ricavate da M15).  Segnali: D1 (posizione principale) e H4 (overlay).
Esecuzione: i segnali calcolati sulla CHIUSURA di una barra vengono eseguiti all'APERTURA
della barra H1 successiva (niente look-ahead). Stop e take-profit controllati intrabar
sulle H1 high/low; se nella stessa barra sono toccati sia stop sia target si assume lo stop
(ipotesi pessimistica). Gap: se l'apertura e' gia' oltre lo stop si esegue all'apertura.

Costi contabilizzati SEPARATAMENTE per posizione principale e overlay:
  spread (meta' spread per lato), commissioni, slippage, swap (tassi storici + markup broker).
Il P&L "lordo" e' calcolato ai prezzi mid, i costi sono sottratti a parte.
"""
from dataclasses import dataclass, field, replace
import math
import numpy as np
import pandas as pd
from instruments import INSTR, swap_rates

DAY_SHIFT = pd.Timedelta(hours=2)  # giornata di trading chiusa alle 22:00 UTC


# --------------------------------------------------------------------------- dati
_cache = {}


def load_bars(sym, data_dir="data"):
    if sym in _cache:
        return _cache[sym]
    m15 = pd.read_csv(f"{data_dir}/{sym}_M15.csv.gz", parse_dates=["time"], index_col="time")
    h1 = m15.resample("1h").agg({"open": "first", "high": "max", "low": "min", "close": "last"}).dropna()
    k = h1.index + DAY_SHIFT
    dayk = k.floor("D")
    dow = dayk.dayofweek
    # sabato -> venerdi', domenica (apertura settimanale anticipata) -> lunedi'
    dayk = dayk + pd.to_timedelta(np.where(dow == 5, -1, np.where(dow == 6, 1, 0)), unit="D")
    h1["day"] = dayk
    h1["h4"] = k.floor("4h")
    d1 = h1.groupby("day").agg(open=("open", "first"), high=("high", "max"), low=("low", "min"), close=("close", "last"))
    h4 = h1.groupby("h4").agg(open=("open", "first"), high=("high", "max"), low=("low", "min"), close=("close", "last"))
    _cache[sym] = (h1, h4, d1)
    return _cache[sym]


def atr(df, n):
    pc = df["close"].shift(1)
    tr = np.maximum(df["high"] - df["low"], np.maximum((df["high"] - pc).abs(), (df["low"] - pc).abs()))
    return tr.ewm(alpha=1.0 / n, adjust=False).mean()  # ATR di Wilder


# --------------------------------------------------------------------------- parametri
@dataclass
class P:
    # ---- posizione principale (D1)
    ema_fast: int = 50
    ema_slow: int = 200
    n_entry: int = 55          # breakout Donchian D1 nella direzione del regime
    atr_d1: int = 20
    k_stop: float = 4.0        # stop iniziale = k_stop * ATR(D1)
    k_trail: float = 4.0       # chandelier: max close dall'ingresso - k_trail * ATR
    core_risk: float = 0.01    # frazione di equity persa se lo stop iniziale e' colpito
    # ---- overlay contro-trend (H4)
    ov_mode: str = "signal"    # none | signal | naive | random
    n_ov: int = 20             # breakout Donchian H4 opposto
    n_ov_exit: int = 10        # trailing Donchian H4
    atr_h4: int = 14
    k_ov_stop: float = 2.5     # stop iniziale overlay = k * ATR(H4)
    ov_filter: str = "ema"     # none | ema (EMA20/50 H4 allineate) | d1 (close < EMA20 D1)
    ov_size: str = "core_frac"  # core_frac (frazione dei lotti della principale) | risk (rischio costante)
    ov_risk: float = 0.005     # rischio per ingresso overlay (frazione equity) se ov_size = risk
    h_step: float = 0.5        # dimensione di ogni ingresso overlay (frazione della principale)
    max_ratio: float = 1.0     # overlay totale massimo (frazione della principale)
    add_R: float = 1.0         # si aggiunge solo se l'ultimo ingresso e' in profitto >= add_R * R
    tp_R: float = 2.0          # take-profit parziale a tp_R * R
    tp_frac: float = 0.5
    ov_after_core_exit: bool = True
    naive_k: float = 2.0       # modalita' naive: apre a (picco - naive_k*ATR D1)
    random_p: float = 0.02     # modalita' random: probabilita' per barra H4
    seed: int = 0
    ov_against: str = "both"    # both | short_core (solo rimbalzi contro principale short) | long_core
    edge_n: int = 0             # edge monitor: finestra ultimi N overlay (0 = off)
    edge_min: float = 0.0       # soglia di aspettativa media in R per tenere attivo l'overlay
    ov_side: str = "opposite"   # opposite | same (controllo: pyramiding nella direzione della principale)
    hedge_mode: str = "hedge"   # hedge = ticket opposti (doppio swap) | net = swap sull'esposizione netta
    virtual_core: bool = False  # True = la principale non viene contabilizzata (test overlay "stand-alone")
    # ---- gestione giornaliera / rischio
    max_hold_days: int = 0      # uscita temporale della principale dopo N chiusure D1 (0 = off)
    day_tp_atr: float = 0.0     # chiude la principale se il movimento favorevole del giorno >= k*ATR D1 (0 = off)
    daily_target: float = 0.0   # 0 = disattivato
    target_mode: str = "close_overlay"  # close_overlay | close_all | block
    daily_loss: float = 0.0     # blocco nuovi ingressi oltre questa perdita giornaliera
    halt_dd: float = 0.0        # stop operativo EA sul drawdown dal massimo (0 = off)
    max_lev_use: float = 10.0   # nozionale lordo massimo / equity
    # ---- costi (moltiplicatori per stress test)
    m_spread: float = 1.0
    m_comm: float = 1.0
    m_slip: float = 1.0
    m_swap: float = 1.0
    carry_adverse: float = 0.0  # carry annuo aggiuntivo avverso alla principale
    markup_mult: float = 1.0    # 0 = finanziamento stile futures (nessun markup)
    no_entry_hours: tuple = (21, 22)  # rollover: niente nuovi ingressi, spread massimo
    compound: bool = True
    start: str = None
    end: str = None


# --------------------------------------------------------------------------- motore
def run(sym, p: P, capital=100_000.0, keep_trades=True):
    h1, h4, d1 = load_bars(sym)
    if p.start or p.end:
        s0 = pd.Timestamp(p.start) if p.start else h1.index[0]
        s1 = pd.Timestamp(p.end) if p.end else h1.index[-1]
        # indicatori calcolati con 300 giorni di storia precedente (warm-up)
        w0 = s0 - pd.Timedelta(days=450)
        h1 = h1[(h1.index >= w0) & (h1.index <= s1)]
        h4 = h4[h4.index.isin(h1["h4"].unique())]
        d1 = d1[d1.index.isin(h1["day"].unique())]
    else:
        s0 = h1.index[0]
    spec = INSTR[sym]

    # --- indicatori D1
    dc = d1["close"]
    ema_f = dc.ewm(span=p.ema_fast, adjust=False).mean().values
    ema_s = dc.ewm(span=p.ema_slow, adjust=False).mean().values
    ema20d = dc.ewm(span=20, adjust=False).mean().values
    atrd = atr(d1, p.atr_d1).values
    dhi = d1["high"].rolling(p.n_entry).max().shift(1).values
    dlo = d1["low"].rolling(p.n_entry).min().shift(1).values
    d_close = dc.values
    d_days = d1.index
    # --- indicatori H4
    hc = h4["close"]
    atrh = atr(h4, p.atr_h4).values
    e20 = hc.ewm(span=20, adjust=False).mean().values
    e50 = hc.ewm(span=50, adjust=False).mean().values
    hlo_in = h4["low"].rolling(p.n_ov).min().shift(1).values
    hhi_in = h4["high"].rolling(p.n_ov).max().shift(1).values
    hlo_ex = h4["low"].rolling(p.n_ov_exit).min().values
    hhi_ex = h4["high"].rolling(p.n_ov_exit).max().values
    h_close = hc.values

    # --- mapping barre H1 -> chiusura D1/H4
    day = h1["day"].values
    h4k = h1["h4"].values
    n = len(h1)
    d_pos = {d: i for i, d in enumerate(d_days)}
    h_pos = {d: i for i, d in enumerate(h4.index)}
    d1_close_at = np.full(n, -1)
    h4_close_at = np.full(n, -1)
    for i in range(n - 1):
        if day[i + 1] != day[i]:
            d1_close_at[i] = d_pos[day[i]]
        if h4k[i + 1] != h4k[i]:
            h4_close_at[i] = h_pos[h4k[i]]
    O = h1["open"].values.tolist(); H = h1["high"].values.tolist()
    L = h1["low"].values.tolist(); C = h1["close"].values.tolist()
    hours = h1.index.hour.values.tolist()
    times = h1.index
    years = h1.index.year.values.tolist()
    rng = np.random.default_rng(p.seed)
    started = h1.index >= s0
    first_i = int(np.argmax(started))

    # --- stato
    cash = capital
    peak_eq = capital
    halted = False
    legs = []            # posizioni aperte
    trades = []          # posizioni chiuse
    pending = []         # ordini a mercato da eseguire all'apertura successiva
    core_peak = None
    acc = {k: 0.0 for k in ["gross_core", "gross_ov", "spread_core", "spread_ov", "comm_core", "comm_ov",
                            "slip_core", "slip_ov", "swap_core", "swap_ov"]}
    daily = []           # (giorno, equity, esposizione netta, esposizione lorda, margine)
    day_start_eq = capital
    blocked_today = False
    max_margin = 0.0
    swap_cache = {}
    day_ref_px, day_ref_time, day_atr = [0.0], [None], [0.0]

    def virtual(leg):
        return (leg["kind"] == "core" and p.virtual_core) or leg.get("shadow", False)

    leg_counter = [0]
    ov_hist = []  # R-multipli degli overlay chiusi (reali + ombra), per l'edge monitor

    def unit_cost(price, hour):
        sp = spec["spread_max"] if hour in p.no_entry_hours else spec["spread_avg"]
        return (0.5 * sp * p.m_spread, spec["slippage"] * p.m_slip, spec["comm_frac"] * price * p.m_comm)

    def book_cost(leg, units, price, hour, slip=True):
        s, sl, c = unit_cost(price, hour)
        if not slip:
            sl = 0.0
        tag = "core" if leg["kind"] == "core" else "ov"
        if virtual(leg):
            return (s + sl + c) * units if leg.get("shadow") else 0.0
        acc["spread_" + tag] += s * units
        acc["slip_" + tag] += sl * units
        acc["comm_" + tag] += c * units
        return (s + sl + c) * units

    def close_leg(leg, units, price, i, reason, slip=True):
        nonlocal cash
        units = min(units, leg["units"])
        gross = leg["dir"] * (price - leg["entry"]) * units
        cost = book_cost(leg, units, price, hours[i], slip)
        frac = units / leg["units"]
        entry_cost = leg["entry_cost"] * frac
        sw = leg["swap"] * frac
        if not virtual(leg):
            cash += gross - cost
            acc["gross_" + ("core" if leg["kind"] == "core" else "ov")] += gross
        net_ = gross - cost - entry_cost + sw
        leg["net_acc"] += net_
        final = leg["units"] - units <= 1e-9
        # R-multiplo calcolato per INGRESSO (non per record parziale): somma dei parziali / rischio iniziale
        if leg["kind"] == "ov" and final and leg["R"] > 0:
            ov_hist.append(leg["net_acc"] / (leg["units0"] * leg["R"]))
        if keep_trades and not leg.get("shadow"):
            trades.append(dict(kind=leg["kind"], dir=leg["dir"], t_in=leg["t_in"], t_out=times[i], units=units,
                               entry=leg["entry"], exit=price, stop=leg["stop"], gross=gross, cost=cost + entry_cost,
                               swap=sw, net=net_, reason=reason, notional=units * leg["entry"], R=leg["R"],
                               leg_id=leg["id"], risk0=leg["units0"] * leg["R"]))
        leg["units"] -= units
        leg["entry_cost"] -= entry_cost
        leg["swap"] -= sw

    def open_leg(kind, d, units, i, stop, R, tp=None, shadow=False):
        nonlocal cash
        price = O[i]
        leg_counter[0] += 1
        leg = dict(kind=kind, dir=d, units=units, entry=price, stop=stop, R=R, tp=tp, tp_done=False,
                   t_in=times[i], i_in=i, entry_cost=0.0, swap=0.0, shadow=shadow,
                   id=leg_counter[0], units0=units, net_acc=0.0)
        c = book_cost(leg, units, price, hours[i])
        leg["entry_cost"] = c
        if not virtual(leg):
            cash -= c
        legs.append(leg)
        return leg

    def equity(price):
        e = cash
        for lg in legs:
            if virtual(lg):
                continue
            e += lg["dir"] * (price - lg["entry"]) * lg["units"]
        return e

    def core_leg():
        for lg in legs:
            if lg["kind"] == "core":
                return lg
        return None

    for i in range(first_i, n):
        o, hi, lo, cl, hr = O[i], H[i], L[i], C[i], hours[i]
        # ---------------------------------------------------------- 1. ordini pendenti all'apertura
        # come l'EA: gli ordini da segnale sono rinviati fuori dalla finestra di rollover
        if hr in p.no_entry_hours:
            todo, pending = [], pending
        else:
            todo, pending = pending, []
        for od in todo:
            typ = od[0]
            if typ == "close":
                lg = od[1]
                if lg in legs:
                    close_leg(lg, lg["units"], o, i, od[2])
                    legs.remove(lg)
            elif typ == "open" and not halted:
                _, kind, d, units, stop_dist, tp_R = od[:6]
                shadow = od[6] if len(od) > 6 else False
                if units <= 0:
                    continue
                stop = o - d * stop_dist
                tp = (o + d * tp_R * stop_dist) if tp_R else None
                lg = open_leg(kind, d, units, i, stop, stop_dist, tp, shadow)
                if kind == "core":
                    core_peak = o

        # ---------------------------------------------------------- 2. stop / take-profit intrabar
        for lg in list(legs):
            d = lg["dir"]
            hit_stop = (lo <= lg["stop"]) if d > 0 else (hi >= lg["stop"])
            if hit_stop:
                fill = min(o, lg["stop"]) if d > 0 else max(o, lg["stop"])
                close_leg(lg, lg["units"], fill, i, "stop")
                legs.remove(lg)
                continue
            if lg["tp"] is not None and not lg["tp_done"]:
                hit_tp = (hi >= lg["tp"]) if d > 0 else (lo <= lg["tp"])
                if hit_tp:
                    fill = max(o, lg["tp"]) if d > 0 else min(o, lg["tp"])
                    close_leg(lg, lg["units"] * p.tp_frac, fill, i, "tp", slip=False)
                    lg["tp_done"] = True
        cl_core = core_leg()
        if cl_core is None and not p.ov_after_core_exit:
            for lg in list(legs):
                if lg["kind"] == "ov":
                    pending.append(("close", lg, "core_exit"))

        # ---------------------------------------------------------- 3. chiusura barra
        eq = equity(cl)
        if eq > peak_eq:
            peak_eq = eq
        if p.halt_dd and not halted and eq < peak_eq * (1 - p.halt_dd):
            halted = True
            for lg in legs:
                pending.append(("close", lg, "halt"))
        # target / perdita giornaliera
        if not blocked_today and day_start_eq > 0:
            r_day = eq / day_start_eq - 1
            if p.daily_target and r_day >= p.daily_target:
                blocked_today = True
                if p.target_mode in ("close_overlay", "close_all"):
                    for lg in legs:
                        if lg["kind"] == "ov" or p.target_mode == "close_all":
                            pending.append(("close", lg, "daily_target"))
            if p.daily_loss and r_day <= -p.daily_loss:
                blocked_today = True
        can_enter = (not halted) and (not blocked_today)
        if p.day_tp_atr and not blocked_today:
            cr = core_leg()
            if cr is not None and day_atr[0] > 0:
                ref = cr["entry"] if (day_ref_time[0] is None or cr["t_in"] >= day_ref_time[0]) else day_ref_px[0]
                if cr["dir"] * (cl - ref) >= p.day_tp_atr * day_atr[0]:
                    blocked_today = True
                    can_enter = False
                    for lg in legs:
                        pending.append(("close", lg, "day_tp_atr"))

        # ---------------------------------------------------------- 3a. logica D1 (principale)
        k = d1_close_at[i]
        if k >= 0 and not math.isnan(ema_s[k]) and not math.isnan(atrd[k]):
            core = core_leg()
            a = atrd[k]
            regime = 1 if (ema_f[k] > ema_s[k] and d_close[k] > ema_s[k]) else (-1 if (ema_f[k] < ema_s[k] and d_close[k] < ema_s[k]) else 0)
            if core is not None:
                d = core["dir"]
                core_peak = max(core_peak, d_close[k]) if d > 0 else min(core_peak, d_close[k])
                trail = core_peak - d * p.k_trail * a
                core["stop"] = max(core["stop"], trail) if d > 0 else min(core["stop"], trail)
                if (d > 0 and ema_f[k] < ema_s[k]) or (d < 0 and ema_f[k] > ema_s[k]):
                    pending.append(("close", core, "regime"))
            elif can_enter and regime != 0 and not any(od[0] == "open" and od[1] == "core" for od in pending):
                brk = (regime > 0 and d_close[k] > dhi[k]) or (regime < 0 and d_close[k] < dlo[k])
                if brk:
                    base = eq if p.compound else capital
                    stop_dist = p.k_stop * a
                    units = base * p.core_risk / stop_dist
                    units = min(units, base * p.max_lev_use / d_close[k] / (1 + p.max_ratio))
                    # un nuovo ciclo chiude eventuali overlay residui del ciclo precedente
                    for lg in legs:
                        if lg["kind"] == "ov":
                            pending.append(("close", lg, "new_core"))
                    pending.append(("open", "core", regime, units, stop_dist, None))

            # swap notturno (giorni di calendario fino alla prossima giornata di trading)
            nxt = day[i + 1] if i + 1 < n else day[i]
            nights = max(1, int((pd.Timestamp(nxt) - pd.Timestamp(day[i])).days))
            y = years[i]
            if y not in swap_cache:
                swap_cache[y] = swap_rates(sym, min(max(y, 2005), 2020), p.markup_mult)
            sl_, ss_ = swap_cache[y]
            def _rate(d):
                r_ = sl_ if d > 0 else ss_
                return r_ * (p.m_swap if r_ < 0 else 1.0)
            if p.hedge_mode == "net" and not p.virtual_core:
                # conto netting: lo swap si paga solo sull'esposizione netta
                cr = core_leg()
                netu = sum(lg["dir"] * lg["units"] for lg in legs if not lg.get("shadow"))
                if netu != 0:
                    d = 1 if netu > 0 else -1
                    rate = _rate(d) - (p.carry_adverse if (cr is not None and d == cr["dir"]) else 0.0)
                    amt = abs(netu) * cl * rate * nights / 365.0
                    cash += amt
                    acc["swap_core"] += amt
            else:
                for lg in legs:
                    rate = _rate(lg["dir"])
                    if lg["kind"] == "core":
                        rate -= p.carry_adverse
                    amt = lg["units"] * cl * rate * nights / 365.0
                    lg["swap"] += amt
                    if virtual(lg):
                        continue
                    cash += amt
                    acc["swap_core" if lg["kind"] == "core" else "swap_ov"] += amt
            # registrazione giornaliera
            eq = equity(cl)
            net_units = sum(lg["dir"] * lg["units"] for lg in legs if not virtual(lg))
            gross_units = sum(lg["units"] for lg in legs if not virtual(lg))
            margin = gross_units * cl / spec["lev"]
            max_margin = max(max_margin, margin / eq if eq > 0 else 0)
            daily.append((day[i], eq, net_units * cl / eq if eq > 0 else 0, gross_units * cl / eq if eq > 0 else 0,
                          margin / eq if eq > 0 else 0))
            day_start_eq = eq
            blocked_today = False
            day_ref_px[0] = cl
            day_ref_time[0] = times[i]
            day_atr[0] = atrd[k] if not math.isnan(atrd[k]) else 0.0
            cr_ = core_leg()
            if p.max_hold_days and cr_ is not None:
                cr_["held"] = cr_.get("held", 0) + 1
                if cr_["held"] >= p.max_hold_days:
                    pending.append(("close", cr_, "time"))
            if eq <= 0:
                break

        # ---------------------------------------------------------- 3b. logica H4 (overlay)
        j = h4_close_at[i]
        if j >= 0 and not math.isnan(atrh[j]) and p.ov_mode != "none":
            core = core_leg()
            ovs = [lg for lg in legs if lg["kind"] == "ov"]
            # trailing Donchian degli overlay aperti
            for lg in ovs:
                if lg["dir"] < 0:
                    lg["stop"] = min(lg["stop"], hhi_ex[j])
                else:
                    lg["stop"] = max(lg["stop"], hlo_ex[j])
            core_closing = core is not None and any(od[0] == "close" and od[1] is core for od in pending)
            dir_ok = core is not None and (p.ov_against == "both" or (p.ov_against == "short_core" and core["dir"] < 0)
                                           or (p.ov_against == "long_core" and core["dir"] > 0))
            if core is not None and dir_ok and not core_closing and can_enter:
                D = core["dir"]
                od_ = -D if p.ov_side == "opposite" else D
                ov_units = sum(lg["units"] for lg in ovs)
                room = p.max_ratio * core["units"] - ov_units
                if p.ov_size == "risk":
                    base_eq = equity(cl) if p.compound else capital
                    step = base_eq * p.ov_risk / max(p.k_ov_stop * atrh[j], 1e-12)
                else:
                    step = p.h_step * core["units"]
                if room > 1e-9:
                    step = min(step, room)
                    brk = (od_ < 0 and h_close[j] < hlo_in[j]) or (od_ > 0 and h_close[j] > hhi_in[j])
                    if p.ov_filter == "ema":
                        filt = (e20[j] < e50[j]) if od_ < 0 else (e20[j] > e50[j])
                    elif p.ov_filter == "d1":
                        kk = d_pos.get(day[i], None)
                        kk = (kk - 1) if kk else None
                        filt = kk is not None and ((h_close[j] < ema20d[kk]) if od_ < 0 else (h_close[j] > ema20d[kk]))
                    else:
                        filt = True
                    if not ovs:
                        if p.ov_mode == "signal":
                            go = brk and filt
                        elif p.ov_mode == "naive":
                            go = (D > 0 and h_close[j] <= core_peak - p.naive_k * atrd[max(0, d_pos[day[i]] - 1)]) or \
                                 (D < 0 and h_close[j] >= core_peak + p.naive_k * atrd[max(0, d_pos[day[i]] - 1)])
                        else:
                            go = rng.random() < p.random_p
                    else:
                        last = ovs[-1]
                        in_profit = od_ * (h_close[j] - last["entry"]) >= p.add_R * last["R"]
                        if p.ov_mode == "signal":
                            go = in_profit and brk
                        elif p.ov_mode == "naive":
                            go = in_profit
                        else:
                            go = in_profit and rng.random() < p.random_p * 5
                    if go:
                        shadow = False
                        if p.edge_n and len(ov_hist) >= p.edge_n:
                            shadow = float(np.mean(ov_hist[-p.edge_n:])) <= p.edge_min
                        if ovs and ovs[-1].get("shadow") != shadow:
                            shadow = ovs[-1].get("shadow")  # le aggiunte seguono lo stato del primo ingresso
                        pending.append(("open", "ov", od_, step, p.k_ov_stop * atrh[j], p.tp_R, shadow))

    # chiusura forzata a fine test (valutazione a mercato)
    last_i = n - 1
    for lg in list(legs):
        close_leg(lg, lg["units"], C[last_i], last_i, "end", slip=False)
    legs.clear()

    dd = pd.DataFrame(daily, columns=["day", "equity", "net_exp", "gross_exp", "margin"]).set_index("day")
    dd = dd[dd.index >= pd.Timestamp(s0).floor("D")]
    tr = pd.DataFrame(trades)
    if len(tr):
        tr = tr[tr["t_out"] >= s0]
    return dict(sym=sym, p=p, capital=capital, daily=dd, trades=tr, acc=acc, max_margin=max_margin,
                final_cash=cash, halted=halted)


# --------------------------------------------------------------------------- statistiche
def stats(res, label=None):
    dd = res["daily"]
    tr = res["trades"]
    if len(tr) and res["p"].virtual_core:
        tr = tr[tr["kind"] == "ov"]
    acc = res["acc"]
    cap0 = dd["equity"].iloc[0] if len(dd) else res["capital"]
    eq = dd["equity"]
    ret = eq.pct_change().dropna()
    net = eq.iloc[-1] - cap0
    costs_core = acc["spread_core"] + acc["comm_core"] + acc["slip_core"]
    costs_ov = acc["spread_ov"] + acc["comm_ov"] + acc["slip_ov"]
    gross = acc["gross_core"] + acc["gross_ov"]
    peak = eq.cummax()
    ddser = 1 - eq / peak
    years = max((eq.index[-1] - eq.index[0]).days / 365.25, 1e-9)
    cagr = (eq.iloc[-1] / cap0) ** (1 / years) - 1 if eq.iloc[-1] > 0 else -1
    monthly = eq.resample("ME").last().pct_change().dropna()
    # episodi di drawdown
    ep, cur = [], 0.0
    for v in ddser.values:
        if v > 0:
            cur = max(cur, v)
        elif cur > 0:
            ep.append(cur); cur = 0.0
    if cur > 0:
        ep.append(cur)
    out = dict(label=label or res["sym"])
    if len(tr):
        w = tr[tr["net"] > 0]; l_ = tr[tr["net"] <= 0]
        pf = w["net"].sum() / -l_["net"].sum() if len(l_) and l_["net"].sum() < 0 else np.inf
        dur = (tr["t_out"] - tr["t_in"]).dt.total_seconds() / 86400
        core_tr = tr[tr["kind"] == "core"]; ov_tr = tr[tr["kind"] == "ov"]
        out.update(n_trades=len(tr), n_core=len(core_tr), n_ov=len(ov_tr), win_rate=len(w) / len(tr), pf=pf,
                   payoff=(w["net"].mean() / -l_["net"].mean()) if len(w) and len(l_) else np.nan,
                   dur_core_d=((core_tr["t_out"] - core_tr["t_in"]).dt.total_seconds() / 86400).mean() if len(core_tr) else np.nan,
                   dur_ov_d=((ov_tr["t_out"] - ov_tr["t_in"]).dt.total_seconds() / 86400).mean() if len(ov_tr) else np.nan,
                   wr_ov=(ov_tr["net"] > 0).mean() if len(ov_tr) else np.nan)
    out.update(
        net_profit=net, net_pct=net / cap0,
        gross_profit=gross,
        gross_core=acc["gross_core"], gross_ov=acc["gross_ov"],
        costs_exec=costs_core + costs_ov, costs_core=costs_core, costs_ov=costs_ov,
        spread=acc["spread_core"] + acc["spread_ov"], comm=acc["comm_core"] + acc["comm_ov"],
        slip=acc["slip_core"] + acc["slip_ov"],
        swap=acc["swap_core"] + acc["swap_ov"], swap_core=acc["swap_core"], swap_ov=acc["swap_ov"],
        net_core=acc["gross_core"] - costs_core + acc["swap_core"],
        net_ov=acc["gross_ov"] - costs_ov + acc["swap_ov"],
        gross_to_cost=gross / max(costs_core + costs_ov - min(acc["swap_core"] + acc["swap_ov"], 0), 1e-9),
        daily_mean=ret.mean(), daily_med=ret.median(), monthly_mean=monthly.mean() if len(monthly) else np.nan,
        cagr=cagr, pos_days=(ret > 0).mean(), active_pos_days=(ret[ret != 0] > 0).mean() if (ret != 0).any() else np.nan,
        sharpe=ret.mean() / ret.std() * np.sqrt(252) if ret.std() > 0 else 0,
        max_dd=ddser.max(), avg_dd=np.mean(ep) if ep else 0.0,
        recovery=net / (ddser.max() * peak.max()) if ddser.max() > 0 else np.inf,
        mar=cagr / ddser.max() if ddser.max() > 0 else np.inf,
        exp_net_avg=dd["net_exp"].abs().mean(), exp_gross_avg=dd["gross_exp"].mean(),
        exp_gross_max=dd["gross_exp"].max(), margin_max=dd["margin"].max(), margin_avg=dd["margin"].mean(),
        best_day=ret.max(), worst_day=ret.min(), years=years,
        halted=res["halted"],
    )
    return out
