# 05 — RTL Verification

## 1. Obiettivo

La verifica RTL ha lo scopo di dimostrare che l'implementazione Verilog dell'ADC sigma-delta digitale riproduce correttamente il comportamento del golden model Python.

Il confronto viene effettuato campione per campione tra:

- uscita del modello di riferimento;
- uscita prodotta dalla simulazione RTL;
- valori attesi contenuti nel golden output.

L'obiettivo è verificare non soltanto la funzionalità generale della catena, ma anche la corrispondenza numerica dell'implementazione hardware con il modello di riferimento.

---

## 2. Ambiente di simulazione

La simulazione RTL è stata eseguita utilizzando:

- simulatore: Icarus Verilog;
- linguaggio: SystemVerilog/Verilog compatibile con `-g2012`;
- testbench: `tb_adc_sd.v`;
- design top-level: `adc_sd_top`;
- blocchi verificati:
  - `cic_decimator`;
  - `fir_comp`;
  - `adc_sd_top`.

Il testbench utilizza il bitstream generato dal golden model come ingresso digitale al modulatore/decimatore RTL e confronta l'uscita ottenuta con il golden output.

---

## 3. Catena verificata

La catena verificata è:

```text
bitstream 1-bit
     |
     v
+----------------+
| CIC decimator  |
| sinc^3 / 64    |
+----------------+
     |
     | 19 bit
     v
+----------------+
| FIR compensation|
| 15 taps, /2    |
+----------------+
     |
     | 16 bit
     v
  dout
La decimazione complessiva è:

64 × 2 = 128

in accordo con l'OSR di progetto.

4. Golden model

Il golden model Python costituisce il riferimento numerico.

Il modello genera:

il segnale di ingresso;
la modulazione sigma-delta di primo ordine;
il bitstream a 1 bit;
la decimazione CIC;
la compensazione FIR;
il golden output finale.

I risultati vengono salvati nella directory output/ del progetto originale.

Tra i file utilizzati nella verifica sono presenti:

bitstream.txt
fir_coef.txt
golden_out.txt

Il modello rappresenta quindi il riferimento rispetto al quale viene verificato l'RTL.

5. Testbench

Il testbench applica al DUT il bitstream prodotto dal modello e acquisisce le uscite valide del blocco adc_sd_top.

La validazione considera solamente i campioni per i quali dout_valid è attivo.

Questo permette di ignorare i cicli nei quali la catena di decimazione non produce un nuovo campione di uscita.

Il confronto viene eseguito sui campioni validi in corrispondenza con quelli presenti nel golden output.

6. Verifica della FIR a coefficienti fissi

Durante lo sviluppo è stata modificata l'architettura della FIR.

La versione iniziale prevedeva un bus per il caricamento dei coefficienti.

La versione finale utilizza invece coefficienti costanti sintetizzabili direttamente nell'RTL:

H0 = -3
H1 = -6
H2 = -14
H3 = -29
H4 = -51
H5 = -74
H6 = -93
H7 = 2047

I coefficienti sono simmetrici:

H[k] = H[14-k]

La struttura finale utilizza quindi la simmetria del filtro per ridurre il numero di prodotti da 15 a 8.

La modifica è stata verificata nuovamente a livello RTL.

7. Risultato della simulazione

La simulazione della versione finale con FIR simmetrica e coefficienti fissi ha prodotto:

=== RISULTATO CONFRONTO RTL vs GOLDEN ===
campioni uscita: 8000 (attesi 4160)
errore max: 0 LSB
mismatch (>2 LSB): 0
PASS

Il numero di campioni prodotti dalla simulazione è superiore al numero di campioni necessari al confronto perché il testbench continua l'esecuzione oltre il numero di campioni attesi.

Ai fini della verifica vengono considerati i primi campioni validi corrispondenti al golden output.

Il risultato significativo è:

errore massimo = 0 LSB
mismatch > 2 LSB = 0

Pertanto l'uscita RTL coincide numericamente con il golden output sui campioni confrontati.

8. Significato del risultato

L'assenza di errore numerico nel confronto dimostra che, nelle condizioni di test considerate:

la mappatura del bitstream è corretta;
la decimazione CIC è corretta;
il dimensionamento a 19 bit è coerente;
la FIR produce gli stessi risultati del modello;
la quantizzazione dei coefficienti è coerente;
la scalatura dell'uscita è coerente;
la saturazione produce risultati compatibili;
la modifica alla struttura simmetrica della FIR non introduce differenze rispetto al riferimento.

La verifica non dimostra tuttavia la correttezza assoluta per ogni possibile ingresso. Essa dimostra la corrispondenza con il golden model per il vettore di test utilizzato.

9. Verifiche strutturali precedenti alla simulazione

Prima della verifica numerica sono stati risolti alcuni problemi emersi durante la sintesi.

9.1 FIR — conflitto tra blocking e non-blocking assignment

La prima implementazione della FIR utilizzava assegnamenti di tipo diverso sulla stessa variabile acc.

Questo ha prodotto un errore di lint/sintesi:

BLKANDNBLK

La logica è stata riorganizzata in modo che l'accumulatore venga gestito coerentemente all'interno del processo combinatorio.

9.2 CIC — variabili di loop

Durante la sintesi sono stati rilevati driver multipli associati alle variabili utilizzate nei loop.

La soluzione è stata separare le variabili di iterazione:

integer i;
integer j;

utilizzando variabili distinte per i loop combinatori e sequenziali.

La modifica ha permesso alla sintesi di completare correttamente.

10. Riproducibilità

La verifica deve poter essere ripetuta senza modificare i sorgenti originali del progetto.

Il repository contiene i sorgenti RTL e il testbench utilizzati come base della verifica.

Gli artefatti temporanei di simulazione, come i file .vvp e i log generati durante i test, non costituiscono parte necessaria del design hardware e possono essere rigenerati.

11. Stato della verifica RTL

Stato attuale:

RTL compilation       PASS
RTL simulation        PASS
RTL vs golden         PASS
Maximum error         0 LSB
Mismatches            0

La verifica funzionale RTL costituisce il passaggio che precede la sintesi e la successiva implementazione fisica nel flusso Sky130.

12. Milestone

RTL Verification — COMPLETATA

La versione RTL con:

CIC sinc^3 /64;
FIR 15 tap;
decimazione FIR /2;
coefficienti FIR fissi;
FIR simmetrica;

è stata verificata contro il golden model con errore massimo pari a 0 LSB sui campioni confrontati.

