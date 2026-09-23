# 06 — Synthesis

## 1. Obiettivo

La sintesi costituisce il passaggio dalla descrizione RTL alla rappresentazione a livello di porte logiche utilizzando le celle della libreria standard-cell Sky130.

L'obiettivo è verificare che il design sia sintetizzabile e valutare:

- numero di celle;
- area logica;
- struttura della netlist;
- complessità dell'implementazione;
- comportamento temporale preliminare.

La sintesi è stata eseguita nell'ambito del flusso OpenLane utilizzando il PDK `sky130A`.

---

## 2. Ambiente

Configurazione utilizzata:

```text
PDK              sky130A
Flow              OpenLane
Design            adc_sd_top
Clock             clk
Clock period      195.3125 ns
Clock frequency   5.12 MHz nominali
Il periodo di clock deriva dalla frequenza del modulatore sigma-delta:

Fs_mod = 5.12 MHz

quindi:

Tclk = 1 / 5.12 MHz
     = 195.3125 ns
3. Configurazione del design

Il top-level sintetizzato è:

adc_sd_top

con interfaccia:

clk
rst_n
din
dout[15:0]
dout_valid

La FIR utilizza coefficienti fissi interni al circuito.

Non è quindi presente un bus di configurazione per il caricamento dei coefficienti durante il funzionamento.

Questa scelta riduce significativamente la logica necessaria per implementare e instradare il filtro.

4. Gerarchia sintetizzata

La struttura RTL sintetizzata è:

adc_sd_top
|
+-- cic_decimator
|
+-- fir_comp

Il CIC implementa:

3 integratori
    |
decimazione /64
    |
3 comb

La FIR implementa:

15 tap
decimazione /2
coefficienti fissi
simmetria dei coefficienti
5. Risultati della sintesi

Per la versione finale con coefficienti FIR fissi sono state ottenute:

Synthesized cells:    9,315
Total cells:         30,197

Il numero di celle sintetizzate rappresenta una forte riduzione rispetto alla versione precedente nella quale i coefficienti erano forniti attraverso un'interfaccia programmabile.

6. Confronto con la versione precedente

La versione precedente utilizzava un bus:

coeffs_flat

per trasferire i coefficienti della FIR.

Questa architettura introduceva una quantità significativa di logica associata alla gestione del bus e dei dati dei coefficienti.

Il confronto tra le due implementazioni è:

Metrica	Versione precedente	Versione finale
Celle sintetizzate	33,210	9,315
Celle totali	104,094	30,197
Area die finale	0.8083 mm²	0.2532 mm²
Wire length	1,003,442	206,356
Vias	233,240	60,906

La riduzione delle celle sintetizzate è:

(33210 - 9315) / 33210 ≈ 71.9 %

La riduzione delle celle totali è:

(104094 - 30197) / 104094 ≈ 71.0 %

Questi risultati mostrano l'effetto particolarmente significativo della scelta di rendere i coefficienti costanti e di sfruttare la simmetria della FIR.

7. Motivazione della riduzione di area

La riduzione non deriva esclusivamente dalla diminuzione del numero di moltiplicazioni.

Sono stati eliminati anche elementi necessari all'architettura programmabile precedente, tra cui la logica associata al percorso dei coefficienti.

La FIR finale sfrutta inoltre la simmetria:

h[k] = h[14-k]

per trasformare la convoluzione da 15 prodotti indipendenti a 8 prodotti:

15 prodotti
    |
    v
8 prodotti

con le somme delle coppie di campioni effettuate prima della moltiplicazione.

Questa trasformazione riduce la complessità aritmetica della FIR.

8. Sintesi e verifica del design

La sintesi della versione finale è stata completata con successo.

Il risultato della sintesi è stato successivamente utilizzato dal flusso OpenLane per:

Floorplanning
Placement
Clock Tree Synthesis
Routing
Signoff

La sintesi costituisce quindi il punto di collegamento tra la verifica RTL e l'implementazione fisica.

9. Timing

Il clock richiesto dal progetto è:

Tclk = 195.3125 ns

Il percorso critico riportato nel risultato finale ha una durata di circa:

196.3125 ns

Il valore è vicino al periodo di clock richiesto e costituisce un punto da tenere sotto osservazione.

Nel run finale di signoff, tuttavia, le verifiche STA riportano percorsi conformi ai vincoli temporali nelle condizioni analizzate.

Il dettaglio del timing viene documentato nel capitolo dedicato al signoff.

10. Importanza della sintesi nel progetto

La sintesi ha fornito una prima misura concreta della complessità hardware dell'ADC digitale.

Il risultato finale dimostra che il design:

è sintetizzabile con Sky130;
può essere implementato utilizzando celle standard;
ha una complessità significativamente inferiore rispetto alla prima architettura;
può procedere al place and route;
mantiene un'interfaccia RTL estremamente semplice.
11. Milestone

Synthesis — COMPLETATA

La versione finale del design è stata sintetizzata con successo utilizzando il flusso Sky130/OpenLane.

Risultato principale:

9,315 synthesized cells
30,197 total cells

La sintesi costituisce la base per la successiva implementazione fisica.

