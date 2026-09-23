#!/usr/bin/env python3
"""
Golden model - ADC Sigma - Delta 1 ordine + catena di decimazione (CIC + FIR)

Scopo (Fase 1 della tesi):
	1. Modellare il modulatore Sigma-Delta del 1 ordine a tempo discreto
	2. Generare la bitstream a 1 bit (stimolo/golden per l'RTL) -> bitstream.txt
	3. Modellare la catena di decimazione digitale (CIC sinc^N + FIR compensatore)
	   con la STESSA aritmetica interna che verra poi implementata in Verilog,
	   così da avere un vero "golden model" bit-accurate del blocco digitale
	4. Misurare SNR / ENOB reali -> alimentano il capitolato (docs/PRS)

Dipendenze: numpy, scipy, matplotlib (presenti in ambiente)
"""

import numpy as np
from pathlib import Path

# ------------------------------------------------------------------------------
# PARAMETRI DI PROGETTO (Fase 0 -> derivano nel capitolato)
# ------------------------------------------------------------------------------
class Params:
	# --- Specifiche ADC ---
	BW	= 20e3		# banda utile del segnale [Hz] (audio)
	OSR	= 128		# oversampling ratio
	FS_OUT	= 2 * BW	# freq di Nyquist di uscita = 40 kHz
	FS_MOD	= OSR * FS_OUT	# freq di  clock del modulatore = 5.12 MHz

	# --- Modulatore ---
	ORDER_MOD = 1		# 1 ordine
	QUANT_BITS = 1		# quantizzatore/DAC a 1 bit
	VREF	= 1.0		# riferimento normalizzato (+- VREF)

	# --- filtro di decimazione ---
	# CIC: numero di stadi N. Regola classica per Sigma-Delta di ordine L:
	# N >= L + 1. Con L=1 -> N>=2. Usiamo N=3 (sinc^3) per più attenuazione.
	CIC_STAGES = 3		# N (sinc^N)
	# Decimazione a due stadi (evita noise-folding, vedi relazione Sprint 2):
	# CIC decima di R, poi il FIR decima di FIR_DECIM. R * FIR_DECIM = OSR.
	FIR_DECIM	= 2			#decimazione del FIR compensatore
	CIC_R		= OSR // FIR_DECIM	# = 64 -> lascia Nyquist = 2*BW
	CIC_M		= 1			# differential delay (tipicamente 1)

	# FIR compensatore di droop (half-band-like), coefficienti fissati sotto
	# Serve a correggere la caduta in banda del CIC (droop) e affinare la transizione. Opera a Fs_out (dopo il CIC)

	# --- Aritmetica interna (bit-accurate col Verilog) ---
	# Bit-growth del CIC: B_out = cell(N*log2(R*M)) + B_in
	# con B_in = 1 (ingresso +-1) -> lo calcoliamo a Runtime
	OUT_BITS = 16			# worldlength dell'uscita finale (dopo scaling/round)

	# --- Simulazione ---
	F_SIG	= 1e3	# frequenza tono di test [Hz] (in banda)
	AMP	= 0.5	# ampiezza tono (frazione di VREF), headroom per stabilità
	N_OUT	= 4096	# numero di campioni di USCITA desiderati (post-decim)

P = Params

# ------------------------------------------------------------------------------
# 1) MODULATORE SIGMA-DELTA 1 ORDINE
# ------------------------------------------------------------------------------
def sigma_delta_mod(x):
	"""
	Modulatore SigmaDelta del 1 ordine (tempo discreto, CIFB semplificato):
	Integratore: w[n] = w[n-1] + (x[n] - y[n-1])
	Quantizzatore: y[n] = +1 se w[n] >= 0 altrimenti -1 (1bit)
	DAC in retroazione: y[n] stesso (bipolare +-1)
	x: array float in [-1, 1]
	ritorna: bitstream y in {-1, +1}, e la versione a bit {0,1}
	"""
	n = len(x)
	y = np.empty(n)
	w = 0.0		# stato integratore
	y_prev = 0.0	# DAC feedback iniziale
	for i in range(n):
		w = w + (x[i] - y_prev)		# integratore sulla differenza
		yi = 1.0 if w >= 0.0 else -1.0	# quantizzatore 1 bit
		y[i] = yi
		y_prev = yi			# DAC 1 bit (ideale)
	bits = (y > 0).astype(np.uint8)		# mappa {-1,+1} -> {0,1}
	return y, bits

