function results = ofdm_study(cfg)
%OFDM_STUDY Learn OFDM using QPSK, a cyclic prefix, and a multipath channel.
% MATLAB R2018a; base MATLAB only. Run: results = ofdm_study;
% Change a setting: results = ofdm_study(struct('cpLength', 0));
% See README.md for assumptions and suggested experiments.

if nargin < 1, cfg = struct(); end
defaults = struct('nFFT', 64, 'cpLength', 16, 'nSymbols', 500, ...
    'ebN0dB', 0:3:18, 'channel', [1 0 0 0.45 0 0 0.25j], ...
    'seed', 7, 'makePlots', true);
names = fieldnames(cfg);
for k = 1:numel(names)
    assert(isfield(defaults, names{k}), 'Unknown setting: %s', names{k});
end
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(cfg, names{k}), cfg.(names{k}) = defaults.(names{k}); end
end
validateattributes(cfg.nFFT, {'numeric'}, {'scalar','integer','>=',64});
assert(mod(cfg.nFFT,2) == 0, 'nFFT must be even.');
validateattributes(cfg.cpLength, {'numeric'}, ...
    {'scalar','integer','>=',0,'<=',cfg.nFFT});
validateattributes(cfg.nSymbols, {'numeric'}, {'scalar','integer','positive'});
validateattributes(cfg.ebN0dB, {'numeric'}, {'vector','real','finite','nonempty'});
validateattributes(cfg.channel, {'numeric'}, {'vector','finite','nonempty'});
assert(any(cfg.channel ~= 0), 'Channel must contain a nonzero tap.');
assert(numel(cfg.channel) <= cfg.nFFT, 'Channel must fit within nFFT.');
rng(cfg.seed, 'twister');

% Frequencies are indexed relative to DC. Leave DC and edge bins empty.
% For a 64-point FFT: 52 data carriers at -26:-1 and 1:26.
carrierNumbers = [-26:-1 1:26].';
dataBins = mod(carrierNumbers, cfg.nFFT) + 1;
nData = numel(dataBins);
nBits = 2*nData*cfg.nSymbols;
bits = randi([0 1], nBits, 1);

% Gray QPSK: each bit independently controls the sign of I or Q.
% Each constellation point has energy 1. No modulation toolbox needed.
bitPairs = reshape(bits, 2, []);
qpsk = ((1-2*bitPairs(1,:)) + 1j*(1-2*bitPairs(2,:)))/sqrt(2);
frequencyGrid = zeros(cfg.nFFT, cfg.nSymbols);
frequencyGrid(dataBins,:) = reshape(qpsk, nData, cfg.nSymbols);

% IFFT combines orthogonal carriers into one time waveform.
% sqrt(N) scaling makes the FFT/IFFT pair energy preserving.
timeSymbols = ifft(frequencyGrid, cfg.nFFT, 1)*sqrt(cfg.nFFT);
withCP = [timeSymbols(end-cfg.cpLength+1:end,:); timeSymbols];
tx = withCP(:); % Columns are transmitted one OFDM symbol at a time.

% Normalize channel tap energy, so its average frequency power is one.
h = cfg.channel(:)/norm(cfg.channel);
H = fft(h, cfg.nFFT, 1); % Explicit dimension also handles a scalar flat channel.
assert(all(abs(H(dataBins)) > 1e-10), ...
    'A data carrier has a channel null; zero-forcing cannot invert it.');
cleanRx = filter(h, 1, tx); % Serial convolution includes adjacent symbols.
if cfg.cpLength < numel(h)-1
    warning('ofdm_study:ShortCP', ...
        'CP is shorter than channel memory: expect interference and BER loss.');
end

ebN0dB = cfg.ebN0dB(:).';
ber = zeros(size(ebN0dB));
errorCounts = zeros(size(ebN0dB));
for k = 1:numel(ebN0dB)
    % Eb refers to useful data energy, excluding CP overhead.
    % QPSK Es=1 and 2 bits/symbol => Eb=1/2. Complex noise power=N0.
    noiseVariance = 1/(2*10^(ebN0dB(k)/10));
    noise = sqrt(noiseVariance/2)* ...
        (randn(size(cleanRx)) + 1j*randn(size(cleanRx)));
    rx = cleanRx + noise;
    rxBlocks = reshape(rx, cfg.nFFT+cfg.cpLength, cfg.nSymbols);
    usefulRx = rxBlocks(cfg.cpLength+1:end,:);
    rxGrid = fft(usefulRx, cfg.nFFT, 1)/sqrt(cfg.nFFT);
    received = rxGrid(dataBins,:);
    % Perfect channel knowledge: divide each carrier by its complex gain.
    equalized = bsxfun(@rdivide, received, H(dataBins));
    detected = zeros(2, numel(equalized));
    detected(1,:) = real(equalized(:)).' < 0;
    detected(2,:) = imag(equalized(:)).' < 0;
    errorCounts(k) = sum(detected(:) ~= bits);
    ber(k) = errorCounts(k)/nBits;
