# giot.ai: installatore 50 · I .doc compilati con la formattazione dell'originale

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-50.sh -o installa-giot-chat.sh && echo "5794f8b67f44c358410faa4562c002ad14e0de9c3e1fa209697f787361a1114e  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **.doc caricati quando il convertitore non c'era:** nel progetto ne restava solo una copia semplificata, che perdeva:
  - il carattere (diventava un altro);
  - la centratura del titolo;
  - l'interlinea;
  - il MAIUSCOLO applicato come stile di Word, per cui comparivano parole in minuscolo.

  Ora, quando compili, giot riconverte con fedeltà il .doc originale (conservato nel progetto) e compila quello. La conversione resta salvata per le volte successive.
- **Spazi intorno ai dati nei Word:** si aggiunge uno spazio solo dove manca, quindi niente più doppi spazi («SIGNOR  MARIO ROSSI  CODICE»).

## Collaudi
- Il .doc vero «Dichiarazione nulla a pretendere agenzia», compilato in due modi:
  - convertito con fedeltà subito;
  - caricato come copia semplificata e poi compilato con il convertitore attivo.

  In entrambi i casi: carattere Times dell'originale, maiuscole conservate, nome dentro la frase, data «__/__/____» sostituita per intero.
- Regressione completa: tutto verde (interfaccia 25 collaudi + variante senza convertitore, server 20 collaudi).
