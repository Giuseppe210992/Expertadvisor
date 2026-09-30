//+------------------------------------------------------------------+
//|                                               CTO/SymbolMath.mqh |
//|   Conversioni prezzo <-> denaro, normalizzazione lotti.          |
//+------------------------------------------------------------------+
#ifndef CTO_SYMBOLMATH_MQH
#define CTO_SYMBOLMATH_MQH

class CSymbolMath
  {
private:
   string            m_sym;

public:
   void              Init(const string sym) { m_sym = sym; }
   string            Symbol(void) const { return m_sym; }

   double            Point(void)   const { return SymbolInfoDouble(m_sym, SYMBOL_POINT); }
   int               Digits(void)  const { return (int)SymbolInfoInteger(m_sym, SYMBOL_DIGITS); }
   double            Bid(void)     const { return SymbolInfoDouble(m_sym, SYMBOL_BID); }
   double            Ask(void)     const { return SymbolInfoDouble(m_sym, SYMBOL_ASK); }
   double            Spread(void)  const { return Ask() - Bid(); }
   int               SpreadPoints(void) const { return (int)MathRound(Spread() / Point()); }

   //--- valore in valuta del conto di 1.0 di movimento di prezzo per 1 lotto
   double            ValuePerPriceUnit(void) const
     {
      double tv = SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tv <= 0.0) tv = SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_SIZE);
      return (ts > 0.0) ? tv / ts : 0.0;
     }

   //--- nozionale in valuta del conto di 'lots' lotti
   double            Notional(const double lots, const double price) const
     {
      return lots * price * ValuePerPriceUnit();
     }

   double            NormalizePrice(const double p) const
     {
      double ts = SymbolInfoDouble(m_sym, SYMBOL_TRADE_TICK_SIZE);
      if(ts <= 0.0) return NormalizeDouble(p, Digits());
      return NormalizeDouble(MathRound(p / ts) * ts, Digits());
     }

   //--- arrotonda PER DIFETTO al passo di volume (non si aumenta mai il rischio arrotondando)
   double            NormalizeLotsDown(const double lots) const
     {
      double step = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_STEP);
      double vmin = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MIN);
      double vmax = SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MAX);
      if(step <= 0.0) step = 0.01;
      double v = MathFloor(lots / step + 1e-9) * step;
      if(v < vmin - 1e-12) return 0.0;
      v = MathMin(v, vmax);
      int dg = (int)MathMax(0, MathCeil(-MathLog10(step)));
      return NormalizeDouble(v, dg);
     }

   double            MinLot(void) const { return SymbolInfoDouble(m_sym, SYMBOL_VOLUME_MIN); }

   //--- distanza minima degli stop imposta dal broker (prezzo)
   double            StopsLevel(void) const
     {
      return (double)SymbolInfoInteger(m_sym, SYMBOL_TRADE_STOPS_LEVEL) * Point();
     }
  };

#endif
//+------------------------------------------------------------------+
