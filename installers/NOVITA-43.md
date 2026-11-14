# giot.ai: installatore 43 · Code: foto e file, da mostrare o da usare nel progetto

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-43.sh -o installa-giot-chat.sh && echo "4ce842823897dddd0137f33041267f3333c4bb0ab24cfec5b65d1a6cbdee805f  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Graffetta 📎 in Code** (o trascina i file sulla pagina): foto dalla galleria o dalla fotocamera, CSV, Excel, PDF, testi, caratteri, video. Fino a 12 file per volta, ciascuno al massimo 10 MB.
- Su ogni file c'è un tasto per scegliere il tipo:
  - **«da mostrare»** (foto e schermate partono così): l'agente lo guarda per capire, per esempio un problema, un esempio da imitare o un errore. Sta in una cartella privata del progetto e non viene pubblicato né inviato a GitHub.
  - **«nel progetto»** (dati, PDF e caratteri partono così): va nelle cartelle del sito (img/, dati/, documenti/, fonts/; con Vite in public/). Il nome viene ripulito e non sovrascrive mai un file esistente.
- **Foto ridotte da sole** a 1600 px: il sito resta leggero.
- **L'agente vede le foto** se il modello scelto legge le immagini. Se non le legge, il lavoro continua con i nomi dei file.
- I **testi «da mostrare»** (errori, istruzioni, codice) l'agente li riceve subito da leggere.
- Due strumenti nuovi per l'agente: **save_attachment** (copia nel sito una foto mostrata, per esempio «usa la foto di prima come copertina») e **read_attachment**.
- **Scheda File:** le immagini si vedono in anteprima, con il percorso da usare nel codice.

## Collaudi
- Banco di lavoro: 33/33 (caricamento binario, allegati privati mai pubblicati né esportati, copia nel progetto, nomi sicuri, limiti).
- Nel browser: 21/21 (foto ridotta e «da mostrare», CSV «nel progetto», scelta del tipo con un tocco, testo d'errore letto dall'agente, save_attachment, modello senza visione, anteprima, trascina e rilascia).
- Regressione completa: tutto verde (app, office, compilazione, esportazione, server, Code, GitHub, memoria).