# ------------------------------------------------------------------------------
# 2) FILTRO CIC (sinc^N) - implementazione intera bit-accurate
# ------------------------------------------------------------------------------
def cic_decimate(bits, stages=P.CIC_STAGES, R=P.CIC_R, M=P.CIC_M):
	"""
	CIC: decimatore: N integratori @Fs_mod -> down-sample per R -> comb @Fs_out
	Ingresso: bits {0,1}. Lo mappiamo a {-1,+1} (segnale bipolare) come nel DAC
	Usa interi Python (precisione arbitraria) ma emula il wrap-around a W = N*log2(R*M) + B_in bit tramite mascheramento two's complement
	esattamente come farebbe l'hardware (gli integratori vanno in overflow ma il comb recupera il risultato corretto: proprietà classica del CIC)
	"""
	x = bits.astype(np.int64) * 2 - 1	#{0,1} -> {-1,+1}
	B_in = 1
	W = int(np.ceil(stages * np.log2(R * M))) + B_in	#bit-growth
	mask = (1 << W) -1
	sign_bit = 1 << (W - 1)

	def wrap(v):
		v &= mask
		return v - (1 << W) if (v & sign_bit) else v

	# --- N integratori @ Fs_mod (co wrap) ---
	integ = [0] * stages
	integrated = np.empty(len(x), dtype=object)
	for n in range(len(x)):
		v = int(x[n])
		for s in range(stages):
			integ[s] = wrap(integ[s] + v)
			v = integ[s]
		integrated[n] = v
	# --- decimazione per R ---
	dec = integrated[::R]

	# --- N stadi comb @ Fs_out (differenza con ritardo M, con wrap) ---
	comb_prev = [0] * stages
	out = np.empty(len(dec), dtype=object)
	# per M>1 servirebbe un buffer; con M=1 basta un registro
	for n in range(len(dec)):
		v = int(dec[n])
		for s in range(stages):
			diff = wrap(v - comb_prev[s])
			comb_prev[s] = v
			v = diff
		out[n] = v
	return np.array([int(o) for o in out], dtype=np.int64), W

# ------------------------------------------------------------------------------
# 3) FIR compensatore di droop (opera @ Fs_out)
# ------------------------------------------------------------------------------
def design_fir_compensator(ntaps=15):
	""""
	FIR simmetrico che compensa il droop del CIC in banda (0..BW su Fs_out)
	Progettazione: risposta target = 1/|H_cic(f)| in banda, poi firls/firwin2
	Ritorna coefficienti float (verranno quantizzati per il verilog)
	"""
	from scipy.signal import firwin2
	# griglia normalizzata 0..1 (1= Nyquist = Fs_out/2)
	f = np.linspace(0, 1, 512)
	# risposta del CIC (sinc^N) valutata sulla banda base normalizzata a Fs_out
	# H_cic(f) ~ [ sin(pi*R*M*f/R)/(R*M*sin(pi*f/R)) ]^N 	-> in banda ~ sinc^N
	# Approssimazione droop in banda (f piccola su scala Fs_mod):
	R, M, N = P.CIC_R, P.CIC_M, P.CIC_STAGES
	fmod_norm = f * (P.FS_OUT/2) / P.CIC_STAGES	#frequenza normalizzata a Fs_mod
	num = np.sin(np.pi * R * M * fmod_norm)
	den = R * M * np.sin(np.pi * fmod_norm)
	with np.errstate(invalid='ignore', divide='ignore'):
		hcic = (num / den) ** N
	hcic[0] = 1.0
	# target = inverso del droop, solo fino a BW; oltre BW lascia decrescere
	passband = P.BW / ( P.FS_OUT/2)		# fraione di Nyquist occupata dalla banda
	gain = np.ones_like(f)
	inband = f <= passband
	gain[inband] = 1.0 / np.clip(np.abs(hcic[inband]), 1e-3, None)
	# oltre banda: transizione dolce a 0 per attenuare i residui
	trans = (f > passband) & (f <= min(1.0, passband * 1.5))
	gain[trans] = np.linspace(gain[inband][-1] if inband.any() else 1.0, 0.0, trans.sum())
	gain[f > min(1.0, passband * 1.5)] = 0.0
	taps = firwin2(ntaps, f, gain)
	return taps


