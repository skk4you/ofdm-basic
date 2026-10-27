# OFDM study simulator (MATLAB R2018a)

Start here: [Training guide](TRAINING_GUIDE.md) — signal-chain walkthrough, settings, experiments, plots and troubleshooting.

Open this folder in MATLAB, then run:

```matlab
results = ofdm_study;
```

Only base MATLAB is required. The simulator prints bit error rates and opens two figures. All settings are optional fields in a structure; omitted fields use defaults.

Run `check_ofdm_study` for numerical checks of flat-channel theory, multipath theory, and recovery at negligible noise.

## Follow the signal

1. Generate random bits and map every pair to a unit-energy QPSK symbol.
2. Put symbols on 52 frequency bins, leaving DC and edge bins empty.
3. Take an IFFT to combine the carriers. Their frequencies are spaced by one FFT bin, making them orthogonal over the useful symbol duration.
4. Copy the last 16 samples to the front as a cyclic prefix (CP), then serialize the symbols.
5. Pass the stream through a multipath channel and add complex Gaussian noise.
6. Split the stream into blocks, discard the CP, and take an FFT.
7. Divide each data carrier by its known channel response (one-tap zero-forcing equalization).
8. Recover bits from the signs of the real and imaginary parts and count errors.

The CP makes the useful part of linear channel convolution behave like circular convolution when it covers the channel memory. The FFT then turns the channel into a separate complex gain on each carrier. With insufficient CP, neighboring symbols interfere and this simple equalizer cannot remove all the distortion.

## Experiments

Run these commands separately and compare the figures:

```matlab
% 1. Flat channel: simulated BER should follow flat AWGN theory.
flat = ofdm_study(struct('channel', 1));

% 2. Default multipath channel, with sufficient CP.
multi = ofdm_study;

% 3. Remove CP: observe interference and loss at high SNR.
noCP = ofdm_study(struct('cpLength', 0, 'ebN0dB', 0:4:28));

% 4. A CP of 6 samples covers the default channel's 6-sample memory.
shorterCP = ofdm_study(struct('cpLength', 6));

% 5. Count more errors for a more reliable BER estimate (takes longer).
longRun = ofdm_study(struct('nSymbols', 5000, 'ebN0dB', 0:2:12));

% 6. Numerical results without figures.
r = ofdm_study(struct('makePlots', false));
disp([r.ebN0dB(:), r.ber(:)])
```

## Interpreting the results

- Defaults: 64-point FFT, 52 active carriers, QPSK, 16 CP samples, 500 OFDM symbols, and 52,000 transmitted bits per SNR point.
- Channel taps are normalized to total squared magnitude one. Empty tap positions represent delays in samples; the default channel has taps at delays 0, 3, and 6.
- The receiver knows the channel exactly and has perfect symbol timing. There are no pilots, coding, synchronization errors, carrier frequency offset, or time-varying fading. This isolates the core OFDM operations.
- `Eb/N0` uses useful data energy and excludes CP energy. With unit-energy QPSK and the energy-preserving FFT scaling, `Eb = 1/2`, so complex noise variance is `1/(2*10^(EbN0dB/10))`. Unused carriers do not change this definition.
- Charging CP energy to each bit would add `10*log10((N+CP)/N)` dB to the reported transmitted-energy Eb/N0 (about 0.97 dB for 64+16 samples).
- The channel-theory curve averages QPSK BER over the actual carrier gains. It applies when the CP covers channel memory. Deep fades amplify noise during zero-forcing equalization.
- The flat AWGN curve is a reference. Multipath results generally follow the channel-theory curve instead.
- A finite run can report zero errors. This does not prove zero BER. The plot marks these points at `1/nBits`; that marker is a measurement-resolution indicator, not a confidence bound.
- Increasing FFT size keeps the same 52 active carriers in this example. No sample rate is assumed: if you choose sample rate `Fs`, carrier spacing is `Fs/N`, useful duration is `N/Fs`, and CP duration is `CP/Fs`.

The main function returns settings, BER measurements, error counts, theoretical curves, and the channel frequency response for your own analysis.
