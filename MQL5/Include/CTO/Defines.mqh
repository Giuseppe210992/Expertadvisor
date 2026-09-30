//+------------------------------------------------------------------+
//|                                                  CTO/Defines.mqh |
//|   Core Trend + Counter-Trend Overlay (CTO) - tipi e impostazioni |
//+------------------------------------------------------------------+
#ifndef CTO_DEFINES_MQH
#define CTO_DEFINES_MQH

#define CTO_VERSION "1.00"

//--- ruolo di una "gamba" (leg) della strategia
enum ENUM_CTO_ROLE
  {
   ROLE_CORE    = 0,   // posizione principale (trend di lungo periodo)
   ROLE_OVERLAY = 1    // operazione opposta (overlay contro-trend)
  };

//--- contro quale direzione della principale sono ammessi gli overlay
enum ENUM_OV_AGAINST
  {
   OV_DISABLED           = 0, // overlay disattivato (solo principale)
   OV_AGAINST_SHORT_CORE = 1, // solo rimbalzi contro principale SHORT (default da ricerca)
   OV_AGAINST_LONG_CORE  = 2, // solo correzioni contro principale LONG (sconsigliato)
   OV_BOTH               = 3  // entrambe le direzioni (idea originale)
  };

//--- modalita' di esecuzione dell'overlay
enum ENUM_EXEC_MODE
  {
   EXEC_AUTO  = 0, // automatica: hedge su conto hedging, netting su conto netting
   EXEC_HEDGE = 1, // ticket opposti (richiede conto hedging; paga doppio swap)
   EXEC_NET   = 2  // riduzione della principale (gamba virtuale; nessun doppio swap)
  };

//--- cosa fare al raggiungimento del target giornaliero
enum ENUM_TARGET_MODE
  {
   TGT_OFF           = 0, // nessuna azione (raccomandato, vedi ricerca)
   TGT_BLOCK_NEW     = 1, // blocca nuovi ingressi fino al giorno successivo
   TGT_CLOSE_OVERLAY = 2, // chiude gli overlay e blocca nuovi ingressi
   TGT_CLOSE_ALL     = 3  // chiude tutto e blocca (sconsigliato: tronca i trend)
  };

//--- impostazioni complete (riempite da input nell'EA)
struct SCtoSettings
  {
   //--- principale
   ENUM_TIMEFRAMES   tfCore;
   int               emaFast;
   int               emaSlow;
   int               donchEntry;
   int               atrCore;
   double            kStop;
   double            kTrail;
   double            coreRiskPct;
   bool              allowLong;
   bool              allowShort;
   //--- overlay
   ENUM_TIMEFRAMES   tfOv;
   ENUM_OV_AGAINST   ovAgainst;
   int               donchOv;
   int               donchOvExit;
   int               atrOv;
   double            kOvStop;
   double            hStep;
   double            maxRatio;
   double            addR;
   double            tpR;
   double            tpFrac;
   bool              ovAfterCoreExit;
   int               edgeN;
   double            edgeMin;
   //--- esecuzione
   ENUM_EXEC_MODE    execMode;
   int               rolloverStartHour;
   int               rolloverEndHour;
   int               maxSpreadPoints;
   double            maxSpreadAtrFrac;
   int               deviationPoints;
   int               maxRetries;
   int               signalExpiryHours;
   //--- rischio
   double            maxHeatPct;
   double            maxGrossLeverage;
   double            minMarginLevel;
   double            dailyLossPct;
   double            haltDDPct;
   double            dailyTargetPct;
   ENUM_TARGET_MODE  targetMode;
   //--- identificazione
   long              magicCore;
   long              magicOv;
   string            tag;
   bool              logCsv;
  };

//--- gamba virtuale (netting o "ombra" dell'edge monitor)
struct SVirtualLeg
  {
   long              id;
   int               dir;        // +1 long, -1 short
   double            volume;
   double            entry;
   double            sl;
   double            tp;         // 0 = nessun TP
   double            tpVolume;   // volume da chiudere al TP
   double            R;          // distanza di stop iniziale (prezzo)
   datetime          openTime;
   bool              shadow;     // true = solo tracciata, nessun ordine
   bool              tpDone;
   double            costAcc;    // costi stimati accumulati (valuta conto)
   double            risk0;      // rischio iniziale in denaro dell'INGRESSO intero
   double            rAcc;       // R gia' realizzato da chiusure parziali dello stesso ingresso
   bool              isPart;     // true = frammento TP in chiusura (appartiene all'ingresso 'id')
  };

//--- utilita'
int    CtoSign(const double v) { return (v > 0.0) ? 1 : ((v < 0.0) ? -1 : 0); }
string CtoRoleName(const ENUM_CTO_ROLE r) { return (r == ROLE_CORE) ? "CORE" : "OVERLAY"; }

#endif
//+------------------------------------------------------------------+