end

% Q(x)=erfc(x/sqrt(2))/2. Ideal QPSK BER conditional on each carrier gain.
ebLinear = 10.^(ebN0dB/10);
awgnTheory = 0.5*erfc(sqrt(ebLinear));
channelTheory = mean(0.5*erfc(sqrt(abs(H(dataBins)).^2*ebLinear)),1);
results = struct('config',cfg, 'ebN0dB',ebN0dB, 'ber',ber, ...
    'errorCounts',errorCounts, 'nBitsPerPoint',nBits, ...
    'awgnTheory',awgnTheory, 'channelTheory',channelTheory, ...
    'carrierNumbers',carrierNumbers, 'channelResponse',H);
fprintf('\nOFDM: N=%d, data carriers=%d, CP=%d, symbols=%d\n', ...
    cfg.nFFT,nData,cfg.cpLength,cfg.nSymbols);
fprintf('Eb/N0 excludes CP energy. Perfect timing and channel knowledge.\n');
fprintf(' Eb/N0 (dB)       Errors          BER\n');
for k = 1:numel(ber)
    fprintf(' %8.1f       %8d       %.4g\n',ebN0dB(k),errorCounts(k),ber(k));
end
fprintf('Zero observed errors is a finite-run result; it does not establish zero true BER.\n');

if ~cfg.makePlots, return; end
figure('Name','OFDM processing steps','Color','w');
subplot(2,2,1);
stem(carrierNumbers,abs(frequencyGrid(dataBins,1)),'.'); grid on;
xlabel('Subcarrier number relative to DC'); ylabel('Magnitude');
title('1. QPSK symbols on 52 carriers');
subplot(2,2,2);
t = -cfg.cpLength:cfg.nFFT-1;
plot(t,real(withCP(:,1)),'b.-'); hold on;
yl = ylim; plot([0 0],yl,'r--'); grid on;
xlabel('Sample (CP occupies negative indices)'); ylabel('Real part');
title('2. IFFT waveform with cyclic prefix');
subplot(2,2,3);
freqBins = (-cfg.nFFT/2:cfg.nFFT/2-1).';
plot(freqBins,20*log10(max(abs(fftshift(H)),1e-12)),'LineWidth',1.2);
grid on; xlabel('Subcarrier number'); ylabel('Channel magnitude (dB)');
title('3. Multipath gives each carrier a different gain');
subplot(2,2,4);
nShow = min(2000,numel(equalized));
plot(real(received(1:nShow)),imag(received(1:nShow)),'.'); hold on;
plot(real(equalized(1:nShow)),imag(equalized(1:nShow)),'.');
axis equal; grid on; xlabel('In-phase'); ylabel('Quadrature');
legend('Before equalization','After equalization','Location','best');
title(sprintf('4. Constellations at last Eb/N0 = %g dB',ebN0dB(end)));

figure('Name','OFDM bit error rate','Color','w');
% Omit zero-error points from the logarithmic curve and mark run resolution.
plotBER = ber; plotBER(plotBER == 0) = NaN;
semilogy(ebN0dB,plotBER,'bo-','LineWidth',1.3); hold on;
semilogy(ebN0dB,awgnTheory,'k--','LineWidth',1.2);
semilogy(ebN0dB,channelTheory,'r-','LineWidth',1.2);
legend('Simulation','Flat AWGN theory','Channel theory (sufficient CP)', ...
    'Location','southwest');
if any(ber == 0)
    semilogy(ebN0dB(ber == 0),ones(1,sum(ber == 0))/nBits,'bv', ...
        'DisplayName','Zero errors: marker at 1 / number of bits');
end
grid on; xlabel('Useful-data Eb/N0 (dB)'); ylabel('Bit error rate');
title(sprintf('QPSK OFDM: %d bits per SNR point',nBits));
end

