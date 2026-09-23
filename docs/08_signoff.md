# 08 — Signoff

## 1. Obiettivo

Il signoff rappresenta la fase finale della verifica dell'implementazione fisica prima della conservazione degli artefatti di layout.

Sono stati verificati:

- timing statico;
- setup e hold;
- slew;
- fanout;
- capacità;
- DRC;
- LVS;
- antenna;
- generazione degli artefatti fisici finali.

Il risultato documentato in questo capitolo riguarda il run:

```text
adc_sd_gen_fixedfir
2. Stato generale del signoff

Il flow OpenLane è terminato con successo.

I principali controlli fisici hanno prodotto:

Magic DRC       = 0
KLayout DRC     = 0
LVS errors      = 0
Routing errors  = 0

Il layout è quindi risultato coerente con le regole geometriche verificate e con la netlist di riferimento nei controlli eseguiti.

3. Static Timing Analysis

La verifica temporale è stata eseguita con Static Timing Analysis (STA).

Il clock del progetto è:

Fs_mod = 5.12 MHz
Tclk   = 195.3125 ns

Nel report di signoff:

multi_corner_sta.max.rpt

i percorsi analizzati risultano conformi ai vincoli temporali nelle condizioni considerate.

Il peggior slack riportato nei percorsi analizzati è positivo:

Worst shown slack ≈ +144.22 ns

Questo corrisponde a un ritardo del percorso di circa:

195.3125 ns - 144.22 ns
≈ 51.09 ns

Il risultato indica quindi un margine temporale positivo per il percorso peggiore riportato nel report di signoff.

4. Setup e hold

Le verifiche STA finali non hanno riportato violazioni di setup o hold nelle condizioni di signoff considerate.

Stato:

Setup violations = 0
Hold violations  = 0

Questo risultato è importante perché conferma che la netlist post-route soddisfa i vincoli temporali utilizzati dal flow.

5. Slew

Il controllo di slew ha evidenziato alcune violazioni nelle condizioni Slowest.

I valori osservati sono prossimi al limite imposto dal flow.

Il limite utilizzato è:

Max slew = 0.75

Sono stati osservati valori fino a circa:

0.84

corrispondenti a una violazione massima di circa:

0.84 - 0.75 = 0.09

Sono presenti inoltre violazioni intermedie nell'intervallo:

0.76 ... 0.82

Le violazioni sono state osservate esclusivamente nel corner Slowest.

Nei corner Fastest e Typical non sono state osservate violazioni di slew nel report considerato.

6. Fanout

Il controllo del fanout ha mostrato una singola condizione oltre il limite:

Fanout limit = 10
Observed fanout = 11

Il segnale interessato appartiene alla logica interna generata dal backend.

L'elemento individuato è:

_15302_ = sky130_fd_sc_hd__buf_2

e non corrisponde a una porta di interfaccia dell'ADC.

Il controllo non ha impedito il completamento del flow e non sono state introdotte modifiche RTL specifiche per questo caso.

7. Capacità

Il controllo della capacità non ha riportato violazioni nei corner analizzati.

Stato:

Max capacitance violations = 0
8. DRC

Il layout finale è stato sottoposto a Design Rule Check utilizzando:

Magic;
KLayout.

Risultati:

Magic DRC   = 0
KLayout DRC = 0

È stata inoltre verificata la corrispondenza tra i risultati ottenuti dai differenti strumenti.

Il risultato del controllo geometrico è quindi pulito per i DRC eseguiti.

9. LVS

La verifica Layout Versus Schematic/netlist ha prodotto:

LVS errors = 0

Questo significa che la connettività estratta dal layout risulta coerente con la netlist utilizzata come riferimento per il signoff.

L'LVS clean costituisce una verifica fondamentale della corrispondenza tra implementazione fisica e circuito logico sintetizzato.

10. Antenna

Il report finale ha riportato:

Pin antenna violations = 2
Net antenna violations = 2

Sono stati analizzati i due casi.

Uno riguarda una rete interna associata a:

u_cic.dout[2]

con connessione verso una cella:

sky130_fd_sc_hd__mux2_1

L'altro riguarda una rete collegata a un'uscita:

output2

attraverso:

sky130_fd_sc_hd__clkbuf_4

Queste condizioni sono state individuate nei controlli di antenna del backend e non hanno prodotto errori DRC/LVS che impedissero il completamento del flow.

Per il momento non è stata modificata l'architettura RTL per correggere questi casi, in quanto il loro trattamento deve essere valutato nel contesto dell'integrazione finale e delle regole specifiche del target di tapeout.

11. Artefatti fisici finali

Il run ha prodotto gli artefatti necessari per conservare il risultato dell'implementazione fisica.

Tra quelli archiviati nel repository sono presenti:

results/physical/adc_sd_top.gds
results/physical/adc_sd_top_signoff.gds
results/physical/adc_sd_top.lef
results/physical/adc_sd_top.def
results/physical/adc_sd_top_postroute.v
results/physical/adc_sd_top_postroute_nl.v

Questi file rappresentano rispettivamente:

GDSII del layout;
GDSII prodotto/validato durante il signoff;
LEF della macro;
DEF del layout;
netlist post-route;
netlist post-route non elaborata.

Gli artefatti intermedi completi del flow OpenLane non vengono inclusi nel repository per evitare di trasformare il repository in un archivio di file temporanei.

12. Dimensioni fisiche

Il layout finale presenta:

Width  = 497.86 µm
Height = 508.58 µm
Area   ≈ 0.2532 mm²

Questi valori sono coerenti tra DEF e metriche del flow.

13. Timing e frequenza

Il clock nominale del design è:

5.12 MHz

con periodo:

195.3125 ns

Il report del flow riporta inoltre una frequenza suggerita di circa:

5.094 MHz

associata al percorso critico indicato dal riepilogo.

Questo valore deve essere interpretato insieme al report STA dettagliato e non sostituisce la verifica dei vincoli temporali di signoff.

14. Risultato complessivo

Il risultato finale può essere riassunto come segue:

Verifica	Risultato
RTL simulation	PASS
Synthesis	PASS
Placement	PASS
Clock Tree Synthesis	PASS
Routing	PASS
Routing violations	0
Setup violations	0
Hold violations	0
Magic DRC	0
KLayout DRC	0
LVS errors	0
Antenna	2 pin / 2 net riportate
Die area	0.2532 mm²

Le verifiche principali di integrità logica, temporale e geometrica sono quindi state completate con esito positivo, con le eccezioni relative ai controlli di slew/fanout/antenna sopra documentate.

15. Significato del risultato

A questo punto il progetto dispone di un blocco digitale:

RTL
 |
 v
Synthesis
 |
 v
Place & Route
 |
 v
STA
 |
 v
DRC
 |
 v
LVS
 |
 v
GDS

completamente attraversato dal flusso di implementazione Sky130/OpenLane.

Questo costituisce una milestone significativa del progetto di tesi.

È però importante distinguere questa milestone dalla disponibilità immediata per un tapeout TinyTapeout.

Il GDS attuale è stato generato con il flusso OpenLane utilizzato per questo progetto. La compatibilità con il flusso TinyTapeout, il relativo wrapper, la configurazione del progetto e le specifiche dello shuttle devono ancora essere verificate separatamente.

16. Milestone

Physical Signoff — COMPLETATO

Il blocco adc_sd_top dispone ora di:

netlist sintetizzata;
layout post-route;
timing signoff;
DRC verificato;
LVS verificato;
GDS;
LEF;
DEF;
netlist post-route.

La successiva attività è l'analisi dell'integrazione TinyTapeout.

