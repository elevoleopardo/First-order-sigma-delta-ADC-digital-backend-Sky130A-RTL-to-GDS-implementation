# 09 — TinyTapeout Integration

## 1. Obiettivo

Il progetto è stato sviluppato mantenendo aperta la possibilità di una successiva integrazione in TinyTapeout.

La milestone attuale consiste nella realizzazione e verifica di un blocco digitale completo:

```text
Golden model
     |
     v
RTL
     |
     v
RTL verification
     |
     v
Synthesis
     |
     v
Place & Route
     |
     v
Signoff
     |
     v
GDS
L'implementazione fisica adc_sd_top è quindi già disponibile.

L'integrazione TinyTapeout costituisce invece una fase successiva e distinta.

2. Stato attuale

Lo stato del progetto può essere riassunto come:

ADC sigma-delta digitale
        |
        +-- Golden model          COMPLETATO
        |
        +-- RTL                  COMPLETATO
        |
        +-- RTL verification     COMPLETATO
        |
        +-- Synthesis            COMPLETATO
        |
        +-- Place & Route        COMPLETATO
        |
        +-- DRC                  COMPLETATO
        |
        +-- LVS                  COMPLETATO
        |
        +-- GDS                  DISPONIBILE
        |
        +-- TinyTapeout wrapper  DA IMPLEMENTARE
        |
        +-- TT flow              DA VERIFICARE
        |
        +-- Shuttle submission   NON ANCORA ESEGUITA

Questa distinzione è importante: il risultato attuale è un blocco Sky130 fisicamente implementato, non ancora una submission TinyTapeout completata.

3. Interfaccia attuale

Il top-level attuale è:

adc_sd_top

con interfaccia:

clk
rst_n
din
dout[15:0]
dout_valid

L'interfaccia è stata mantenuta volutamente semplice.

Il blocco non richiede:

bus di configurazione;
caricamento runtime dei coefficienti;
registri di controllo;
memoria esterna;
interfaccia seriale.

I coefficienti della FIR sono infatti costanti all'interno dell'implementazione.

4. Differenza rispetto all'interfaccia TinyTapeout

TinyTapeout utilizza un'interfaccia standardizzata per i progetti digitali.

La struttura generale prevede:

clk
rst_n
ui_in[7:0]
uo_out[7:0]
uio_in[7:0]
uio_out[7:0]
uio_oe[7:0]

e un top-level con nome compatibile con il formato TinyTapeout, tipicamente:

tt_um_<project_name>

Il blocco adc_sd_top non utilizza direttamente questa interfaccia.

È quindi necessario realizzare un wrapper.

5. Wrapper previsto

L'integrazione può essere strutturata come:

              TinyTapeout
                  |
        +--------------------+
        | tt_um_adc_sd       |
        |                    |
clk --->|                    |
rst_n ->|                    |
ui_in ->|                    |
uo_out<-|                    |
        |       |            |
        |       v            |
        |  adc_sd_top        |
        |                    |
        +--------------------+

Il wrapper avrà il compito di collegare l'interfaccia standard TinyTapeout al core già verificato.

Il principio fondamentale sarà evitare di modificare inutilmente il core adc_sd_top.

6. Possibile mappatura dei segnali

Una possibile configurazione è:

TinyTapeout ui_in[0]  -> din
TinyTapeout ui_in[1]  -> eventuale controllo/reset locale
TinyTapeout uo_out[7:0] -> parte dell'uscita

Poiché il convertitore produce:

dout[15:0]

mentre l'interfaccia TinyTapeout dispone di 8 output digitali, sarà necessario definire una strategia di trasferimento dell'uscita a 16 bit.

Le possibilità comprendono, ad esempio:

Metodo A:
8 bit per volta attraverso un multiplexer controllato da ui_in

Metodo B:
uscita serializzata attraverso un protocollo digitale

Metodo C:
utilizzo dei GPIO bidirezionali quando appropriato

La scelta definitiva deve essere fatta in funzione delle specifiche dello shuttle e degli obiettivi della demo.

Non viene assunta una soluzione definitiva in questa fase.

7. Clock

Il clock interno previsto dal progetto è:

Fs_mod = 5.12 MHz

corrispondente a:

Tclk = 195.3125 ns

Il wrapper TinyTapeout dovrà quindi utilizzare il clock fornito dal framework come clock del core oppure prevedere esplicitamente un'eventuale divisione/mappatura.

Non è necessario introdurre una PLL per il funzionamento digitale del core.

8. Reset

Il core utilizza:

rst_n

come reset attivo basso.

Il wrapper dovrà quindi mantenere coerente la polarità del reset con quella utilizzata dal core.

La logica di reset non deve modificare il comportamento verificato nella simulazione RTL.

9. Dimensione fisica

Il risultato OpenLane attuale ha dimensioni:

Width  = 497.86 µm
Height = 508.58 µm
Area   ≈ 0.2532 mm²

Questo significa che il blocco non è una piccola macro 1×2 o 2×2 standard.

L'integrazione TinyTapeout deve quindi considerare il footprint fisico effettivo del progetto e il tile size disponibile nello shuttle scelto.

TinyTapeout supporta configurazioni di progetto con dimensioni superiori al footprint minimo; la disponibilità effettiva dipende dallo shuttle e dalla configurazione utilizzata.

Non viene quindi fissata in questo documento una dimensione definitiva del tile senza prima verificare la configurazione dello shuttle target.

10. Layer metallici

Un punto importante per l'integrazione è la compatibilità tra il risultato OpenLane e le regole di integrazione TinyTapeout.

Il GDS finale è stato analizzato per identificare i layer presenti.

Tra i layer Sky130 individuati sono presenti:

met1
met2
met3
met4
met5

La presenza del layer associato a met5 richiede una verifica specifica prima di considerare il GDS direttamente integrabile in TinyTapeout.

Questo è importante perché le regole TinyTapeout per i progetti analogici/digitali possono imporre restrizioni sui layer metallici utilizzabili, in particolare in relazione alla power grid dello shuttle.

Pertanto:

GDS attuale
    |
    +-- DRC Sky130/OpenLane       PASS
    |
    +-- LVS Sky130/OpenLane       PASS
    |
    +-- Compatibilità TT          DA VERIFICARE

Il fatto che il GDS superi DRC e LVS nel flow OpenLane non implica automaticamente la compatibilità con il flusso TinyTapeout.

11. Wrapper e integrazione

La prossima implementazione necessaria sarà un progetto TinyTapeout separato dal core.

La struttura prevista sarà indicativamente:

tt_um_adc_sd/
|
+-- src/
|   +-- tt_um_adc_sd.v
|   +-- adc_sd_top.v
|   +-- cic_decimator.v
|   +-- fir_comp.v
|
+-- info.yaml
|
+-- config/
|
+-- docs/
|
+-- test/
|
+-- gds/

La struttura effettiva dovrà seguire il template e il flusso TinyTapeout dello shuttle selezionato.

Il core già verificato dovrebbe essere riutilizzato senza modifiche funzionali.

12. Strategia di integrazione

L'integrazione dovrebbe essere eseguita in ordine:

1. selezione dello shuttle TinyTapeout
             |
             v
2. recupero del template ufficiale
             |
             v
3. creazione del wrapper
             |
             v
4. adattamento dell'interfaccia GPIO
             |
             v
5. simulazione wrapper + core
             |
             v
6. verifica synthesis
             |
             v
7. verifica floorplan
             |
             v
8. verifica routing
             |
             v
9. verifica DRC/LVS
             |
             v
10. verifica GDS finale

Solo dopo questi passaggi sarà possibile considerare il progetto effettivamente pronto per una eventuale submission.

13. Separazione tra core e integrazione

Una scelta progettuale importante è mantenere separati:

CORE
adc_sd_top

e:

INTEGRATION
tt_um_adc_sd

Il core rappresenta l'implementazione dell'ADC.

Il wrapper rappresenta invece l'adattamento alle specifiche del sistema TinyTapeout.

Questa separazione permette di:

mantenere stabile il core verificato;
riutilizzare l'RTL;
semplificare il debug;
modificare l'interfaccia senza alterare l'algoritmo;
mantenere una chiara distinzione tra risultato della tesi e integrazione del tapeout.
14. Stato della compatibilità
Elemento	Stato
Core RTL	COMPLETATO
RTL verification	COMPLETATA
Sky130 synthesis	COMPLETATA
Sky130 P&R	COMPLETATO
Sky130 DRC	PASS
Sky130 LVS	PASS
GDS core	DISPONIBILE
TinyTapeout wrapper	DA IMPLEMENTARE
TinyTapeout GPIO mapping	DA DEFINIRE
TinyTapeout tile size	DA DEFINIRE
TinyTapeout flow	DA ESEGUIRE
TT-specific DRC/LVS	DA ESEGUIRE
Submission	NON ESEGUITA
15. Criterio di successo

Il progetto può essere considerato completo dal punto di vista della tesi anche senza una submission TinyTapeout.

La milestone già raggiunta comprende infatti:

specifiche
    |
golden model
    |
RTL
    |
RTL verification
    |
synthesis
    |
place & route
    |
STA
    |
DRC
    |
LVS
    |
GDS

L'eventuale tapeout rappresenta una fase successiva di integrazione e validazione del blocco.

Questo permette di mantenere un risultato sperimentale completo anche nel caso in cui la submission TinyTapeout non venga effettuata entro la scadenza del progetto.

16. Milestone

TinyTapeout preparation — ANALISI COMPLETATA

Il progetto è stato preparato per una successiva integrazione TinyTapeout.

Sono stati identificati i principali punti di integrazione:

wrapper;
GPIO;
uscita a 16 bit;
clock;
reset;
dimensionamento fisico;
compatibilità dei layer;
verifica del flow TinyTapeout.

La realizzazione del wrapper e la verifica attraverso il flow TinyTapeout costituiscono il prossimo livello di sviluppo.

