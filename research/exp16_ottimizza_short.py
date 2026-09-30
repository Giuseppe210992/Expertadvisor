# "Se regoli bene ingressi e uscite dello short risolvi": ottimizzo ingresso (calo X%), uscita (rimbalzo R%)
# e moltiplicatore h sul 2005-2012, poi applico la combinazione MIGLIORE, senza cambiarla, al 2013-2020.
# Long sempre aperto 1x, chiusure D1, senza costi ne swap (favorevole all'idea).
import itertools
from exp15_hedge_con_leva import d1, run
Xs=[.02,.03,.04,.05,.06,.07,.08,.10,.12,.15]; Rs=[.01,.02,.03,.04,.05,.07,.10]; Hs=[1,2,3,5]
for sym in ["NAS100_USD","SPX500_USD","XAU_USD","EUR_USD"]:
    p=d1(sym); IS=p[:"2012"]; OOS=p["2013":]
    res=[]
    for X,R,h in itertools.product(Xs,Rs,Hs):
        bh,s,n,w,dd,ru=run(IS,X,R,h,False)
        res.append((s,X,R,h,dd,ru,n))
    res.sort(reverse=True)
    s,X,R,h,dd,ru,n=res[0]
    pos=sum(1 for r in res if r[0]>0)
    bho,so,no,wo,ddo,ruo=run(OOS,X,R,h,False)
    print(f"{sym}: {len(res)} combinazioni provate sul 2005-2012, {pos} con coperture in utile")
    print(f"   migliore 2005-2012: calo {X:.0%}, rimbalzo {R:.0%}, short {h}x -> coperture {s:+.0%}, DD {dd:.0%}")
    print(f"   stessa regola 2013-2020:                          -> coperture {so:+.0%}, DD {ddo:.0%}{'  CONTO AZZERATO' if ruo else ''}"
          f"  (solo long {bho:+.0%}, totale {bho+so:+.0%})")
