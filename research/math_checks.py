"""
Verifiche matematiche indipendenti dai dati di mercato.

1. 10% giornaliero: quale Sharpe e quale volatilita' servono (Kelly / crescita geometrica).
2. Hedge sullo stesso simbolo = riduzione dell'esposizione netta (identita' contabile) + costi extra.
3. Hedge "meccanico" (a distanza fissa) su un random walk: aspettativa nulla prima dei costi.
4. Target giornaliero come regola di stop: non crea aspettativa (optional stopping),
   ma tronca la coda destra di una strategia trend-following.
5. Martingala / averaging: probabilita' di rovina.

Esegui:  python math_checks.py  > results/math_checks.txt
"""
import numpy as np

rng = np.random.default_rng(42)
TD = 252  # giorni di trading/anno


def section(t):
    print("\n" + "=" * 78 + "\n" + t + "\n" + "=" * 78)


# ---------------------------------------------------------------------------
section("1. Il 10% giornaliero: aritmetica della capitalizzazione")
for days, label in [(1, "1 giorno"), (5, "1 settimana"), (21, "1 mese"), (63, "3 mesi"), (252, "1 anno")]:
    print(f"  {label:12s}: capitale x {1.10 ** days:,.2f}")
print("  => 10.000 EUR dopo 1 anno a +10%/giorno = {:,.0f} EUR".format(10_000 * 1.10 ** 252))

section("1b. Crescita geometrica massima (criterio di Kelly)")
print("  Per una strategia con Sharpe giornaliero S_d, la crescita log massima")
print("  (leva di Kelly piena) e' g* = S_d^2 / 2 per giorno.")
print("  Per avere g* = ln(1.10) = 9.53%/giorno serve S_d = sqrt(2*0.0953).")
Sd_req = np.sqrt(2 * np.log(1.10))
print(f"  S_d richiesto = {Sd_req:.3f}  -> Sharpe annuo = {Sd_req * np.sqrt(TD):.1f}")
print("  Riferimenti: trend-following diversificato ~0.5-1.0; ottime strategie retail ~1-2;")
print("  market making HFT con infrastruttura co-locata: >5.")
print()
print(f"  {'Sharpe annuo':>12s} {'g* giorn. (Kelly)':>18s} {'g* annua':>12s} {'1/2 Kelly giorn.':>17s} {'vol giorn. Kelly':>17s}")
for Sa in [0.5, 1.0, 1.5, 2.0, 3.0, 7.1]:
    Sd = Sa / np.sqrt(TD)
    g = Sd ** 2 / 2
    g_half = 0.75 * g  # mezza Kelly ottiene 3/4 della crescita
    print(f"  {Sa:12.1f} {100*(np.exp(g)-1):17.3f}% {100*(np.exp(g*TD)-1):11.0f}% {100*(np.exp(g_half)-1):16.3f}% {100*Sd:16.2f}%")
print("  (vol giornaliera a Kelly pieno = S_d: con Sharpe 1 e' ~6.3% al giorno -> DD enormi)")

section("1c. Cosa succede se si forza la leva per mirare al 10%/giorno")
print("  Strategia con Sharpe annuo 1.5 (gia' ottima). Si sceglie la leva L in modo che")
print("  il rendimento ARITMETICO medio giornaliero sia 10%. Simulazione 1 anno, 20.000 percorsi.")
Sa = 1.5
Sd = Sa / np.sqrt(TD)
mu = 0.10
sigma = mu / Sd  # vol giornaliera necessaria
n_paths = 20_000
r = rng.normal(mu, sigma, size=(n_paths, TD))
r = np.maximum(r, -1.0)  # non si puo' perdere piu' del 100%
eq = np.cumprod(1 + r, axis=1)
ruin = (eq.min(axis=1) < 0.01).mean()
print(f"  vol giornaliera necessaria: {100*sigma:.0f}%  (crescita log attesa = mu - sigma^2/2 = {mu - sigma**2/2:.2f}/giorno)")
print(f"  probabilita' di perdere >99% entro 1 anno: {100*ruin:.1f}%")
print(f"  mediana capitale finale: x{np.median(eq[:, -1]):.2e}")
print()
print("  Stessa strategia a leve diverse (rendimento/DD a 1 anno, 20.000 percorsi):")
print(f"  {'vol giorn.':>10s} {'rend.medio giorn.':>18s} {'mediana annuo':>14s} {'DD mediano':>11s} {'P(DD>50%)':>10s} {'P(rovina)':>10s}")
for vol in [0.005, 0.01, 0.02, 0.04, 0.063, 0.10, 0.20]:
    m = Sd * vol
    rr = np.maximum(rng.normal(m, vol, size=(n_paths, TD)), -1)
    e = np.cumprod(1 + rr, axis=1)
    peak = np.maximum.accumulate(np.concatenate([np.ones((n_paths, 1)), e], axis=1), axis=1)[:, 1:]
    dd = 1 - e / peak
    mdd = dd.max(axis=1)
    print(f"  {100*vol:9.1f}% {100*m:17.3f}% {100*(np.median(e[:,-1])-1):13.1f}% {100*np.median(mdd):10.1f}% {100*(mdd>0.5).mean():9.1f}% {100*(e.min(axis=1)<0.05).mean():9.1f}%")

