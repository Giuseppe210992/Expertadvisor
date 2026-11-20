# giot.ai: installatore 52 · «Compila» per tutti i moduli del progetto

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-52.sh -o installa-giot-chat.sh && echo "894b573ff5908540135761b11cfad0da35913ef1be4fe4ac26fa5376d6a7224e  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **«Compila» c'è sempre** per i PDF e i Word del progetto, anche quando giot non ha riconosciuto gli spazi da solo (celle vuote di tabelle, righe disegnate, scansioni). Per esempio «Adeguata verifica».
  - Prima si riprova il riconoscimento con le regole attuali.
  - Se gli spazi ancora non si trovano, si apre la compilazione guidata sull'originale: scegli il cliente e tocchi l'anteprima dove scrivere.
- **Avvisi sui .doc più precisi:**
  - file del progetto senza originale: «elimina e ricarica»;
  - convertitore spento: copia semplificata, e giot lo dice.

## Collaudi
- Modulo a tabella con celle vuote: «Compila» presente, compilazione guidata aperta (4/4).
- Regressione completa: tutto verde (interfaccia 26 collaudi più due varianti del .doc, server 20 collaudi).
