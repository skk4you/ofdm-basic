# Validation before initial publication

Reviewed and tested on MATLAB R2018a on 2026-10-28.

## Fix found during review

A scalar flat channel (`channel=1`) could make `fft(h,nFFT)` return a row-shaped frequency response. Equalizing a 52-by-many-symbol received matrix then failed in `bsxfun`. The published implementation explicitly uses `fft(h,nFFT,1)` to preserve a column response. The zero-error console message was also clarified to avoid implying a bound on the unknown true BER.

## Checks passed

`check_ofdm_study` passed using the exact staged sources prepared for this repository:

- Flat-channel QPSK BER versus AWGN theory at 0, 3 and 6 dB, using 2,000 OFDM symbols per point.
- Default multipath BER versus sufficient-CP theory at 0, 6 and 12 dB, using 2,000 symbols per point.
- Negligible-noise recovery for a scalar flat channel with no CP.
- Negligible-noise recovery for the default multipath channel with CP length 6.

The training guide was checked against the configuration names, output fields, carrier allocation, transform scaling, channel assumptions, and plotting code. Its MATLAB examples use existing settings/functions.

The test log is kept outside the repository with the Wi-Fi workspace's review artifacts (`matlab_second_review_final.log`); generated results/logs are not submitted. These are deterministic numerical regression checks, not IEEE Wi-Fi conformance tests or exhaustive coverage of every possible channel.