def fir_apply_int(x_int, taps_float, coef_bits=12, decim=P.FIR_DECIM):
	"""FIR causale bit-accurate + decimazione."""

	scale = (1 << (coef_bits - 1)) - 1

	q = np.round(
		taps_float / np.max(np.abs(taps_float)) * scale
	).astype(np.int64)

	# FIR CAUSALE:
	# y[n] = sum_k q[k] * x[n-k]
	#
	# mode='full' produce anche il transitorio finale;
	# [:len(x_int)] mantiene esattamente la sequenza streaming
	# che possiamo implementare nel Verilog.
	y = np.convolve(x_int, q, mode='full')[:len(x_int)]

	# normalizzazione del guadagno DC del FIR
	coef_sum = max(1, int(np.sum(q)))
	y = y // coef_sum

	# decimazione finale
	y = y[::decim]

	return y, q


# ------------------------------------------------------------------------------
# 4) MISURA SNR / ENOB
# ------------------------------------------------------------------------------
def measure_snr(sig, fs, f_sig, bw):
	"""SNR in banda via periodogramma (finestra di HANN), esclude DC e bin segnale."""
	from scipy.signal import periodogram, get_window
	sig = sig - np.mean(sig)
	w = get_window('hann', len(sig))
	f, pxx = periodogram(sig, fs=fs, window=w, scaling='spectrum')
	# bin del segnale (+- qualche bin per la finestra)
	k_sig = np.argmin(np.abs(f - f_sig))
	band = f <= bw
	sig_bins = np.zeros_like(f, dtype=bool)
	lo, hi = max(1, k_sig - 3), min(len(f), k_sig + 4)
	sig_bins[lo:hi] = True
	P_sig = np.sum(pxx[sig_bins])
	noise_mask = band & (~sig_bins)
	noise_mask[0] = False # escludi DC
	P_noise = np.sum(pxx[noise_mask])
	snr = 10 * np.log10(P_sig / P_noise)
	enob = (snr - 1.76) / 6.02
	return snr, enob


