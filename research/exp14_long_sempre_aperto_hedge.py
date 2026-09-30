# Idea utente: long SEMPRE aperto + short di copertura (stesso volume) quando il prezzo cala del X% dal massimo;
# lo short si chiude quando il prezzo rimbalza del R% dal minimo raggiunto. Chiusure D1, SENZA costi ne swap (favorevole all hedge).
import pandas as pd, numpy as np, itertools
def d1(sym):
    df=pd.read_csv(f"data/{sym}_M15.csv.gz")
    tcol=[c for c in df.columns if 'time' in c.lower() or 'date' in c.lower()][0]
    df[tcol]=pd.to_datetime(df[tcol]); df=df.set_index(tcol)
    c=[c for c in df.columns if c.lower() in('close','c','mid_c')][0]
    return df[c].resample('1D').last().dropna()
def run(p,X,R):
    peak=p.iloc[0]; h=None; mn=None; pnl=0; n=0; w=0
    for x in p.values[1:]:
        if h is None:
            peak=max(peak,x)
            if x<=peak*(1-X): h=x; mn=x; n+=1
        else:
            mn=min(mn,x)
            if x>=mn*(1+R):
                r=h-x; pnl+=r; w+= r>0; h=None; peak=x
    if h is not None: pnl+=h-p.values[-1]
    return pnl/p.iloc[0], n, w
for sym in ["NAS100_USD","SPX500_USD","XAU_USD","EUR_USD"]:
    try: p=d1(sym)
    except Exception as e: print(sym,e); continue
    bh=p.iloc[-1]/p.iloc[0]-1
    print(f"\n{sym} {p.index[0].date()}->{p.index[-1].date()} buy&hold {bh:+.0%}")
    for X,R in itertools.product([.03,.05,.10],[.02,.03,.05]):
        s,n,w=run(p,X,R)
        print(f"  cala {X:.0%} -> short; chiude se rimbalza {R:.0%}: short {s:+.0%} ({n} coperture, {w} in utile) totale {bh+s:+.0%}")
