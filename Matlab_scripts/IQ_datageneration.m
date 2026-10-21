 %% IQ DATASET GENERATION SCRIPT
% This script creates raw IQ dataset examples for radar detection
% with multiple UEs, MIMO reception, and per-example metadata.
% It saves IQ only, not spectrogram images.

%% 1  Extract numeric waveforms and sample rate from app structs
load("workspace.mat")
wave5gSig = wave5g.waveform;        % 5G IQ
Fs5g      = wave5g.Fs;              % sample rate

radarSig  = Radar.waveform;         % radar IQ
FsRadar   = Radar.Fs;               % sample rate

assert(Fs5g == FsRadar, 'Sample rates must match. Set them equal in the apps');
Fs = Fs5g;

%% 2  Make both signals the same length
N5g    = length(wave5gSig);
NRadar = length(radarSig);
Nmin   = min(N5g, NRadar);

wave5gSig = wave5gSig(1:Nmin);
radarSig  = radarSig(1:Nmin);

%% 3  Normalize to unit RMS once
wave5gSig = wave5gSig / rms(wave5gSig);
radarSig  = radarSig  / rms(radarSig);

%% 4  Create output folder
outRoot = "dataset_IQ";
if ~exist(outRoot, "dir")
    mkdir(outRoot);
end

classNames = ["5G_only", "Radar_plus_5G"];

%% 5  Parameters for random scenarios
numExamplesPerClass = 1000;
SNR_range_dB        = [-10 25];
SIR_range_dB        = [-10 10];

%% 5a  Geometry and MIMO parameters
numUE   = 3;
numRx   = 4;

gNBPos   = [0 0 0];
radarPos = [3000 400 0];

fc      = 3.8e9;
c       = 3e8;
lambda  = c / fc;

cellRmin = 100;
cellRmax = 1500;

%% 5b  Metadata container
meta  = struct('class',{},'exampleIdx',{},'fileName',{}, ...
               'SNR_dB',{},'SIR_dB',{},'UEpos',{}, ...
               'gNBPos',{},'radarPos',{},'numUE',{}, ...
               'numRx',{},'pathLossModel',{});
exIdx = 0;

%% Create one master IQ CSV file
masterCSV = fullfile(outRoot, "master_iq_dataset.csv");
fidIQ = fopen(masterCSV, "w");

% Write simplified header
fprintf(fidIQ, 'I_component,Q_component,label,SNR_dB,SIR_dB,numRx,numUE,');
for k = 1:numUE
    fprintf(fidIQ, 'UE%d_x,UE%d_y,UE%d_z,', k, k, k);
end
fprintf(fidIQ, 'gNB_x,gNB_y,gNB_z,radar_x,radar_y,radar_z,pathLossModel\n');