# ------------------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------------------
def main():
	outdir = Path(__file__).resolve().parent.parent / "output"
	outdir.mkdir(exist_ok=True)

	#numero campioni ingresso: N_OUT campioni finali * decimazione totale + transitorio
	# decimazione totale = CIC_R * FIR_DECIM = OSR
	warmup = P.OSR * 64
	n_in = P.N_OUT * P.CIC_R * P.FIR_DECIM + warmup

	#tono di test coerente (bin-aligned) per FFT pulita sull'uscita
	# scegliamo f_sig vicino a F_SIG ma multiplo di Fs_out/N_OUT
	df = P.FS_OUT / P.N_OUT
	f_sig = round(P.F_SIG / df) * df
	t = np.arange(n_in) / P.FS_MOD
	x = P.AMP * np.sin(2 * np.pi * f_sig * t)
	print(f"[cfg] BW{P.BW/1e3:.0f}kHz OSR={P.OSR} Fs_mod={P.FS_MOD/1e6:.3f}MHz "
	      f"Fs_out={P.FS_OUT/1e3:.1f}kHz f_test={f_sig:.1f}Hz")
	print(f"[cfg] CIC sinc^{P.CIC_STAGES} R={P.CIC_R} N_in={n_in} N_out~{P.N_OUT}")

	# 1) modulatore
	y_bip, bits = sigma_delta_mod(x)

	# salva bitstream (stimolo per il testbench Verilog)
	bs_path = outdir / "bitstream.txt"
	np.savetxt(bs_path, bits, fmt="%d")
	print(f"[out] bitstream.txt ({len(bits)} campioni 1-bit) -> {bs_path}")

	# 2) CIC
	cic_out, W = cic_decimate(bits)
	print(f"[cic] wordlength interna W={W} bit, campioni out={len(cic_out)}")

	# 3) FIR compensatore
	taps = design_fir_compensator(ntaps=15)
	fir_out, qcoef = fir_apply_int(cic_out, taps, coef_bits=12)

	# scala l'uscita a OUT_BITS con segno
	def scale_to_bits(v, bits_out):
		m = np.max(np.abs(v)) or 1
		full = (1 << (bits_out -1)) -1
		return np. round(v/m * full).astype(np.int64)
	out_final = scale_to_bits(fir_out, P.OUT_BITS)
	print(f"[scale] FIR max abs = {np.max(np.abs(fir_out))}")

	# salva coefficienti FIR (per il verilog)
	np.savetxt(outdir / "fir_coef.txt", qcoef, fmt="%d")
	# salva l'uscita golden (per confronto con rtl)
	np.savetxt(outdir / "golden_out.txt", out_final, fmt="%d")
	print(f"[out] fir_coef.txt ({len(qcoef)} tap), golden_out.txt ({len(out_final)} campioni)")

	# versioni HEX in complemento a due per $readmemh nel testbench verilog
	def write_hex(path, values, nbits):
		mask = (1 << nbits) - 1
		ndig = (nbits + 3) // 4
		with open(path, "w") as fh:
			for v in values:
				fh.write(f"{int(v) & mask:0{ndig}x}\n")
	write_hex(outdir / "fir_coef_hex.txt", qcoef, 12)	# COEF_BITS=12
	write_hex(outdir / "golden_out_hex.txt", out_final, 16)	# OUT_W16
	print(f"[out] fir_coef_hex.txt, golden_out_hex.txt (per $readmemh)")

	# 4) misura SNR/ENOB (scarta transitorio)
	# il CIC lavora a Fs_cic = Fs_mod/R = Fs_out*FIR_DECIM; l'uscita finale a Fs_out
	fs_cic = P.FS_OUT * P.FIR_DECIM
	skip = 64
	snr_cic, enob_cic = measure_snr(cic_out[skip:].astype(float), fs_cic, f_sig, P.BW)
	snr_fir, enob_fir = measure_snr(out_final[skip:].astype(float), P.FS_OUT, f_sig, P.BW)
	print(f"[snr] dopo CIC		: SNR={snr_cic:6.2f} dB  ENOB={enob_cic:5.2f} bit")
	print(f"[snr] dopo CIC+FIR	: SNR={snr_fir:6.2f} dB  ENOB={enob_fir:5.2f} bit")

	# SQNR teorico atteso per SigmaDelta 1 ordine:
	#	SQNR = 6.02*ENOB+1.76 ; per L=1: ~ 30*log10(OSR) - 3.14 dB (approx + 9dB/oct)
	sqnr_teo = 6.02*0 + 1.76 + 30*np.log10(P.OSR) -5.17	# formula L=1
	print(f"[teo] SQNR teorico 1-ord @OSR={P.OSR}: ~{sqnr_teo:.1f} dB "
		f"(ENOB~{(sqnr_teo-1.76)/6.02:.1f} bit)")

	# salva un piccolo report per il capitolato
	with open(outdir / "model_report.txt", "w") as f:
		f.write("ADC Sigma-Delta 1 ordine - report golden model\n")
		f.write(f"BW={P.BW} Hz  OSR={P.OSR}  Fs_mod={P.FS_MOD} Hz  Fs_out={P.FS_OUT} Hz\n")
		f.write(f"CIC sinc^{P.CIC_STAGES} R={P.CIC_R} M={P.CIC_M}  W_interno={W} bit\n")
		f.write(f"FIR taps={len(qcoef)} coef_bits=12\n")
		f.write(f"OUT_BITS={P.OUT_BITS}\n")
		f.write(f"f_test={f_sig} Hz  amp={P.AMP}\n")
		f.write(f"SNR dopo CIC		= {snr_cic:.2f} db  (ENOB {enob_cic:.2f})\n")
		f.write(f"SNR dopo CIC+FIR	= {snr_fir:.2f} db  (ENOB {enob_fir:.2f})\n")
		f.write(f"SQNR teorico 1-ord = {sqnr_teo:.1f} dB\n")
	print(f"[out] model_report.txt")

if __name__ == "__main__":
	main()

