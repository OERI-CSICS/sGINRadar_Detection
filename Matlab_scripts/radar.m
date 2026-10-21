% Generated and edited for MATLAB R2025a
% Requires Phased Array System Toolbox

clear;
clc;
close all;

%% ============================================================
%  COMMON PARAMETERS
% =============================================================

Fs = 50e6;                 % Sampling rate: 50 MHz
PRF = 10e3;                % Pulse repetition frequency: 10 kHz
numPulses = 20;            % Number of pulses
pulseWidth = 50e-6;        % Pulse width: 50 microseconds
sweepBandwidth = 10e6;     % Sweep bandwidth: 10 MHz

fprintf("Radar waveform generation started.\n");
fprintf("Common sample rate: %.2f MHz\n\n", Fs / 1e6);


%% ============================================================
%  1. LINEAR FM RADAR
% =============================================================

fprintf("Generating Linear FM waveform...\n");

linearFMwaveform = phased.LinearFMWaveform( ...
    'SampleRate', Fs, ...
    'PRF', PRF, ...
    'NumPulses', numPulses, ...
    'PulseWidth', pulseWidth, ...
    'SweepBandwidth', sweepBandwidth, ...
    'SweepDirection', 'Down', ...
    'SweepInterval', 'Positive', ...
    'Envelope', 'Rectangular');

% Generate waveform
lfmSignal = linearFMwaveform();

% Store waveform information
Radar_LFM.name = "LFM";
Radar_LFM.waveform = lfmSignal;
Radar_LFM.Fs = linearFMwaveform.SampleRate;
Radar_LFM.PRF = PRF;
Radar_LFM.NumPulses = numPulses;
Radar_LFM.PulseWidth = pulseWidth;
Radar_LFM.SweepBandwidth = sweepBandwidth;

% Normalize to unit RMS
Radar_LFM.waveform = Radar_LFM.waveform / ...
    rms(Radar_LFM.waveform);


%% ============================================================
%  2. FMCW RADAR
% =============================================================

fprintf("Generating FMCW waveform...\n");

fmcwSweepTime = 500e-6;    % Sweep time: 500 microseconds
numSweeps = 20;            % Generate multiple sweeps

fmcwWaveform = phased.FMCWWaveform( ...
    'SampleRate', Fs, ...
    'SweepTime', fmcwSweepTime, ...
    'SweepBandwidth', sweepBandwidth, ...
    'SweepDirection', 'Up', ...
    'SweepInterval', 'Positive', ...
    'NumSweeps', numSweeps);

% Generate waveform
fmcwSignal = fmcwWaveform();

% Store waveform information
Radar_FMCW.name = "FMCW";
Radar_FMCW.waveform = fmcwSignal;
Radar_FMCW.Fs = fmcwWaveform.SampleRate;
Radar_FMCW.SweepTime = fmcwSweepTime;
Radar_FMCW.NumSweeps = numSweeps;
Radar_FMCW.SweepBandwidth = sweepBandwidth;

% Normalize to unit RMS
Radar_FMCW.waveform = Radar_FMCW.waveform / ...
    rms(Radar_FMCW.waveform);


%% ============================================================
%  3. NONLINEAR FM RADAR
% =============================================================

fprintf("Generating Nonlinear FM waveform...\n");

nonlinearFMwaveform = phased.NonlinearFMWaveform( ...
    'SampleRate', Fs, ...
    'PRF', PRF, ...
    'FrequencyModulation', 'Polynomial', ...
    'NumPulses', numPulses, ...
    'PulseWidth', pulseWidth, ...
    'Envelope', 'Rectangular');

% NLFM configuration
nonlinearFMwaveform.PolynomialCoefficients = [1 0 0];
nonlinearFMwaveform.SweepInterval = 'Positive';
nonlinearFMwaveform.SweepBandwidth = sweepBandwidth;

% Generate waveform
nlfmSignal = nonlinearFMwaveform();

% Store waveform information
Radar_NLFM.name = "NLFM";
Radar_NLFM.waveform = nlfmSignal;
Radar_NLFM.Fs = nonlinearFMwaveform.SampleRate;
Radar_NLFM.PRF = PRF;
Radar_NLFM.NumPulses = numPulses;
Radar_NLFM.PulseWidth = pulseWidth;
Radar_NLFM.SweepBandwidth = sweepBandwidth;
Radar_NLFM.PolynomialCoefficients = ...
    nonlinearFMwaveform.PolynomialCoefficients;

% Normalize to unit RMS
Radar_NLFM.waveform = Radar_NLFM.waveform / ...
    rms(Radar_NLFM.waveform);


%% ============================================================
%  4. P4 PHASE-CODED RADAR
% =============================================================

fprintf("Generating P4 phase-coded waveform...\n");

chipWidth = 1e-6;          % Chip width: 1 microsecond
numChips = 64;             % Number of chips per pulse

phaseCodedWaveform = phased.PhaseCodedWaveform( ...
    'SampleRate', Fs, ...
    'PRF', PRF, ...
    'NumPulses', numPulses, ...
    'Code', 'P4', ...
    'ChipWidth', chipWidth);