%% 6  Main loop to generate IQ data
for c = 1:numel(classNames)

    for n = 1:numExamplesPerClass

        % 6a  Base transmit signals
        x5gBase    = wave5gSig;
        xRadarBase = radarSig;

        % Optional random time shift for radar
        if classNames(c) == "Radar_plus_5G"
            shiftRadarSamples = randi([0 floor(0.5 * Nmin)]);
            xRadarBase = circshift(xRadarBase, shiftRadarSamples);
        else
            shiftRadarSamples = 0;
        end

        % 6b  Random UE positions and channels
        y5g_MIMO = zeros(Nmin, numRx);
        UEpos = zeros(numUE, 3);
        h_eff_sum = zeros(numRx, 1);

        pathLossModel = randi([1 3]);
        fc_GHz = fc / 1e9;

        for k = 1:numUE
            r     = cellRmin + (cellRmax - cellRmin) * rand();
            theta = 2*pi*rand();
            UEpos(k,:) = [r*cos(theta) r*sin(theta) 0];

            d = norm(UEpos(k,:) - gNBPos);

            switch pathLossModel
                case 1
                    PL_dB = 20*log10(4*pi*d/lambda);

                case 2
                    d0 = 1;
                    n_exp = 3.2;
                    sigma_sf = 6;
                    PL0 = 20*log10(4*pi*d0/lambda);
                    X_sigma = sigma_sf * randn;
                    PL_dB = PL0 + 10*n_exp*log10(d/d0) + X_sigma;

                case 3
                    PL_dB = 32.4 + 20*log10(fc_GHz) + 30*log10(d);
            end

            PL_lin = 10^(PL_dB/10);

            h_UE = (randn(numRx,1) + 1j*randn(numRx,1)) / sqrt(2);
            h_eff = h_UE / sqrt(PL_lin);
            h_eff_sum = h_eff_sum + h_eff;

            shiftUE = randi([0 floor(0.2 * Nmin)]);
            x5g_UE  = circshift(x5gBase, shiftUE);

            for m = 1:numRx
                y5g_MIMO(:,m) = y5g_MIMO(:,m) + h_eff(m) * x5g_UE;
            end
        end

        % 6c  Radar channel to MIMO receiver
        dRadar  = norm(radarPos - gNBPos);
        PLr_dB  = 20*log10(4*pi*dRadar/lambda);
        PLr_lin = 10^(PLr_dB/10);

        h_radar     = (randn(numRx,1) + 1j*randn(numRx,1)) / sqrt(2);
        h_radar_eff = h_radar / sqrt(PLr_lin);

        yRadar_MIMO = zeros(Nmin, numRx);
        for m = 1:numRx
            yRadar_MIMO(:,m) = h_radar_eff(m) * xRadarBase;
        end

        % 6d  Build clean MIMO received signal depending on class
        if classNames(c) == "5G_only"
            s_clean_MIMO = y5g_MIMO;
            SIR_dB = NaN;
            label = 0;

        elseif classNames(c) == "Radar_plus_5G"
            SIR_dB     = SIR_range_dB(1) + rand() * diff(SIR_range_dB);
            Pr_over_Pc = 10^(SIR_dB/10);

            P5g   = mean(abs(y5g_MIMO).^2, "all");
            Prad0 = mean(abs(yRadar_MIMO).^2, "all");

            beta = sqrt(Pr_over_Pc * P5g / (Prad0 + 1e-12));

            s_clean_MIMO = y5g_MIMO + beta * yRadar_MIMO;
            label = 1;
        end

        % 6e  MRC combining across antennas
        if norm(h_eff_sum) > 0
            w = conj(h_eff_sum) / norm(h_eff_sum);
        else
            w = ones(numRx,1) / sqrt(numRx);
        end

        s_clean = s_clean_MIMO * w;

        % 6f  Add noise at random SNR
        SNR_dB    = SNR_range_dB(1) + rand() * diff(SNR_range_dB);
        sig_pow   = rms(s_clean)^2;
        noise_pow = sig_pow / 10^(SNR_dB/10);
        noise     = sqrt(noise_pow/2) * (randn(size(s_clean)) + 1j*randn(size(s_clean)));

        s_rx = s_clean + noise;

        % Convert path loss model to name
        if pathLossModel == 1
            plName = "FSPL";
        elseif pathLossModel == 2
            plName = "LogDistance";
        else
            plName = "UMa";
        end

        % Flatten UE positions
        UE_flat = reshape(UEpos.', 1, []);

        % Downsample to avoid huge CSV
        max_points = 2000;
        indices = unique(round(linspace(1, length(s_rx), max_points)));

        % Write only the IQ data and desired metadata columns
        for idx = indices
            fprintf(fidIQ, '%.12f,%.12f,%d,%.4f,%.4f,%d,%d,', ...
                real(s_rx(idx)), imag(s_rx(idx)), label, ...
                SNR_dB, SIR_dB, numRx, numUE);

            fprintf(fidIQ, '%.4f,', UE_flat);

            fprintf(fidIQ, '%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%s\n', ...
                gNBPos(1), gNBPos(2), gNBPos(3), ...
                radarPos(1), radarPos(2), radarPos(3), ...
                plName);
        end

        % Store metadata
        exIdx = exIdx + 1;
        meta(exIdx).class      = char(classNames(c));
        meta(exIdx).exampleIdx = n;
        meta(exIdx).fileName   = sprintf("%s_example_%03d", string(classNames(c)), n);
        meta(exIdx).SNR_dB     = SNR_dB;
        meta(exIdx).SIR_dB     = SIR_dB;
        meta(exIdx).UEpos      = UEpos;
        meta(exIdx).gNBPos     = gNBPos;
        meta(exIdx).radarPos   = radarPos;
        meta(exIdx).numUE      = numUE;
        meta(exIdx).numRx      = numRx;
        meta(exIdx).pathLossModel = plName;
    end
end

fclose(fidIQ);
fprintf("Saved master IQ CSV to %s\n", masterCSV);

disp("IQ dataset generation complete");

%% 7  Save metadata to .mat
metaFileMAT = fullfile(outRoot, "metadata.mat");
save(metaFileMAT, "meta");
fprintf("Saved metadata struct to %s\n", metaFileMAT);

%% 8  Save metadata to .csv
metaFileCSV = fullfile(outRoot, "metadata.csv");
fid = fopen(metaFileCSV, "w");

fprintf(fid, "idx,class,filename,SNR_dB,SIR_dB,");
for k = 1:numUE
    fprintf(fid, "UE%d_x,UE%d_y,UE%d_z,", k, k, k);
end
fprintf(fid, "gNB_x,gNB_y,gNB_z,radar_x,radar_y,radar_z,pathLossModel,numUE,numRx\n");

for i = 1:numel(meta)
    m = meta(i);

    fprintf(fid, "%d,%s,%s,%.4f,%.4f,", ...
        i, m.class, m.fileName, m.SNR_dB, m.SIR_dB);

    UEp = m.UEpos;
    if size(UEp,1) < numUE
        UEp(numUE,1:3) = 0;
    end

    for k = 1:numUE
        fprintf(fid, "%.4f,%.4f,%.4f,", UEp(k,1), UEp(k,2), UEp(k,3));
    end

    fprintf(fid, "%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%d,%d\n", ...
        m.gNBPos(1), m.gNBPos(2), m.gNBPos(3), ...
        m.radarPos(1), m.radarPos(2), m.radarPos(3), ...
        m.pathLossModel, m.numUE, m.numRx);
end

fclose(fid);
fprintf("Saved metadata table to %s\n", metaFileCSV);

disp("Dataset generation complete with IQ data and metadata.");