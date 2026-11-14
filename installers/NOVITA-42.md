# giot.ai: installatore 42 · Code lavora come Claude Code

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-42.sh -o installa-giot-chat.sh && echo "3c85854a74e1660d3ac307f160395f2c9df93e281e1b30aae82dbac21c13f8d5  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Metodo di lavoro.** L'agente segue questi passi: capire la richiesta, esplorare i file prima di scrivere, fare un piano nelle note, modificare in modo piccolo e preciso, verificare sempre, correggere la causa (al massimo 3 tentativi), chiudere dicendo cosa resta da confermare. Non inventa dati reali.
- **Strumenti nuovi:** ricerca nei file, modifica precisa, verifica prima di consegnare, note del progetto, lettura della documentazione online.
- **La verifica controlla:** percorsi assoluti, file mancanti, sintassi di JavaScript e JSON, visualizzazione sul telefono, lingua della pagina, descrizioni delle immagini, uso della memoria del browser.
- **Controllo di qualità automatico.** Se l'agente consegna senza aver verificato le modifiche, giot.ai verifica al suo posto e gli fa correggere gli errori.
- **Ricettario per argomento:** siti, moduli, web app, Vite, React, grafici e mappe, script e dati, app installabili, errori, pubblicazione.
- **16 lezioni di partenza** prese dagli errori veri incontrati costruendo giot.ai. Vanno nella memoria (sezione Code) una volta sola. Le lezioni imparate sui tuoi progetti pesano un po' di più.
- **Anteprima:** si ricarica da sola dopo la pubblicazione, così non resta bianca.
- **Avvio di Code:** mentre il banco di lavoro si avvia, la pagina dice «si sta avviando…» e riprova da sola.

## Collaudi
- Strumenti del banco di lavoro: 18/18.
- Metodo e controllo di qualità nel browser: 13/13.
- Regressione completa: app 92, 45, 36, 40, 37, 8, 14, 9, 22, 16, 19, 10, 29, 22, 20, 13; office 36, compilazione 13, esportazione 10; server 87, 106, 32, 41, 29, 31, 5, 41, 20, 25, 17, chiavi 10, Code 35, connettori 11, GitHub 26, memoria 14, strumenti 18. Tutto verde.
