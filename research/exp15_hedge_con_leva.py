# Idea utente: long SEMPRE aperto (1x il capitale) + short di copertura con volume MAGGIORATO (h volte il long),
# oppure raddoppiato a ogni nuova copertura finche' il prezzo non torna al massimo (escalation).
# Chiusure D1, SENZA costi ne swap (favorevole all'hedge). Capitale iniziale = valore del long all'avvio.
import pandas as pd, itertools
def d1(sym):
    df=pd.read_csv(f"data/{sym}_M15.csv.gz")
    t=[c for c in df.columns if 'time' in c.lower() or 'date' in c.lower()][0]
    df[t]=pd.to_datetime(df[t]); df=df.set_index(t)
    c=[c for c in df.columns if c.lower() in('close','c','mid_c')][0]
    return df[c].resample('1D').last().dropna()
def run(p,X,R,h,escal):
    P=p.values; p0=P[0]; cap=1.0
    peak=p0; ath=p0; sh=None; vol=0; mn=None; real=0.0; n=w=0; mult=h; peq=1.0; dd=0.0; ruin=False
    for x in P[1:]:
        eq=cap+(x-p0)/p0+real+(vol*(sh-x)/p0 if sh else 0)
        peq=max(peq,eq); dd=max(dd,1-eq/peq)
        if eq<=0:   # conto azzerato: fine della strategia
            return (x-p0)/p0, -1-(x-p0)/p0, n, w, 1.0, True
        if sh is None:
            peak=max(peak,x)
            if x>=ath: ath=x; mult=h
            if x<=peak*(1-X): sh=x; vol=mult; mn=x; n+=1
        else:
            mn=min(mn,x)
            if x>=mn*(1+R):
                r=vol*(sh-x)/p0; real+=r; w+=r>0; sh=None; peak=x
                if escal and r<0: mult*=2
    if sh: real+=vol*(sh-P[-1])/p0
    return (P[-1]-p0)/p0, real, n, w, dd, ruin
for sym in ["NAS100_USD","SPX500_USD","XAU_USD","EUR_USD"]:
    p=d1(sym)
    print(f"\n{sym} {p.index[0].date()}->{p.index[-1].date()}")
    for (X,R),h,e in itertools.product([(.05,.03),(.10,.03)],[1,2,3,5],[False,True]):
        if e and h>1: continue
        bh,s,n,w,dd,ruin=run(p,X,R,h,e)
        lab=("raddoppio a ogni copertura persa" if e else f"short {h}x il long")
        print(f"  cala {X:.0%}/rimbalzo {R:.0%}, {lab:33s}: long {bh:+.0%} short {s:+.0%} totale {bh+s:+.0%} | "
              f"coperture {n} (in utile {w}) | drawdown max {dd:.0%}{'  -> CONTO AZZERATO' if ruin else ''}")
