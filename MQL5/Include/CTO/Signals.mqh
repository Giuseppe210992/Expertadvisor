//+------------------------------------------------------------------+
//|                                                  CTO/Signals.mqh |
//|   Regole di ingresso/uscita della principale e dell'overlay.     |
//|   Tutte le funzioni lavorano su barre chiuse (niente repaint).   |
//+------------------------------------------------------------------+
#ifndef CTO_SIGNALS_MQH
#define CTO_SIGNALS_MQH

#include "Defines.mqh"
#include "Indicators.mqh"

//+------------------------------------------------------------------+
//| Posizione principale: breakout di Donchian nel verso del regime  |
//+------------------------------------------------------------------+
class CCoreSignal
  {
private:
   CCtoIndicators   *m_ind;
   SCtoSettings      m_s;

public:
   void              Init(CCtoIndicators *ind, const SCtoSettings &s) { m_ind = ind; m_s = s; }

   //--- +1 apri long, -1 apri short, 0 nessun segnale (valutare alla chiusura della barra D1)
   int               EntrySignal(void) const
     {
      int reg = m_ind.Regime();
      if(reg == 0) return 0;
      double c = m_ind.CloseCore(1);
      if(reg > 0 && m_s.allowLong)
        {
         double hh = m_ind.HighestCore(m_s.donchEntry, 2);
         if(hh != EMPTY_VALUE && c > hh) return 1;
        }
      if(reg < 0 && m_s.allowShort)
        {
         double ll = m_ind.LowestCore(m_s.donchEntry, 2);
         if(ll != EMPTY_VALUE && c < ll) return -1;
        }
      return 0;
     }

   //--- trend invalidato: incrocio delle medie contro la posizione
   bool              RegimeExit(const int dir) const
     {
      double f = m_ind.EmaFast(1), s = m_ind.EmaSlow(1);
      if(f == EMPTY_VALUE || s == EMPTY_VALUE) return false;
      return (dir > 0 && f < s) || (dir < 0 && f > s);
     }

   //--- distanza dello stop iniziale (prezzo)
   double            InitialStopDistance(void) const
     {
      double a = m_ind.AtrCore(1);
      return (a == EMPTY_VALUE) ? 0.0 : m_s.kStop * a;
     }

   //--- livello chandelier: estremo delle chiusure dall'ingresso -/+ kTrail*ATR
   double            TrailLevel(const int dir, const datetime openTime, const double entry) const
     {
      double a = m_ind.AtrCore(1);
      if(a == EMPTY_VALUE) return 0.0;
      double ext = m_ind.ExtremeCloseSince(openTime, dir);
      if(ext <= 0.0) ext = entry;
      ext = (dir > 0) ? MathMax(ext, entry) : MathMin(ext, entry);
      return ext - dir * m_s.kTrail * a;
     }
  };

//+------------------------------------------------------------------+
//| Overlay: breakout contro-trend con propria logica di trade       |
//+------------------------------------------------------------------+
class COverlaySignal
  {
private:
   CCtoIndicators   *m_ind;
   SCtoSettings      m_s;

public:
   void              Init(CCtoIndicators *ind, const SCtoSettings &s) { m_ind = ind; m_s = s; }

   //--- l'overlay e' ammesso contro questa principale?
   bool              AllowedAgainst(const int coreDir) const
     {
      switch(m_s.ovAgainst)
        {
         case OV_BOTH:               return true;
         case OV_AGAINST_SHORT_CORE: return coreDir < 0;
         case OV_AGAINST_LONG_CORE:  return coreDir > 0;
         default:                    return false;
        }
     }

   //--- breakout del canale overlay nella direzione 'ovDir' sulla barra chiusa
   bool              Breakout(const int ovDir) const
     {
      double c = m_ind.CloseOv(1);
      if(ovDir < 0)
        {
         double ll = m_ind.LowestOv(m_s.donchOv, 2);
         return ll != EMPTY_VALUE && c < ll;
        }
      double hh = m_ind.HighestOv(m_s.donchOv, 2);
      return hh != EMPTY_VALUE && c > hh;
     }

   //--- conferma di momentum (EMA20/EMA50 del TF overlay allineate con l'overlay)
   bool              MomentumConfirm(const int ovDir) const
     {
      double e20 = m_ind.Ema20Ov(1), e50 = m_ind.Ema50Ov(1);
      if(e20 == EMPTY_VALUE || e50 == EMPTY_VALUE) return false;
      return (ovDir < 0) ? (e20 < e50) : (e20 > e50);
     }

   //--- primo ingresso
   bool              FirstEntry(const int coreDir) const
     {
      int od = -coreDir;
      return AllowedAgainst(coreDir) && Breakout(od) && MomentumConfirm(od);
     }

   //--- incremento: solo se l'ultimo ingresso e' in profitto >= addR * R e c'e' un nuovo breakout
   bool              AddEntry(const int coreDir, const double lastEntry, const double lastR) const
     {
      int od = -coreDir;
      double c = m_ind.CloseOv(1);
      if(lastR <= 0.0) return false;
      bool inProfit = od * (c - lastEntry) >= m_s.addR * lastR;
      return AllowedAgainst(coreDir) && inProfit && Breakout(od);
     }

   double            StopDistance(void) const
     {
      double a = m_ind.AtrOv(1);
      return (a == EMPTY_VALUE) ? 0.0 : m_s.kOvStop * a;
     }

   //--- trailing di Donchian (uscita): per overlay short = massimo delle ultime N barre
   double            TrailLevel(const int ovDir) const
     {
      return (ovDir < 0) ? m_ind.HighestOv(m_s.donchOvExit, 1) : m_ind.LowestOv(m_s.donchOvExit, 1);
     }
  };

#endif
//+------------------------------------------------------------------+
