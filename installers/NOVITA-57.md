# giot.ai: installatore 57 · Togliere un oggetto dalla foto, davvero (e controllato)

## Installazione

Comando e impronta sha256 nel messaggio di consegna (file `installa-giot-chat-57.sh`).

## Cosa non andava (il tuo screenshot dell'accendino)
- «Togli l'accendino dalla foto» mandava **tutta** la foto al generatore (FLUX Kontext su Pollinations) con la frase tradotta.
- Il generatore ha restituito la foto **con l'accendino ancora lì**, e in più con le proporzioni cambiate.
- giot non controllava il risultato e scriveva comunque «Fatto: ho modificato la tua immagine come richiesto».

## Cosa cambia: come lavora un fotoritocco vero
1. **Trova.** Un modello con visione (Gemini) guarda la foto, capisce cosa vuoi togliere (anche detto con un sinonimo) e ne segna la posizione esatta, ombra compresa.
2. **Toglie solo lì.**
   - Con un generatore collegato, l'IA riceve la foto **con la zona segnata**. Il suo risultato si usa **solo dentro quella zona**: fuori la foto resta identica all'originale, con le stesse proporzioni.
   - Se l'IA restituisce la foto uguale (il tuo caso), giot **se ne accorge misurando i pixel** e passa alla cancellazione locale. Questa ricostruisce il piano con la trama vera presa tutt'attorno.
   - Senza generatore, la cancellazione locale parte subito, senza dover dipingere a mano.
3. **Controlla.** Un modello confronta la zona **prima e dopo**. Se l'oggetto si vede ancora, prova l'altro metodo e ricontrolla.
4. **Dice la verità:**
   - «Fatto: ho tolto l'accendino e ho controllato il risultato» solo se il controllo lo conferma;
   - se resta qualcosa lo dice, e spiega come rifinire con **Modifica**;
   - se il controllo non risponde lo dice;
   - se non trova l'oggetto con sicurezza non tira a indovinare e apre lo studio.

## Altre correzioni
- **Modifiche normali** («rendila più luminosa»): se il generatore restituisce la foto praticamente uguale, giot lo dice invece di scrivere «fatto».
- **Cancellazione locale più pulita:**
  - niente più striscia chiara sul bordo destro e niente effetto «a blocchi»;
  - la grana si copia a tasselli dalla superficie vera (come il timbro clone), invece che a puntini casuali.
- «Togli lo sfondo» resta lo sfondo trasparente: non viene scambiato per «togli un oggetto».

## Collaudi
- Nuovo collaudo «togli l'accendino», 23/23:
  - senza generatore;
  - generatore che restituisce la foto uguale (il tuo caso);
  - generatore che lavora bene;
  - controllo che dice «si vede ancora»;
  - controllo che non risponde;
  - oggetto assente.
- Ogni volta si verifica che **fuori dalla zona nessun pixel cambi** e che le proporzioni restino quelle della foto.
- Tutti i collaudi precedenti ripetuti.

## Limiti onesti
- Oggetti grandi su sfondi complicati (una persona davanti a una folla) restano difficili per la cancellazione locale: lì serve l'IA, e il controllo te lo dice.
- Le foto molto grandi vengono lavorate a 2048 pixel sul lato lungo.
