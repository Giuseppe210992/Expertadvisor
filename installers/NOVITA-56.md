# giot.ai: installatore 56 · Capire davvero cosa chiedi (e togliere oggetti dalle foto)

## Installazione

Comando e impronta sha256 nel messaggio di consegna (file `installa-giot-chat-56.sh`).

## Cosa non andava
- «Elimina gli occhiali dalla foto» e «Rimuovi gli occhiali dal tavolo» finivano alla chat normale: le parole fisse non includevano «elimina», e «rimuovi» valeva solo se nella frase c'era «foto». Risultato: «non dispongo di strumenti», «non ho braccia», consigli di siti esterni.
- «No, rimuovili dalla foto», scritto senza riallegare la foto, non veniva collegato alla foto del messaggio prima. Partiva una ricerca web con il connettore.

## Cosa cambia
- **Centralino che capisce.** Quando c'è di mezzo un'immagine (allegata ora, nei messaggi prima o creata da giot), oppure la frase parla di foto o immagini, un modello veloce legge il messaggio **insieme agli ultimi scambi** e decide cosa vuoi davvero:
  - modificare la foto;
  - creare un'immagine;
  - oppure parlarne o fare una domanda.

  Capisce anche frasi informali, sottintese o le correzioni come «no, dalla foto».
- **Parole di rimozione:** elimina, cancella, togli, rimuovi, leva, «fai sparire»… con una foto sono una modifica.
- **Togliere un oggetto non ricrea più la foto da una descrizione.**
  - Senza generatore IA: «Apri nello studio», dipingi l'oggetto con il dito, poi **«Togli ciò che dipingi»**. Lo sfondo viene ricostruito con la grana vera della foto e fuori dalla zona la foto resta identica al pixel.
  - Con un generatore collegato, la rimozione la fa l'IA.
- **Istruzioni del modello:** giot sa che modifica le foto, quindi non risponde più «non posso» e non manda su siti esterni. «Rimuovi X» su una foto vuol dire toglierlo dall'immagine.

## Collaudi
- Il tuo caso esatto: 12/12.
  - foto + «Rimuovi gli occhiali dal tavolo»;
  - poi «No rimuovili dalla foto» senza foto;
  - «Cosa c'è in questa foto?» resta una domanda;
  - occhiali tolti, zero pixel cambiati fuori dalla zona.