phaseCodedWaveform.NumChips = numChips;

% Generate waveform
p4Signal = phaseCodedWaveform();

% Store waveform information
Radar_P4.name = "P4";
Radar_P4.waveform = p4Signal;
Radar_P4.Fs = phaseCodedWaveform.SampleRate;
Radar_P4.PRF = PRF;
Radar_P4.NumPulses = numPulses;
Radar_P4.ChipWidth = chipWidth;
Radar_P4.NumChips = numChips;

% Normalize to unit RMS
Radar_P4.waveform = Radar_P4.waveform / ...
    rms(Radar_P4.waveform);


%% ============================================================
%  5. VERIFY SAMPLE RATES AND WAVEFORM LENGTHS
% =============================================================

fprintf("\nWaveform verification:\n");

fprintf("LFM:  Fs = %.2f MHz, Length = %d samples\n", ...
    Radar_LFM.Fs / 1e6, ...
    length(Radar_LFM.waveform));

fprintf("FMCW: Fs = %.2f MHz, Length = %d samples\n", ...
    Radar_FMCW.Fs / 1e6, ...
    length(Radar_FMCW.waveform));

fprintf("NLFM: Fs = %.2f MHz, Length = %d samples\n", ...
    Radar_NLFM.Fs / 1e6, ...
    length(Radar_NLFM.waveform));

fprintf("P4:   Fs = %.2f MHz, Length = %d samples\n", ...
    Radar_P4.Fs / 1e6, ...
    length(Radar_P4.waveform));

% Verify all radar waveforms use the same sampling rate
assert(Radar_LFM.Fs == Fs, ...
    "LFM sampling rate does not match the required sampling rate.");

assert(Radar_FMCW.Fs == Fs, ...
    "FMCW sampling rate does not match the required sampling rate.");

assert(Radar_NLFM.Fs == Fs, ...
    "NLFM sampling rate does not match the required sampling rate.");

assert(Radar_P4.Fs == Fs, ...
    "P4 sampling rate does not match the required sampling rate.");

disp("All radar sampling rates are correct.");


%% ============================================================
%  6. CREATE RADAR BANK
% =============================================================

% Use a cell array because each radar structure contains
% waveform-specific metadata fields.

radarBank = {
    Radar_LFM
    Radar_FMCW
    Radar_NLFM
    Radar_P4
};

fprintf("\nRadar bank contents:\n");

for r = 1:numel(radarBank)

    currentRadar = radarBank{r};

    fprintf("%d. %s: Fs = %.2f MHz, Length = %d samples\n", ...
        r, ...
        currentRadar.name, ...
        currentRadar.Fs / 1e6, ...
        length(currentRadar.waveform));
end


%% ============================================================
%  7. TIME-DOMAIN VISUALIZATION
% =============================================================

radarNames = ["LFM", "FMCW", "NLFM", "P4"];

radarSignals = {
    Radar_LFM.waveform
    Radar_FMCW.waveform
    Radar_NLFM.waveform
    Radar_P4.waveform
};

% Display only a limited number of samples for readability
samplesToDisplay = 5000;

for r = 1:numel(radarSignals)

    signal = radarSignals{r};

    displayLength = min(samplesToDisplay, length(signal));

    timeVector = (0:displayLength-1) / Fs;

    figure;

    plot( ...
        timeVector * 1e6, ...
        real(signal(1:displayLength)) ...
    );

    xlabel("Time (\mus)");
    ylabel("Amplitude");
    title(radarNames(r) + " Radar Waveform");
    grid on;

end


%% ============================================================
%  8. SPECTROGRAM VISUALIZATION
% =============================================================

winLen = 512;
window = hamming(winLen);
overlap = round(0.5 * winLen);
nfft = 1024;

for r = 1:numel(radarSignals)

    signal = radarSignals{r};

    figure;

    spectrogram( ...
        signal, ...
        window, ...
        overlap, ...
        nfft, ...
        Fs, ...
        "centered", ...
        "yaxis" ...
    );

    title(radarNames(r) + " Radar Spectrogram");
    colormap jet;
    colorbar;

end


%% ============================================================
%  9. OPTIONAL SPECTRUM ANALYZER
% =============================================================

for r = 1:numel(radarSignals)

    signal = radarSignals{r};

    spectrum = spectrumAnalyzer( ...
        SampleRate=Fs, ...
        AveragingMethod='exponential', ...
        ForgettingFactor=1);

    spectrum.RBWSource = "property";
    spectrum.RBW = 0.02 * Fs;
    spectrum.Title = radarNames(r) + " Spectrum";

    spectrum(signal);

    release(spectrum);

end


%% ============================================================
%  10. SAVE RADAR WAVEFORMS
% =============================================================

save( ...
   "workspace.mat", ...
   "Radar_LFM", ...
    "Radar_FMCW", ...
    "Radar_NLFM", ...
    "Radar_P4", ...
    "radarBank", ...
    "Fs",  ...
    "-append" );

fprintf("\nRadar waveforms saved to radar_waveforms.mat\n");
disp("Radar waveform generation complete.");