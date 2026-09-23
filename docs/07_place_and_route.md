# 07 — Place & Route

## 1. Obiettivo

Il processo di Place & Route trasforma la netlist sintetizzata in una implementazione fisica nel processo Sky130.

Il flusso comprende:

```text
Netlist
   |
   v
Floorplanning
   |
   v
Placement
   |
   v
Clock Tree Synthesis
   |
   v
Routing
   |
   v
Post-route optimization
   |
   v
Signoff
Il run documentato in questo capitolo è quello della versione finale del design con FIR a coefficienti fissi e struttura simmetrica.

2. Ambiente di implementazione

Il flusso è stato eseguito con OpenLane utilizzando:

Design:          adc_sd_top
PDK:             sky130A
OpenLane tag:    2024.05.09
OpenLane commit: 14b94a6
Clock period:    195.3125 ns
FP core util:    40 %
PL target density: 0.5

Il run finale è identificato come:

adc_sd_gen_fixedfir
3. Risultato generale

Il flow OpenLane è stato completato con successo:

[SUCCESS]: Flow complete.

Le principali verifiche fisiche hanno dato esito positivo:

Routing violations     0
Magic DRC              0
KLayout DRC            0
LVS errors             0

Non sono state quindi rilevate violazioni DRC o errori LVS nel risultato finale.

4. Area del die

Il die finale presenta:

Die area = 0.2532016388 mm²

Le dimensioni sono ricavabili dal DEF finale:

DIEAREA ( 0 0 ) ( 497860 508580 ) ;

con una scala di 1000 DBU/µm:

Width  = 497.86 µm
Height = 508.58 µm

L'area risultante è:

497.86 × 508.58 µm²
≈ 0.2532 mm²

Questo valore è coerente con quello riportato dal flow OpenLane.

5. Core area

L'area del core riportata dal run è:

235630.9888 µm²

ovvero:

0.235631 mm²

L'utilizzazione finale del core è:

37.4089 %

Il valore OpenDP riportato durante il placement è:

41.19 %

La differenza deriva dalle diverse metriche utilizzate nelle varie fasi del flow.

6. Complessità fisica

Le principali metriche post-route sono:

Metrica	Risultato
Die area	0.2532 mm²
Core area	0.2356 mm²
Final utilization	37.41 %
OpenDP utilization	41.19 %
Total cells	30,197
Wire length	206,356
Vias	60,906
Routing violations	0

La lunghezza complessiva delle connessioni è:

206,356

mentre il numero di vias è:

60,906
7. Confronto con la precedente implementazione

La versione precedente, caratterizzata dalla FIR con coefficienti forniti attraverso un bus programmabile, aveva prodotto:

Die area       = 0.8083 mm²
Core area      = 0.7775 mm²
Total cells    = 104,094
Wire length    = 1,003,442
Vias           = 233,240

La versione finale ha prodotto:

Die area       = 0.2532 mm²
Core area      = 0.2356 mm²
Total cells    = 30,197
Wire length    = 206,356
Vias           = 60,906

La variazione percentuale è:

Metrica	Riduzione
Die area	~68.7 %
Core area	~69.7 %
Total cells	~71.0 %
Wire length	~79.4 %
Vias	~73.9 %

La riduzione fisica è quindi molto significativa.

È importante però attribuirla correttamente: il cambiamento principale tra le due implementazioni è stata la trasformazione della FIR da architettura con coefficienti programmabili a coefficienti fissi, oltre all'utilizzo della simmetria del filtro.

8. Placement

Durante il placement le celle standard vengono distribuite all'interno del core cercando di rispettare:

densità;
vincoli di timing;
connessioni tra celle;
capacità dei segnali;
vincoli geometrici.

Il risultato finale ha mantenuto una densità sufficientemente bassa da consentire il completamento del routing.

9. Clock Tree Synthesis

Il clock del design è:

clk

con periodo:

195.3125 ns

Il flow include Clock Tree Synthesis:

RUN_CTS = 1

Il clock tree viene quindi inserito e ottimizzato prima del routing finale.

10. Routing

Il routing globale e dettagliato è stato completato senza violazioni di routing:

Routing violations = 0

Il runtime complessivo del flow è stato:

0 h 18 min 54 s

di cui:

Routing = 0 h 12 min 7 s

Il tempo di routing costituisce quindi circa il 64 % del runtime complessivo del flow.

11. Confronto dei tempi di implementazione

La precedente implementazione aveva richiesto:

Total runtime  = 3 h 48 min 50 s
Routing        = 2 h 28 min 29 s

La versione finale:

Total runtime  = 0 h 18 min 54 s
Routing        = 0 h 12 min 7 s

La riduzione del tempo complessivo è di circa:

91.7 %

mentre quella del routing è circa:

91.8 %

La forte riduzione della complessità della netlist si riflette quindi anche nei tempi necessari all'implementazione fisica.

12. Timing post-route

Il percorso critico riportato dal risultato finale è:

196.3125 ns

rispetto al periodo richiesto:

195.3125 ns

Tuttavia il valore del percorso critico riportato nei riepiloghi non deve essere interpretato isolatamente come una violazione di timing.

La verifica STA di signoff eseguita sul risultato finale riporta percorsi conformi ai vincoli nelle condizioni analizzate.

Il dettaglio della verifica temporale viene riportato nel capitolo 08_signoff.md.

13. Antenna e verifiche fisiche preliminari

Nel risultato finale sono stati riportati:

Pin antenna violations = 2
Net antenna violations = 2

Questi risultati riguardano controlli di antenna del layout e non hanno prodotto errori DRC/LVS tali da impedire il completamento del flow.

Sono stati inoltre analizzati i dettagli delle reti coinvolte.

Le violazioni osservate sono associate a elementi introdotti nell'implementazione fisica, inclusi buffer e reti interne generate dal backend.

Non è stata modificata l'architettura RTL per questi casi.

14. Milestone

Place & Route — COMPLETATO

Il design è stato:

floorplanned;
posizionato;
sottoposto a CTS;
instradato;
verificato con controlli fisici;
preparato per il signoff.

Risultato principale:

Die area       = 0.2532 mm²
Core area      = 0.2356 mm²
Utilization    = 37.41 %
Routing errors = 0

Il layout finale costituisce la base per la generazione degli artefatti fisici e per le verifiche di signoff.

