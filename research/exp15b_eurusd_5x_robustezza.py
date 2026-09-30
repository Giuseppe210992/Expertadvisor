# Robustezza del caso "EURUSD, short 5x": sotto-periodi, griglia di parametri, serie invertita.
import itertools, pandas as pd
from exp15_hedge_con_leva import d1, run
p=d1("EUR_USD")
print("EURUSD short 5x, calo 5% / rimbalzo 3%, per sotto-periodo (ogni periodo riparte da capitale 1):")
for a,b in [("2005","2008-07"),("2008-07","2012"),("2012","2016"),("2016","2020-06"),("2005","2012"),("2013","2020-06")]:
    q=p[a:b]; bh,s,n,w,dd,ru=run(q,.05,.03,5,False)
    print(f"  {a}->{b}: EURUSD {q.iloc[0]:.3f}->{q.iloc[-1]:.3f} ({bh:+.0%})  totale {bh+s:+.0%}  DD max {dd:.0%}{'  CONTO AZZERATO' if ru else ''}")
print("\nGriglia completa short 5x, 2005-2020 (calo X / rimbalzo R):")
for X,R in itertools.product([.03,.05,.07,.10],[.02,.03,.05]):
    bh,s,n,w,dd,ru=run(p,X,R,5,False)
    print(f"  X={X:.0%} R={R:.0%}: totale {bh+s:+.0%}  DD max {dd:.0%}{'  CONTO AZZERATO' if ru else ''}")