# ---------------------------------------------------------------------------
section("2. Hedge sullo stesso simbolo = esposizione netta (identita')")
print("  P&L(long L lotti) + P&L(short H lotti) = (L - H) * dP   per QUALSIASI percorso di prezzo.")
print("  Differenze reali tra 'hedge' e 'ridurre la posizione':")
print("   - costi di esecuzione: identici per round-trip (apri+chiudi l'hedge = chiudi+riapri la quota);")
print("   - swap: con l'hedge si pagano DUE swap su H lotti: swap_long + swap_short.")
print("     Il differenziale di tasso si annulla, resta 2 x markup del broker (sempre negativo);")
print("   - margine: dipende dal broker (hedged margin 0-100%).")
print("  Esempio numerico, markup tipico 2.5%/anno per lato su un nozionale di 100.000:")
for days in [5, 20, 60, 120]:
    print(f"    hedge tenuto {days:3d} giorni -> costo swap extra ~ {100_000*0.025*2*days/365:,.0f} (vs 0 riducendo)")

# ---------------------------------------------------------------------------
section("3. Hedge meccanico su random walk: aspettativa zero prima dei costi")
print("  Long 1 lotto; quando il prezzo scende di X apri short h lotti; chiudi lo short se torna a +X")
print("  o se scende di ulteriori 2X (take profit). Prezzo = random walk senza drift.")
n_paths, n_steps = 3_000, 2_000
steps = rng.choice([-1.0, 1.0], size=(n_paths, n_steps))
P = np.concatenate([np.zeros((n_paths, 1)), np.cumsum(steps, axis=1)], axis=1)
for X, TPm, h in [(10, 2, 1.0), (20, 1, 0.5), (15, 3, 1.0)]:
    pnl_hedge = np.zeros(n_paths)
    n_trades = np.zeros(n_paths)
    for i in range(n_paths):
        p = P[i]
        open_px = None
        ref = 0.0
        for t in range(1, n_steps + 1):
            if open_px is None and p[t] <= ref - X:
                open_px = p[t]
            elif open_px is not None:
                if p[t] >= open_px + X or p[t] <= open_px - TPm * X:
                    pnl_hedge[i] += h * (open_px - p[t])
                    n_trades[i] += 1
                    ref = p[t]
                    open_px = None
        if open_px is not None:
            pnl_hedge[i] += h * (open_px - p[-1])
    se = pnl_hedge.std() / np.sqrt(n_paths)
    print(f"  X={X:3d} TP={TPm}X h={h:.1f}: P&L medio hedge = {pnl_hedge.mean():+.3f} +/- {1.96*se:.3f} tick,"
          f" trade medi {n_trades.mean():.1f}; con costo 0.5 tick/trade -> {pnl_hedge.mean()-0.5*h*n_trades.mean():+.2f}")
print("  => senza un segnale con potere predittivo l'hedge non produce profitto: produce solo costi.")

# ---------------------------------------------------------------------------
section("4. Target giornaliero: optional stopping")
print("  Strategia con rendimento giornaliero intraday ~ random walk con piccolo drift positivo.")
print("  Confronto: nessun target vs 'chiudi tutto al +T%' vs 'chiudi al +T% o al -T%'.")
n_days, n_int = 50_000, 96  # 96 intervalli da 15 min
drift, vol = 0.0005 / n_int, 0.01 / np.sqrt(n_int)
inc = rng.normal(drift, vol, size=(n_days, n_int))
path = np.cumsum(inc, axis=1)
final = path[:, -1]
for T in [0.005, 0.01, 0.02]:
    hit = (path >= T)
    first = np.where(hit.any(axis=1), hit.argmax(axis=1), -1)
    res = np.where(first >= 0, path[np.arange(n_days), np.maximum(first, 0)], final)
    print(f"  T={100*T:.1f}%: media senza target {100*final.mean():+.4f}%  con target {100*res.mean():+.4f}%"
          f"  | % giorni positivi {100*(final>0).mean():.1f}% -> {100*(res>0).mean():.1f}%"
          f"  | giorno migliore {100*final.max():.2f}% -> {100*res.max():.2f}%")
print("  => il target alza la % di giorni positivi ma NON aumenta l'aspettativa;")
print("     su una strategia con drift positivo la riduce leggermente (si tagliano i giorni migliori).")
print("  Per il trend-following, che guadagna soprattutto nella coda destra, il taglio e' piu' costoso")
print("  (verificato sui dati reali in backtest.py, test 'daily target').")

# ---------------------------------------------------------------------------
section("5. Martingala/averaging (per confronto, NON usata)")
print("  Raddoppio dopo ogni perdita, prob. perdita singola 0.5, capitale = 1023 unita' (10 raddoppi).")
for p_loss in [0.5, 0.55]:
    ruin_per_cycle = p_loss ** 10
    for cycles in [100, 500, 1000]:
        print(f"   p_loss={p_loss}: P(rovina) entro {cycles:4d} cicli = {100*(1-(1-ruin_per_cycle)**cycles):5.1f}%"
              f"  (guadagno se sopravvive: {cycles} unita')")
