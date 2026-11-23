# giot.ai: installatore 58 · Idee prese da AI-Image-Editing-Tools

## Installazione

Comando e impronta sha256 nel messaggio di consegna (file `installa-giot-chat-58.sh`).

## Cosa ho letto
L'elenco [danielrosehill/AI-Image-Editing-Tools](https://github.com/danielrosehill/AI-Image-Editing-Tools) raccoglie 19 strumenti per modificare immagini con agenti IA.
- Quasi tutti sono plugin per Claude Code o server MCP che chiamano servizi **a pagamento**: OpenAI gpt-image, Gemini «Nano Banana» (via API costa circa 4-15 centesimi a immagine e la quota gratuita è zero o quasi), muapi, Higgsfield.
- imagesorcery-mcp trova gli oggetti con modelli YOLO in Python: è troppo pesante per il server da 1 GB. giot fa la stessa cosa con Gemini, che è già disponibile e gratuito.
- Da nano-banana-2-skill ho preso il metodo per lo sfondo trasparente.
- ImageMagick non serve: le modifiche si fanno già nel telefono.

## Cosa cambia
- **«Togli lo sfondo» non rovina più le parti verdi del soggetto.** Prima la pulizia dal verde agiva su tutta l'immagine, quindi una maglietta verde o una pianta diventavano grigie o trasparenti. Ora, come in nano-banana-2-skill:
  - il colore del verde si legge dai bordi, perché l'IA non usa mai il verde puro esatto;
  - si toglie solo lo sfondo collegato al bordo, più gli spazi chiusi dello stesso identico verde (per esempio tra braccio e corpo);
  - la pulizia dall'alone verde si fa solo sui contorni.
- **Stesse proporzioni della foto.** Se il generatore restituisce un'immagine di forma diversa (quadrata o allungata, come nel tuo screenshot dell'accendino), giot la riporta alle proporzioni della foto originale, ritagliando al centro e senza deformarla.

## Collaudi
- Studio immagini 29/29, con due controlli nuovi:
  - verde «quasi puro» tolto, mentre la parte verde scuro del soggetto resta verde e piena;
  - immagine quadrata riportata a 4:3 senza deformazioni.
- Tutti i collaudi precedenti ripetuti.
