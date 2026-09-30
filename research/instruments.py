"""
Specifiche di costo per strumento (conto ECN/RAW retail tipico, UE, 2024-2026).

TUTTI i valori sono STIME da verificare sul proprio broker: l'EA include un logger
dei costi reali (CostTracker) e lo script MQL5 CostReport.mq5 che li misura.

Unita':
  spread_avg / spread_max / slippage : unita' di prezzo (es. 0.00015 = 1.5 decimi di pip su EURUSD)
  comm_frac   : commissione per lato come frazione del nozionale (0.000035 = 3.5 USD per 100k)
  swap_markup : markup annuo del broker sul finanziamento overnight, per lato (0.01 = 1%/anno)
  lev         : leva massima retail ESMA (per il calcolo del margine)
  kind        : 'fx' (swap = differenziale tassi), 'cfd' (swap = tasso valuta + markup)
"""

INSTR = {
    #              spread_avg spread_max  slippage   comm_frac  swap_mk  lev  kind   base   quote  point
    "EUR_USD":    dict(spread_avg=0.00002, spread_max=0.00030, slippage=0.00002, comm_frac=0.000035, swap_markup=0.010, lev=30, kind="fx",  base="EUR", quote="USD", point=0.0001),
    "GBP_USD":    dict(spread_avg=0.00005, spread_max=0.00060, slippage=0.00003, comm_frac=0.000035, swap_markup=0.010, lev=30, kind="fx",  base="GBP", quote="USD", point=0.0001),
    "AUD_USD":    dict(spread_avg=0.00004, spread_max=0.00050, slippage=0.00002, comm_frac=0.000035, swap_markup=0.010, lev=20, kind="fx",  base="AUD", quote="USD", point=0.0001),
    "USD_CAD":    dict(spread_avg=0.00006, spread_max=0.00060, slippage=0.00003, comm_frac=0.000035, swap_markup=0.010, lev=30, kind="fx",  base="USD", quote="CAD", point=0.0001),
    "EUR_JPY":    dict(spread_avg=0.0060,  spread_max=0.0400, slippage=0.0010,  comm_frac=0.000035, swap_markup=0.010, lev=30, kind="fx",  base="EUR", quote="JPY", point=0.01),
    "AUD_JPY":    dict(spread_avg=0.0070,  spread_max=0.0500, slippage=0.0012,  comm_frac=0.000035, swap_markup=0.010, lev=20, kind="fx",  base="AUD", quote="JPY", point=0.01),
    "XAU_USD":    dict(spread_avg=0.15,    spread_max=1.00,   slippage=0.05,    comm_frac=0.000020, swap_markup=0.025, lev=20, kind="cfd", base="XAU", quote="USD", point=0.01),
    "NAS100_USD": dict(spread_avg=1.20,    spread_max=6.00,   slippage=0.50,    comm_frac=0.0,      swap_markup=0.025, lev=20, kind="cfd", base="IDX", quote="USD", point=0.1),
    "SPX500_USD": dict(spread_avg=0.50,    spread_max=2.50,   slippage=0.25,    comm_frac=0.0,      swap_markup=0.025, lev=20, kind="cfd", base="IDX", quote="USD", point=0.1),
    "UK100_GBP":  dict(spread_avg=1.00,    spread_max=5.00,   slippage=0.50,    comm_frac=0.0,      swap_markup=0.025, lev=20, kind="cfd", base="IDX", quote="GBP", point=0.1),
    "JP225_USD":  dict(spread_avg=7.00,    spread_max=30.0,   slippage=3.00,    comm_frac=0.0,      swap_markup=0.025, lev=20, kind="cfd", base="IDX", quote="USD", point=1.0),
    "WTICO_USD":  dict(spread_avg=0.03,    spread_max=0.15,   slippage=0.01,    comm_frac=0.0,      swap_markup=0.030, lev=10, kind="cfd", base="OIL", quote="USD", point=0.01),
}

# Tassi di policy/interbancari medi annui (approssimati) per il modello di swap storico.
RATES = {
    "USD": {2005: 3.2, 2006: 5.0, 2007: 5.0, 2008: 2.0, 2009: 0.15, 2010: 0.15, 2011: 0.1, 2012: 0.15, 2013: 0.1,
            2014: 0.1, 2015: 0.15, 2016: 0.4, 2017: 1.0, 2018: 1.8, 2019: 2.2, 2020: 0.4},
    "EUR": {2005: 2.1, 2006: 2.8, 2007: 3.9, 2008: 3.9, 2009: 1.2, 2010: 0.8, 2011: 1.3, 2012: 0.5, 2013: 0.2,
            2014: 0.1, 2015: -0.1, 2016: -0.3, 2017: -0.35, 2018: -0.35, 2019: -0.4, 2020: -0.45},
    "GBP": {2005: 4.7, 2006: 4.6, 2007: 5.6, 2008: 4.7, 2009: 0.6, 2010: 0.5, 2011: 0.5, 2012: 0.5, 2013: 0.5,
            2014: 0.5, 2015: 0.5, 2016: 0.4, 2017: 0.3, 2018: 0.6, 2019: 0.75, 2020: 0.2},
    "JPY": {2005: 0.0, 2006: 0.2, 2007: 0.5, 2008: 0.5, 2009: 0.1, 2010: 0.1, 2011: 0.1, 2012: 0.1, 2013: 0.1,
            2014: 0.1, 2015: 0.1, 2016: -0.05, 2017: -0.05, 2018: -0.05, 2019: -0.05, 2020: -0.05},
    "AUD": {2005: 5.5, 2006: 5.8, 2007: 6.4, 2008: 6.8, 2009: 3.3, 2010: 4.4, 2011: 4.7, 2012: 3.8, 2013: 2.9,
            2014: 2.5, 2015: 2.1, 2016: 1.6, 2017: 1.5, 2018: 1.5, 2019: 1.0, 2020: 0.35},
    "CAD": {2005: 2.7, 2006: 4.0, 2007: 4.3, 2008: 3.0, 2009: 0.4, 2010: 0.6, 2011: 1.0, 2012: 1.0, 2013: 1.0,
            2014: 1.0, 2015: 0.6, 2016: 0.5, 2017: 0.7, 2018: 1.4, 2019: 1.75, 2020: 0.6},
}


# rendimento da dividendi medio (aggiustamento dividendi dei CFD su indici cash)
DIV = {"SPX500_USD": 0.020, "NAS100_USD": 0.010, "UK100_GBP": 0.038, "JP225_USD": 0.018}


def swap_rates(sym, year, markup_mult=1.0):
    """Tasso annuo di swap (frazione, >0 = incasso) per lato LONG e SHORT sul nozionale.
    markup_mult=0 approssima il finanziamento implicito dei FUTURES (carry puro, nessun markup broker)."""
    s = INSTR[sym]
    m = s["swap_markup"] * markup_mult
    q = RATES.get(s["quote"], RATES["USD"])[year] / 100
    if s["kind"] == "fx":
        b = RATES[s["base"]][year] / 100
        return (b - q - m, q - b - m)
    # CFD: il long paga (tasso + markup), lo short incassa (tasso - markup);
    # sugli indici cash il long riceve i dividendi, lo short li paga
    dv = DIV.get(sym, 0.0)
    return (-(q + m) + dv, q - m - dv)
