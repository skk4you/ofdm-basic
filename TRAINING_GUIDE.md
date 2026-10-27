# Basic OFDM simulator: training guide

**Project:** [skk4you/ofdm-basic](https://github.com/skk4you/ofdm-basic)  
**Target:** MATLAB R2018a or later; base MATLAB only.  
**Purpose:** Learn the OFDM signal chain before moving to packet-based Wi-Fi simulation.

## 1. What this project does

The simulator generates random bits, maps them to QPSK, transmits them on OFDM carriers through a configurable FIR channel and AWGN, equalizes the received carriers, and measures BER.

It is an educational model, not a standards-compliant Wi-Fi packet generator. It has no Wi-Fi preamble, pilots, coding, packet detection, CFO correction, PER, RF power calibration, DC/IQ trims, or time-varying fading. Timing and channel knowledge are perfect.

| File | Role |
|---|---|
| `ofdm_study.m` | Complete TX/channel/RX simulation, metrics and plots. |
| `check_ofdm_study.m` | Numerical regression checks. |
| `README.md` | Commands and parameter reference. |
| `TRAINING_GUIDE.md` | This walkthrough and exercises. |
| `VALIDATION.md` | What was checked before publication. |

## 2. First run

In MATLAB, add the folder containing the source:

```matlab
addpath('C:\Codex\ofdm')
r = ofdm_study;
check_ofdm_study
```

If you cloned elsewhere, substitute that path. The code opens two figures and prints errors/BER at each Eb/N0 point. Nothing is saved to disk automatically.

For numbers without figures:

```matlab
r = ofdm_study(struct('makePlots',false));
disp(table(r.ebN0dB(:),r.errorCounts(:),r.ber(:), ...
    'VariableNames',{'EbN0dB','BitErrors','BER'}))
```

## 3. Follow one symbol through the code

```mermaid
flowchart LR
  A[Random bits] --> B[Gray QPSK]
  B --> C[52 data carriers]
  C --> D[IFFT]
  D --> E[Cyclic prefix]
  E --> F[FIR channel and AWGN]
  F --> G[Remove CP]
  G --> H[FFT]
  H --> I[Known-channel ZF equalizer]
  I --> J[QPSK decisions and BER]
```

### Bits and QPSK

Each symbol carries two bits: one controls the real sign and one the imaginary sign. The four constellation points have I/Q coordinates ±1/sqrt(2), giving unit symbol energy.

The default sends 500 OFDM symbols with 52 QPSK carriers:

```text
bits per point = 500 * 52 * 2 = 52,000
```

### Carrier allocation

The data carriers are -26 through -1 and +1 through +26 relative to DC. DC and unused FFT bins contain zeros. All 52 occupied bins carry data; this model does not reserve Wi-Fi pilots.

`mod(carrierNumbers,nFFT)+1` converts signed carrier numbers into MATLAB FFT-bin indices.

### IFFT and FFT

The IFFT combines the carrier symbols into a time waveform. Multiplication by sqrt(N) at TX and division by sqrt(N) after the RX FFT form an energy-preserving transform pair.

Changing `nFFT` changes the transform size but keeps the same 52 carrier numbers. It does not select another Wi-Fi standard or bandwidth.

### Cyclic prefix

The last CP samples of each useful symbol are copied to its beginning. The receiver discards the CP before taking the FFT.

For an FIR channel with memory L-1 samples, CP must be at least L-1 samples for this ideal aligned receiver to avoid inter-symbol/inter-carrier interference from channel convolution. The default channel has taps at delays 0, 3 and 6, so its memory is 6 samples.

### Channel and equalizer

The channel tap vector is normalized so sum(abs(h).^2)=1. Its response is `H=fft(h,nFFT,1)`. The explicit first dimension keeps the response column-shaped even when the channel has only one scalar tap. With sufficient CP, each received carrier is approximately its transmitted symbol multiplied by H at that bin, plus noise.

Zero-forcing equalization divides by H. It corrects gain/phase but increases noise at weak carriers. An exact/deep channel null cannot be recovered this way; the implementation rejects a near-zero gain on any data carrier.

### Decisions and errors

The receiver recovers bits from the signs of the equalized real and imaginary components. BER is the number of differing bits divided by the transmitted bit count.

## 4. Parameter reference

Pass only fields you want to change. Unknown field names are errors.

| Setting | Default | Meaning |
|---|---:|---|
| `nFFT` | 64 | Even transform size, at least 64. Still 52 data carriers. |
| `cpLength` | 16 | Samples copied to the prefix; allowed 0 through nFFT. |
| `nSymbols` | 500 | Number of OFDM symbols, not number of bits. |
| `ebN0dB` | 0:3:18 | Useful-data Eb/N0 points. |
| `channel` | [1 0 0 0.45 0 0 0.25j] | FIR taps at sample delays 0, 3 and 6. |
| `seed` | 7 | Repeatable random bits/noise. |
| `makePlots` | true | Enable the two figures. |

Example:

```matlab
cfg = struct;
cfg.channel = 1;
cfg.ebN0dB = 0:2:12;
cfg.nSymbols = 2000;
cfg.makePlots = true;
r = ofdm_study(cfg);
```

The function resets MATLAB's RNG using `seed`; unlike the Wi-Fi experiment wrapper, it does not restore the caller's prior RNG state.

## 5. Eb/N0 and theoretical curves

The horizontal axis is useful-data Eb/N0, excluding CP overhead.

QPSK has Es=1 and two bits per symbol, so Eb=1/2. The injected complex-noise variance is:

```text
N0 = 1 / (2 * 10^(EbN0dB/10))
```

The real and imaginary noise components each have variance N0/2. The flat-channel QPSK reference is:

```matlab
0.5 * erfc(sqrt(10.^(ebN0dB/10)))
```

The channel reference averages the corresponding conditional BER across the actual occupied-carrier gains. It assumes sufficient CP and the model's perfect timing/channel knowledge.

Eb/N0 is not input power in dBm and is not automatically equal to sample SNR or the conducted Wi-Fi simulator's SNR. If you assign an external sample rate Fs, useful symbol time is N/Fs and CP time is CP/Fs; Fs is not an input setting in this project.

## 6. Read the figures

### Figure 1: OFDM processing steps

1. **Carrier magnitudes:** shows the occupied bins for the first symbol.
2. **Time waveform and CP:** negative sample indices mark the copied prefix.
3. **Channel response:** shows frequency-dependent gain from multipath.
4. **Constellations:** before/after equalization at the **last** Eb/N0 point.

Do not interpret the constellation as an average over the full sweep. Change the last Eb/N0 setting if you want to inspect a particular noise level.

### Figure 2: BER

Compare simulated BER with flat AWGN theory and channel theory.

- For a flat channel, the simulation should approximately follow the AWGN reference.
- With multipath and sufficient CP, compare against the channel reference.
- With insufficient CP, the sufficient-CP theoretical curve no longer describes all interference.
- Zero errors do not prove true BER is zero. The downward marker at 1/nBits is a resolution indicator, not a confidence bound.

## 7. Guided experiments

Run each experiment separately.

### A. Verify flat AWGN behavior

```matlab
flat = ofdm_study(struct('channel',1,'nSymbols',2000, ...
    'ebN0dB',0:2:12));
```

Explain why BER decreases with Eb/N0 and why simulation fluctuates around theory.

### B. Observe multipath and equalization

```matlab
multi = ofdm_study(struct('nSymbols',2000,'ebN0dB',0:3:18));
```

Find the weak carriers in the channel-response plot. Explain why equalization does not remove the extra noise penalty on those carriers.

### C. Remove CP

```matlab
noCP = ofdm_study(struct('cpLength',0,'ebN0dB',0:4:28));
```

A short-CP warning is expected. Look for interference that cannot be removed by the one-tap equalizer.

### D. Use just enough CP

```matlab
enoughCP = ofdm_study(struct('cpLength',6,'ebN0dB',0:4:28));
```

Compare with no CP. Explain why CP 6 covers the default 6-sample memory, while a larger CP adds overhead without removing another impairment in this model.

### E. Increase statistical resolution

```matlab
longer = ofdm_study(struct('channel',1,'nSymbols',5000, ...
    'ebN0dB',0:2:12,'makePlots',false));
disp(longer.nBitsPerPoint)
```

Explain why observing zero errors in a longer run is more informative, while still not establishing zero true BER.

## 8. Returned results and optional export

The returned structure includes:

- `config`: resolved settings.
- `ebN0dB`, `ber`, `errorCounts`, `nBitsPerPoint`.
- `awgnTheory`, `channelTheory`.
- `carrierNumbers` and the full FFT `channelResponse`.

You can save measurements explicitly in your current folder:

```matlab
r = ofdm_study(struct('makePlots',false));
save('ofdm_results.mat','r')
metrics = table(r.ebN0dB(:),r.errorCounts(:),r.ber(:), ...
    'VariableNames',{'EbN0dB','BitErrors','BER'});
writetable(metrics,'ofdm_metrics.csv')
```

Those filenames are replaced if reused. Use separate test folders or unique names for separate experiments.

## 9. Validation and troubleshooting

`check_ofdm_study` checks flat-channel theory, sufficient-CP multipath theory, negligible-noise flat recovery with no CP, and negligible-noise multipath recovery with CP 6. Passing these checks is not Wi-Fi conformance validation.

| Symptom | Explanation or action |
|---|---|
| Short-CP warning | Expected when CP does not cover channel memory. |
| Channel-null assertion | Choose a channel without a near-zero response on a data carrier; ZF cannot invert the null. |
| BER not exactly on theory | Finite Monte Carlo variation; increase nSymbols. |
| Zero-error points missing from the line | They are deliberately omitted from the log curve and marked at measurement resolution. |
| Larger FFT did not add data throughput/carriers | Carrier allocation remains fixed at 52. |
| Looking for PER/EVM/DC trim | Use the Wi-Fi project instead. |

## 10. Move to the Wi-Fi simulator

Continue with [wifi-ofdm](https://github.com/skk4you/wifi-ofdm) and its [training guide](https://github.com/skk4you/wifi-ofdm/blob/main/TRAINING_GUIDE.md) for actual Wi-Fi PHY packets, coding/pilots/synchronization, conducted dBm PER sweeps, RX DC/IQ calibration, effective SNR/MER, sensitivity, test plans and saved-run comparisons.

Before moving on, explain: Why is the CP needed? Why can ZF amplify noise? Which energy does Eb/N0 refer to? Which receiver knowledge is assumed? How many bits support each BER point?
