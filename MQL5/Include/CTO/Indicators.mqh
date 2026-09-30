//+------------------------------------------------------------------+
//|                                               CTO/Indicators.mqh |
//|   Accesso agli indicatori su barre CHIUSE (shift >= 1).          |
//|   Nessun valore della barra in formazione entra nelle decisioni. |
//+------------------------------------------------------------------+
#ifndef CTO_INDICATORS_MQH
#define CTO_INDICATORS_MQH

#include "Defines.mqh"

class CCtoIndicators
  {
private:
   string            m_symbol;
   SCtoSettings      m_s;
   int               m_hEmaFast;
   int               m_hEmaSlow;
   int               m_hAtrCore;
   int               m_hEma20Ov;
   int               m_hEma50Ov;
   int               m_hAtrOv;

   double            Buf(const int handle, const int shift) const
     {
      double v[1];
      if(handle == INVALID_HANDLE || CopyBuffer(handle, 0, shift, 1, v) != 1)
         return EMPTY_VALUE;
      return v[0];
     }

public:
                     CCtoIndicators(void) : m_hEmaFast(INVALID_HANDLE), m_hEmaSlow(INVALID_HANDLE),
                     m_hAtrCore(INVALID_HANDLE), m_hEma20Ov(INVALID_HANDLE),
                     m_hEma50Ov(INVALID_HANDLE), m_hAtrOv(INVALID_HANDLE) {}
                    ~CCtoIndicators(void) { Release(); }

   bool              Init(const string symbol, const SCtoSettings &s)
     {
      m_symbol = symbol;
      m_s = s;
      m_hEmaFast = iMA(symbol, s.tfCore, s.emaFast, 0, MODE_EMA, PRICE_CLOSE);
      m_hEmaSlow = iMA(symbol, s.tfCore, s.emaSlow, 0, MODE_EMA, PRICE_CLOSE);
      m_hAtrCore = iATR(symbol, s.tfCore, s.atrCore);
      m_hEma20Ov = iMA(symbol, s.tfOv, 20, 0, MODE_EMA, PRICE_CLOSE);
      m_hEma50Ov = iMA(symbol, s.tfOv, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_hAtrOv   = iATR(symbol, s.tfOv, s.atrOv);
      if(m_hEmaFast == INVALID_HANDLE || m_hEmaSlow == INVALID_HANDLE || m_hAtrCore == INVALID_HANDLE ||
         m_hEma20Ov == INVALID_HANDLE || m_hEma50Ov == INVALID_HANDLE || m_hAtrOv == INVALID_HANDLE)
        {
         PrintFormat("[CTO] errore creazione indicatori: %d", GetLastError());
         return false;
        }
      return true;
     }

   void              Release(void)
     {
      if(m_hEmaFast != INVALID_HANDLE) IndicatorRelease(m_hEmaFast);
      if(m_hEmaSlow != INVALID_HANDLE) IndicatorRelease(m_hEmaSlow);
      if(m_hAtrCore != INVALID_HANDLE) IndicatorRelease(m_hAtrCore);
      if(m_hEma20Ov != INVALID_HANDLE) IndicatorRelease(m_hEma20Ov);
      if(m_hEma50Ov != INVALID_HANDLE) IndicatorRelease(m_hEma50Ov);
      if(m_hAtrOv   != INVALID_HANDLE) IndicatorRelease(m_hAtrOv);
      m_hEmaFast = m_hEmaSlow = m_hAtrCore = m_hEma20Ov = m_hEma50Ov = m_hAtrOv = INVALID_HANDLE;
     }

   //--- pronto se tutti i buffer hanno abbastanza storia
   bool              Ready(void) const
     {
      return BarsCalculated(m_hEmaSlow) > m_s.emaSlow + 2 &&
             BarsCalculated(m_hAtrCore) > m_s.atrCore + 2 &&
             BarsCalculated(m_hAtrOv) > m_s.atrOv + 2 &&
             Bars(m_symbol, m_s.tfCore) > MathMax(m_s.emaSlow, m_s.donchEntry) + 5 &&
             Bars(m_symbol, m_s.tfOv) > m_s.donchOv + 5;
     }

   //--- timeframe principale
   double            EmaFast(const int shift = 1) const { return Buf(m_hEmaFast, shift); }
   double            EmaSlow(const int shift = 1) const { return Buf(m_hEmaSlow, shift); }
   double            AtrCore(const int shift = 1) const { return Buf(m_hAtrCore, shift); }
   double            CloseCore(const int shift = 1) const { return iClose(m_symbol, m_s.tfCore, shift); }

   //--- massimo/minimo delle N barre PRECEDENTI a 'shift' (canale di Donchian)
   double            HighestCore(const int n, const int shift = 2) const
     {
      int idx = iHighest(m_symbol, m_s.tfCore, MODE_HIGH, n, shift);
      return (idx < 0) ? EMPTY_VALUE : iHigh(m_symbol, m_s.tfCore, idx);
     }
   double            LowestCore(const int n, const int shift = 2) const
     {
      int idx = iLowest(m_symbol, m_s.tfCore, MODE_LOW, n, shift);
      return (idx < 0) ? EMPTY_VALUE : iLow(m_symbol, m_s.tfCore, idx);
     }

   //--- regime: +1 rialzista, -1 ribassista, 0 indefinito (barra chiusa)
   int               Regime(void) const
     {
      double f = EmaFast(1), s = EmaSlow(1), c = CloseCore(1);
      if(f == EMPTY_VALUE || s == EMPTY_VALUE || c <= 0.0) return 0;
      if(f > s && c > s) return 1;
      if(f < s && c < s) return -1;
      return 0;
     }

   //--- massimo/minimo delle CHIUSURE del TF principale da 'since' all'ultima barra chiusa
   double            ExtremeCloseSince(const datetime since, const int dir) const
     {
      double closes[];
      datetime last = iTime(m_symbol, m_s.tfCore, 1);
      if(last < since) return 0.0;
      int n = CopyClose(m_symbol, m_s.tfCore, since, last, closes);
      if(n <= 0) return 0.0;
      double ext = closes[0];
      for(int i = 1; i < n; i++)
         ext = (dir > 0) ? MathMax(ext, closes[i]) : MathMin(ext, closes[i]);
      return ext;
     }

   //--- timeframe overlay
   double            AtrOv(const int shift = 1) const { return Buf(m_hAtrOv, shift); }
   double            Ema20Ov(const int shift = 1) const { return Buf(m_hEma20Ov, shift); }
   double            Ema50Ov(const int shift = 1) const { return Buf(m_hEma50Ov, shift); }
   double            CloseOv(const int shift = 1) const { return iClose(m_symbol, m_s.tfOv, shift); }
   double            HighestOv(const int n, const int shift) const
     {
      int idx = iHighest(m_symbol, m_s.tfOv, MODE_HIGH, n, shift);
      return (idx < 0) ? EMPTY_VALUE : iHigh(m_symbol, m_s.tfOv, idx);
     }
   double            LowestOv(const int n, const int shift) const
     {
      int idx = iLowest(m_symbol, m_s.tfOv, MODE_LOW, n, shift);
      return (idx < 0) ? EMPTY_VALUE : iLow(m_symbol, m_s.tfOv, idx);
     }
  };

#endif
//+------------------------------------------------------------------+
