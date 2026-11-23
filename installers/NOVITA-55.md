# giot.ai: installatore 55 · Immagini serie: creare e MODIFICARE

## Installazione

```
ssh -i ~/.ssh/navetta ubuntu@158.180.230.0 'cd ~ && curl -fsSL https://raw.githubusercontent.com/Giuseppe210992/Expertadvisor/claude/modest-mayer-c31pbe/installers/installa-giot-chat-55.sh -o installa-giot-chat.sh && echo "964208f1ec51b3be38052cd6a8ed0475d938006e07cfea7480a6af4084a1decb  installa-giot-chat.sh" | sha256sum -c - && bash installa-giot-chat.sh'
```

## Perché prima non si poteva
FreeLLMAPI passa ai generatori solo la descrizione, mai un'immagine. Per «modificare» giot descriveva la foto a parole e ne faceva un'altra da zero: per questo volti e dettagli cambiavano.

## Cosa cambia
- **Studio immagini sul server** (Impostazioni → Immagini). Si collegano generatori che **ricevono l'immagine**; le chiavi restano solo sul server (file 600). Si provano nell'ordine scelto e, se uno non risponde, si passa al successivo. Pronti all'uso:
  - **Pollinations**: chiave gratuita su enter.pollinations.ai; FLUX.2 per creare, FLUX.1 Kontext per modificare, altri modelli a scelta;
  - **Cloudflare Workers AI**: FLUX.2 con immagini di riferimento;
  - **Google Gemini** («Nano Banana»);
  - **xAI Grok Imagine**, **OpenAI** e qualsiasi servizio compatibile OpenAI.

  Senza generatori collegati si crea come prima con FreeLLMAPI.
- **Modifica vera in chat:**
  - foto allegata + «rendi il cielo rosa»: la foto va al generatore e il resto resta com'era;
  - seguito sull'ultima immagine: «di sera», «togli il cane», «più realistica»;
  - **«togli lo sfondo»**: sfondo trasparente in PNG.
- **Suggerimenti con un tocco** sotto l'ultima immagine.
- **Varianti:** «crea tre varianti di…» oppure il pulsante «Varianti». Le immagini arrivano in griglia, con semi diversi.
- **Formati nuovi:** 16:9 (copertine) e 9:16 (storie).
- **Studio a tutto schermo** su ogni immagine (pulsante «Modifica», o un tocco sulla foto allegata):
  - **IA**: scrivi cosa cambiare; se dipingi una zona l'IA cambia **solo lì**, perché il resto viene ricomposto identico al pixel. Scorciatoie: sfondo trasparente, migliora la foto, togli ciò che dipingi, notte, tramonto, acquerello, cartone, foto professionale, estate, neve;
  - **Ritaglia** (libero, 1:1, 4:5, 3:2, 16:9, 9:16), ruota, specchia;
  - **Regola** (luce, contrasto, saturazione, calore, nitidezza, vignettatura) e **filtri**;
  - **Testo** (colori, bordo, fondo, grassetto, posizione con il dito);
  - **Disegna**;
  - **Privacy**: pixel o sfocatura su volti, targhe e documenti;
  - **Dimensioni** (2048, 1600, 1080, 720);
  - Annulla e Ripristina, confronto con l'originale, Scarica (PNG se trasparente), Salva in chat.

## Collaudi
- Server con generatori finti: 18/18.
  - compatibile OpenAI, Cloudflare FLUX.2, Gemini e FreeLLMAPI come riserva;
  - ordine e ripiego, errori comprensibili;
  - chiavi mai restituite e mai nei log, solo il proprietario configura.
- App: 27/27.
  - funzioni controllate pixel per pixel;
  - studio usato con il «dito»;
  - modifica a zona con zero pixel cambiati fuori dalla zona;
  - sfondo trasparente vero;
  - foto modificata davvero in chat, suggerimenti, varianti, impostazioni.
- Prova di base: 92/92. Regressione completa: tutto verde (interfaccia 29 collaudi + 2 varianti, server 23 collaudi).

## Riferimenti studiati su GitHub
- **TOAST UI Image Editor** (MIT) e **Filerobot** (MIT): riferimenti per ritaglio, filtri, testo e strumenti in basso. Rifatti in modo leggero, senza librerie da 1 MB.
- **IOPaint** (Apache-2.0): riferimento per il pennello a maschera. Il suo modello richiede una GPU; qui la zona va al generatore e il resto si ricompone identico.
- **imgly background-removal** (AGPL, modello da più di 40 MB): scartato per la licenza e il peso. Usata invece la tecnica dello schermo verde.
