# giot.ai: installatore 34, Compilazione per persona senza «ragionamenti»

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-latest.sh -o installa-giot-chat.sh && echo "056ee23e5393c793f2de65579762b8ea20a73bf80f91f725e9ce7e4555976ba5  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Cosa cambia
- **Un documento per persona, sempre sull'originale.** Con una foto (proposta, documenti) o con le parti del progetto, il modello si limita a **leggere le persone** (nome, codice fiscale, nascita, ruolo). Il modulo lo compila il motore, persona per persona, sul tuo file originale: stesso titolo, stesso carattere, stessa impaginazione.
- **Niente decisioni al posto tuo.** Se nella foto ci sono più ruoli (venditori, acquirenti), la chat chiede per chi compilare: pulsanti «Venditori (3)», «Acquirenti / proponenti (2)», «Tutti». Non unisce più persone in un unico documento.
- **Seguiti che restano sull'originale.** Frasi come «ridammi i pdf delle 3 persone» o «riprova per gli acquirenti» rifanno i documenti dall'originale. Non lo riscrivono e non cercano sul web.
- **Codice fiscale controllato.** Se il codice di una persona non torna, lo segnala accanto al suo nome.
- **Dati inventati segnalati.** Quando il modello scrive un documento suo, P.IVA, REA, codici fiscali e numeri che non stanno in nessuna tua fonte compaiono in un avviso giallo.
- **PDF puliti.** Le frasi della chat («Ecco il contenuto…», «Premi il pulsante…») non finiscono più nel PDF. Gli spazi per la data «__/__/____» restano intatti.
- Per ogni documento: anteprima, scarica PDF/Word, e il pulsante «Tutti in un unico PDF».
- Se i dati sono scritti nel messaggio (niente foto), si usa la compilazione classica, come prima.

## Collaudi
- Nuovo collaudo per persona: 19/19 (foto con 5 persone fittizie, il vero .doc della dichiarazione, scelta del ruolo, seguiti, codice fiscale errato, P.IVA inventata, PDF pulito).
- Regressione completa: app 92, 45, 36, 40, 37, 8, 14, 9, 22, 16, 19, office 36, compilazione 13, esportazione 10; server 87, 106, 32, 41, 29, 31, 5, 41, 20, 25, 17, chiavi 10. Tutto verde.
- Installatore: stessi risultati del 33 in tutti i casi (chiave dell'archivio mai sostituita).
