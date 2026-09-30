# Idea utente: "aperture e chiusure rapide e frequentissime, piccoli importi".
# Scalping su barre M15 2005-2020: ingresso all'apertura di ogni barra (dopo la chiusura del trade precedente),
# take profit = stop loss = k pip. Tre regole di direzione: casuale, momentum (come la barra precedente),
# contrarian (opposta). Se TP e SL cadono nella stessa barra il trade vale 0 (ne' vinto ne' perso).
# Costo: spread medio misurato su TenTrade (CTO_CostReport) + 0,2 pip di slippage.
import numpy as np, pandas as pd
rng=np.random.default_rng(1)
def load(sym):
    df=pd.read_csv(f"data/{sym}_M15.csv.gz",parse_dates=["time"])
    df=df[df.time.dt.hour.between(7,20)]         # solo ore liquide (spread normale)
    return df.open.values,df.high.values,df.low.values,df.close.values
def sim(o,h,l,c,k,rule):
    i=1;n=len(o);res=[]
    while i<n-1:
        d = rng.choice([-1,1]) if rule=="casuale" else (np.sign(c[i-1]-o[i-1]) or 1)*(1 if rule=="momentum" else -1)
        e=o[i];tp=e+d*k;sl=e-d*k;j=i;r=None
        while j<n and j<i+400:
            hit_tp = h[j]>=tp if d>0 else l[j]<=tp
            hit_sl = l[j]<=sl if d>0 else h[j]>=sl
            if hit_tp and hit_sl: r=0.0;break
            if hit_tp: r=1.0;break
            if hit_sl: r=-1.0;break
            j+=1
        if r is None: r=d*(c[min(j,n-1)]-e)/k
        res.append(r); i=j+1
    return np.array(res)
for sym,pip,spread in [("EUR_USD",1e-4,1.12),("XAU_USD",0.1,3.14)]:
    o,h,l,c=load(sym); cost=(spread+0.2)*pip
    print(f"\n{sym}: costo per trade {spread+0.2:.2f} pip (spread TenTrade {spread} + slippage 0,2)")
    for kp in [3,5,10,20]:
        k=kp*pip
        for rule in ["casuale","momentum","contrarian"]:
            r=sim(o,h,l,c,k,rule); g=r.mean(); net=g-cost/k
            print(f"  TP=SL={kp:>2} pip {rule:10s}: trade {len(r):>6}  vinti {np.mean(r>0):.1%}  "
                  f"lordo {g:+.3f} R/trade  costo {cost/k:.3f} R  NETTO {net:+.3f} R/trade  -> su 1000 trade {net*1000:+.0f} R")
