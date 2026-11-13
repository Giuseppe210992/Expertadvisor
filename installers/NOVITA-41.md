# giot.ai: installatore 41 · La memoria: impara come lavori

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "095b6ed67eb03ae118e2febafa26aceff54f6c59e2cd992b935bd362c43be435  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia

### Una memoria vera, uguale su tutti i dispositivi
- La memoria sta **sul tuo server, cifrata** come l'archivio clienti, ed è uguale su telefono e computer. Entra anche nelle copie di sicurezza dell'archivio.
- Al primo avvio i ricordi che avevi nel browser **salgono sul server** da soli, senza doppioni.
- Quattro tipi di ricordo:
  - **Fatti su di te**: «Vive a Scauri», «Lavora come agente immobiliare».
  - **Preferenze**: «Preferisce i documenti in PDF», «Nei siti colori sobri».
  - **Come lavori**: le tue procedure, per esempio «Nelle proroghe la data è quella dell'atto».
  - **Lezioni imparate**: errori risolti in Code, per non ripeterli.

### Impara da come lavori
- **Chat.** Quando correggi o spieghi come vuoi le cose («sempre…», «mai…», «la prossima volta…», «preferisco…», «di solito…»), giot.ai propone: *Vuoi che ricordi come lavori: «…»?* Salva solo se confermi, con il tipo giusto e la sezione giusta (per esempio Moduli).
- **Code.** Quando l'agente risolve un errore, sul server o su GitHub, salva da solo una **lezione** breve («Ho imparato: …»). Le preferenze che esprimi in Code («usa sempre colori sobri») le propone come in chat.
- **Moduli.** I modelli continuano a ricordare dove va ogni dato e le posizioni scritte a mano.

### Usa i ricordi giusti
- Nelle richieste entrano **solo i ricordi pertinenti**: quelli della sezione in cui lavori e quelli che parlano della stessa cosa. I fatti brevi su di te ci sono sempre.
  - Se chiedi una proroga, entra la tua regola sulle proroghe.
  - Se chiedi una poesia, no.
- L'agente di Code riceve le lezioni imparate nei lavori precedenti, oltre alle tue preferenze.
- I ricordi usati spesso restano. Quando la memoria è piena (400 voci) escono prima le lezioni meno usate, **mai** quelli che hai fissato.

### Impostazioni → Memoria
- Ricordi divisi per tipo, ciascuno con la sua **sezione** e la **provenienza** (chat, Code, a mano).
- Per ogni ricordo: **fissa** (usalo sempre), **modifica**, **elimina**.
- Puoi aggiungere un ricordo a mano scegliendo tipo e sezione.
- Due interruttori: «Proponi cosa ricordare» e «Impara dagli errori risolti».

### Nota su «chiunque usi giot.ai»
Oggi il server non distingue le persone: chi accede allo stesso server condivide la stessa memoria, come condivide l'archivio clienti. Per avere una memoria separata per ogni persona serve riconoscere chi ha fatto l'accesso. È il passo successivo, se ti serve.

## Collaudi
- Memoria sul server: 14/14 (cifrata sul disco, niente doppioni, tipi e sezioni validati, limite di 400 con priorità, uso contato, importazione, persiste al riavvio).
- Nel browser con il server vero: 20/20 (migrazione dal browser, proposta «come lavori» da una correzione con conferma, richiamo solo dei ricordi pertinenti, lezione automatica in Code dopo un errore risolto e usata al lavoro successivo, preferenza in Code, Impostazioni → Memoria con fissa/modifica/aggiungi/elimina, secondo dispositivo).
- Regressione completa: app 92, 45, 36, 40, 37, 8, 14, 9, 22, 16, 19, 10, 29, 22, 20, office 36, compilazione 13, esportazione 10; server 87, 106, 32, 41, 29, 31, 5, 41, 20, 25, 17, chiavi 10, Code 35, connettori 11, GitHub 26, memoria 14. Tutto verde.
- Installatore: identico al 40 (in più il file memory.js).
