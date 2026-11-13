# giot.ai: installatore 31, compilazione dei moduli come nel progetto Tecnocasa

Riprende il metodo dei moduli compilati in claude.ai: si scrive sopra l'originale, quello che non c'è resta vuoto, ogni modulo ha le sue regole fisse e si consegna in PDF.

## Cosa cambia

### 1. Stile di scrittura identico
- Testo **blu scuro (0, 0, 0,55)**, **Helvetica 10,5 pt**. Se non ci sta scende fino a **6 pt**, poi si abbrevia. Le caselle si spuntano con una **X in grassetto**.
- **Niente cancellature**: il testo sta appena sopra la riga, come a penna. I puntini e le righe del modulo restano intatti, e non può più coprire per errore lo stampato accanto.

### 2. Il mio profilo e lo studio (Impostazioni)
Nome, recapiti, qualifica, dati dello studio e il **luogo per "…, lì"** (Scauri). Servono quando **sei tu il delegato** e per i tuoi recapiti. I dati sono cifrati sul server.

### 3. La pratica nel Progetto: parti e immobile
- **Parti con il ruolo**: venditore, acquirente, locatore, conduttore, delegante, dichiarante. Ognuna è una scheda dell'archivio clienti.
- **Immobile e pratica**:
  - immobile: indirizzo, comune, foglio, particella, subalterno, categoria, rendita;
  - destinazione d'uso, **ricavata dalla categoria** (A/3 → residenziale);
  - prezzo e caparra;
  - data e **protocollo della proposta**;
  - **data del rogito**, **nuova data** e **data dell'atto**;
  - notaio e titoli edilizi.

### 4. Più parti nello stesso modulo
"Promittente venditrice ___ nata a ___ il ___ C.F. ___" e "promissaria acquirente ___" si compilano **ognuna con la sua scheda**. Le righe che seguono una parte ereditano quella parte. Una parte senza scheda resta vuota: mai i dati di un'altra persona. Le forme femminili (venditrice, promissaria, delegata…) sono riconosciute.

### 5. Il delegato sei tu
"Il delegato ___ Telefono ___ Email ___" prende nome e recapiti dal tuo profilo. Gli spazi sulla stessa riga appartengono a quella parte.

### 6. Valori fissi per ogni modello (📌)
Accanto a ogni spazio c'è **📌 fissa**: "DELEGATO", "VENDITA" e simili vengono scritti sempre lì e ricordati nel modello della libreria. Dal cliente successivo sono già al loro posto.

### 7. Dati mancanti più chiari
Ogni dato mancante indica **dove** va inserito: scheda del cliente, pratica del progetto o tuo profilo.

## Collaudi (dati fittizi, moduli costruiti sul modello dei tuoi)
- **Proroga di proposta**: due parti, date di proposta e rogito, "Scauri, lì". **Accesso agli atti**: immobile, destinazione, delegato, valori fissi. App 16/16, con controllo visivo della pagina.
- Motore: 17/17 casi nuovi, 25/25 casi precedenti. Server (profilo, valori fissi): 41/41.
- Regressione completa dell'app e del server: tutto verde. Controllo indipendente dei PDF e dei Word con pypdf e python-docx: 18/18.

## Cosa provare
1. Impostazioni → **Il mio profilo e lo studio**: compila e salva.
2. Apri un Progetto → **Pratica: parti e immobile**: aggiungi venditore e acquirente, poi i dati dell'immobile.
3. **Compila un modulo** dal progetto con la tua proroga o l'accesso agli atti. Fissa con 📌 i valori sempre uguali e salva il modulo nella libreria.

## Prossimo passo
Mandami i **moduli reali**: adeguata verifica, privacy, Modulo B Acqualatina, dichiarazione di residenza, accesso agli atti, proroga. Li calibro uno per uno con le loro regole fisse, come nel progetto Tecnocasa, e li carico già pronti nella libreria.
