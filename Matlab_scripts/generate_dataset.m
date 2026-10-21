%% DATASET GENERATION SCRIPT
% Creates spectrogram images for radar detection using:
% - Multiple radar waveform types selected randomly
% - Multiple UEs
% - MIMO reception
% - Random SNR and SIR
% - Multiple path-loss models
% - Per-example metadata

clear;
clc;

%% 1. Load 5G and radar waveforms
load("workspace.mat");

% Expected variables in workspace.mat:
%   wave5g      -> structure with fields .waveform and .Fs
%   Radar       -> LFM radar structure
%   fcmw_radar  -> FMCW radar structure
%   nonlfmw     -> nonlinear FM radar structure
%   phasecoded  -> phase-coded radar structure

wave5gSig = wave5g.waveform(:);
Fs5g      = wave5g.Fs;
Fs        = Fs5g;

% Store the radar structures in one cell array.
% The names must follow the same order as the structures.
radarBank = {
    Radar_LFM
    Radar_FMCW
    Radar_NLFM
    Radar_P4
};

radarNames = [
    "LFM"
    "FMCW"
    "NLFM"
    "P4"
];

numRadarTypes = numel(radarBank);

% Verify that every radar uses the same sampling rate as the 5G waveform.
%% Match all radar sample rates to the 5G sample rate

for r = 1:numRadarTypes

    currentRadar = radarBank{r};

    radarFs = currentRadar.Fs;
    radarWaveform = currentRadar.waveform(:);

    if radarFs ~= Fs5g

        fprintf( ...
            "Resampling %s radar from %.2f MHz to %.2f MHz...\n", ...
            radarNames(r), radarFs/1e6, Fs5g/1e6);

        % Find an integer approximation to the rate ratio.
        [p, q] = rat(Fs5g / radarFs);

        % Resample the complex radar waveform.
        radarWaveform = resample(radarWaveform, p, q);

        % Update the waveform and sampling rate in the radar bank.
        currentRadar.waveform = radarWaveform;
        currentRadar.Fs = Fs5g;

        radarBank{r} = currentRadar;
    end
end

%% 2. Normalize the 5G waveform
wave5gSig = wave5gSig / (rms(wave5gSig) + eps);
N5g       = length(wave5gSig);

%% 3. Create output folders
outRoot    = "dataset";
classNames = ["5G_only", "Radar_plus_5G"];

for c = 1:numel(classNames)
    folderName = fullfile(outRoot, classNames(c));

    if ~exist(folderName, "dir")
        mkdir(folderName);
    end
end

%% 4. Random-scenario parameters
numExamplesPerClass = 2500;

SNR_range_dB = [0 25];
SIR_range_dB = [-10 10];

% STFT parameters
winLen  = 512;
win     = hamming(winLen);
overlap = round(0.5 * winLen);
nfft    = 1024;

%% 5. Geometry and MIMO parameters
numUE = 3;
numRx = 4;

gNBPos   = [0 0 0];
radarPos = [3000 400 0];

fc      = 3.8e9;
c0      = 3e8;
lambda  = c0 / fc;
fc_GHz  = fc / 1e9;

cellRmin = 100;
cellRmax = 1500;

%% 6. Metadata container
meta = struct( ...
    'class',{}, ...
    'radarType',{}, ...
    'radarIndex',{}, ...
    'exampleIdx',{}, ...
    'fileName',{}, ...
    'SNR_dB',{}, ...
    'SIR_dB',{}, ...
    'SINR_dB',{}, ...
    'UEpos',{}, ...
    'gNBPos',{}, ...
    'radarPos',{}, ...
    'numUE',{}, ...
    'numRx',{}, ...
    'pathLossModel',{});

exIdx = 0;

%% 7. Main generation loop
for c = 1:numel(classNames)

    for n = 1:numExamplesPerClass

        %% 7a. Prepare the 5G waveform
        x5gBase = wave5gSig;
        Nmin    = N5g;

        %% 7b. Randomly select and prepare a radar waveform
        if classNames(c) == "Radar_plus_5G"

            % Randomly select one radar type.
            radarIdx     = randi(numRadarTypes);
            selectedRadar = radarBank{radarIdx};
            radarType     = radarNames(radarIdx);

            % Force a column vector and normalize it.
            xRadarBase = selectedRadar.waveform(:);
            xRadarBase = xRadarBase / (rms(xRadarBase) + eps);

            % Match the selected radar length to the 5G waveform length.
            if length(xRadarBase) < Nmin
                repetitions = ceil(Nmin / length(xRadarBase));
                xRadarBase  = repmat(xRadarBase, repetitions, 1);
                xRadarBase  = xRadarBase(1:Nmin);

            elseif length(xRadarBase) > Nmin
                xRadarBase = xRadarBase(1:Nmin);
            end

            % Randomly shift the radar waveform in time.
            shiftRadarSamples = randi([0 floor(0.5 * Nmin)]);
            xRadarBase = circshift(xRadarBase, shiftRadarSamples);

        else
            % No radar for the 5G-only class.
            radarIdx           = 0;
            radarType          = "None";
            shiftRadarSamples  = 0;
            xRadarBase         = zeros(Nmin, 1);
        end

        %% 7c. Generate random UE positions and 5G MIMO channels
        y5g_MIMO = zeros(Nmin, numRx);
        UEpos     = zeros(numUE, 3);
        h_eff_sum = zeros(numRx, 1);

        % One path-loss model is selected for the entire example:
        % 1 = Free-space path loss
        % 2 = Log-distance with shadowing
        % 3 = Urban macro approximation
        pathLossModel = randi([1 3]);

        for k = 1:numUE

            % Random UE position.
            rUE   = cellRmin + (cellRmax - cellRmin) * rand();
            theta = 2*pi*rand();

            UEpos(k,:) = [rUE*cos(theta), rUE*sin(theta), 0];

            % UE-to-gNB distance.
            d = norm(UEpos(k,:) - gNBPos);

            switch pathLossModel

                case 1
                    % Free-space path loss
                    PL_dB = 20*log10(4*pi*d/lambda);

                case 2
                    % Log-distance model with shadow fading
                    d0       = 1;
                    n_exp    = 3.2;
                    sigma_sf = 6;

                    PL0     = 20*log10(4*pi*d0/lambda);
                    X_sigma = sigma_sf * randn;

                    PL_dB = PL0 + 10*n_exp*log10(d/d0) + X_sigma;

                case 3
                    % Urban macro approximation
                    PL_dB = 32.4 + 20*log10(fc_GHz) + 30*log10(d);
            end

            PL_lin = 10^(PL_dB/10);

            % Rayleigh fading channel for this UE.
            h_UE = (randn(numRx,1) + 1j*randn(numRx,1)) / sqrt(2);

            % Apply path loss.
            h_eff = h_UE / sqrt(PL_lin);

            % Accumulate the effective channel for MRC.
            h_eff_sum = h_eff_sum + h_eff;

            % Random timing offset for each UE.
            shiftUE = randi([0 floor(0.2 * Nmin)]);
            x5g_UE  = circshift(x5gBase, shiftUE);

            % Add this UE contribution to all receive antennas.
            for m = 1:numRx
                y5g_MIMO(:,m) = y5g_MIMO(:,m) + h_eff(m) * x5g_UE;
            end
        end

        %% 7d. Generate the radar MIMO channel
        yRadar_MIMO = zeros(Nmin, numRx);

        if classNames(c) == "Radar_plus_5G"

            dRadar  = norm(radarPos - gNBPos);
            PLr_dB  = 20*log10(4*pi*dRadar/lambda);
            PLr_lin = 10^(PLr_dB/10);

            h_radar = ...
                (randn(numRx,1) + 1j*randn(numRx,1)) / sqrt(2);

            h_radar_eff = h_radar / sqrt(PLr_lin);

            for m = 1:numRx
                yRadar_MIMO(:,m) = ...
                    h_radar_eff(m) * xRadarBase;
            end
        end

        %% 7e. Combine 5G and radar according to the target SIR
        if classNames(c) == "5G_only"

            s_clean_MIMO = y5g_MIMO;
            SIR_dB       = NaN;

        else

            % Draw the desired 5G-to-radar ratio.
            SIR_dB     = SIR_range_dB(1) + ...
                         rand() * diff(SIR_range_dB);

            Pr_over_Pc = 10^(SIR_dB/10);

            % Measure the received powers before radar scaling.
            P5g   = mean(abs(y5g_MIMO).^2, "all");
            Prad0 = mean(abs(yRadar_MIMO).^2, "all");

            % Scale radar power to achieve the selected SIR.
            beta = sqrt(Pr_over_Pc * P5g / (Prad0 + 1e-12));

            s_clean_MIMO = y5g_MIMO + beta * yRadar_MIMO;
        end

        %% 7f. MRC combining
        if norm(h_eff_sum) > 0
            w = conj(h_eff_sum) / norm(h_eff_sum);
        else
            w = ones(numRx,1) / sqrt(numRx);
        end

        s_clean = s_clean_MIMO * w;

        %% 7g. Add complex Gaussian noise
        SNR_dB = SNR_range_dB(1) + ...
                 rand() * diff(SNR_range_dB);

        sig_pow   = rms(s_clean)^2;
        noise_pow = sig_pow / 10^(SNR_dB/10);

        noise = sqrt(noise_pow/2) .* ...
            (randn(size(s_clean)) + 1j*randn(size(s_clean)));

        s_rx = s_clean + noise;

        %% 7h. Compute SINR
        if isnan(SIR_dB)
            SINR_dB = SNR_dB;
        else
            SNR_lin = 10^(SNR_dB/10);
            SIR_lin = 10^(SIR_dB/10);

            SINR_lin = 1 / ((1/SNR_lin) + (1/SIR_lin));
            SINR_dB  = 10*log10(SINR_lin);
        end

        %% 7i. Generate the spectrogram
        [STFT, ~, ~] = spectrogram( ...
            s_rx, ...
            win, ...
            overlap, ...
            nfft, ...
            Fs, ...
            "centered");

        S_mag = abs(STFT);
        S_db  = 20*log10(S_mag + 1e-12);

        % Normalize the spectrogram to the range [-60, 0] dB.
        S_db_norm = S_db - max(S_db(:));
        S_img     = mat2gray(S_db_norm, [-60 0]);

        %% 7j. Build filename tags
        snrTag = sprintf("SNR%+04.1f", SNR_dB);
        snrTag = replace(snrTag, ".", "p");

        if isnan(SIR_dB)
            sirTag = "SIRNA";
        else
            sirTag = sprintf("SIR%+04.1f", SIR_dB);
            sirTag = replace(sirTag, ".", "p");
        end

        radarTag = replace(radarType, " ", "_");
        cls      = string(classNames(c));

        fileName = sprintf( ...
            "%s_%s_%s_%s_example_%04d.png", ...
            cls, ...
            radarTag, ...
            snrTag, ...
            sirTag, ...
            n);

        fullPath = fullfile(outRoot, cls, fileName);

        imwrite(S_img, fullPath);
        fprintf("Saved %s\n", fullPath);

        %% 7k. Store metadata
        exIdx = exIdx + 1;

        switch pathLossModel
            case 1
                pathLossName = "FSPL";
            case 2
                pathLossName = "LogDistance";
            case 3
                pathLossName = "UMa";
        end

        meta(exIdx).class         = char(classNames(c));
        meta(exIdx).radarType     = char(radarType);
        meta(exIdx).radarIndex    = radarIdx;
        meta(exIdx).exampleIdx    = n;
        meta(exIdx).fileName      = fileName;
        meta(exIdx).SNR_dB        = SNR_dB;
        meta(exIdx).SIR_dB        = SIR_dB;
        meta(exIdx).SINR_dB       = SINR_dB;
        meta(exIdx).UEpos         = UEpos;
        meta(exIdx).gNBPos        = gNBPos;
        meta(exIdx).radarPos      = radarPos;
        meta(exIdx).numUE         = numUE;
        meta(exIdx).numRx         = numRx;
        meta(exIdx).pathLossModel = char(pathLossName);
    end
end

disp("Image dataset generation complete.");

%% 8. Save metadata to MAT file
metaFileMAT = fullfile(outRoot, "metadata.mat");
save(metaFileMAT, "meta");

fprintf("Saved metadata structure to %s\n", metaFileMAT);

%% 9. Save metadata to CSV
metaFileCSV = fullfile(outRoot, "metadata.csv");
fid = fopen(metaFileCSV, "w");

assert(fid ~= -1, "Could not open metadata CSV file for writing.");

fprintf( ...
    fid, ...
    "idx,class,radarType,radarIndex,filename,SNR_dB,SIR_dB,SINR_dB,");

for k = 1:numUE
    fprintf(fid, "UE%d_x,UE%d_y,UE%d_z,", k, k, k);
end

fprintf( ...
    fid, ...
    "gNB_x,gNB_y,gNB_z,radar_x,radar_y,radar_z," + ...
    "pathLossModel,numUE,numRx\n");

for i = 1:numel(meta)

    m = meta(i);

    fprintf( ...
        fid, ...
        "%d,%s,%s,%d,%s,%.4f,%.4f,%.4f,", ...
        i, ...
        m.class, ...
        m.radarType, ...
        m.radarIndex, ...
        m.fileName, ...
        m.SNR_dB, ...
        m.SIR_dB, ...
        m.SINR_dB);

    UEp = m.UEpos;

    if size(UEp,1) < numUE
        UEp(numUE,1:3) = 0;
    end

    for k = 1:numUE
        fprintf( ...
            fid, ...
            "%.4f,%.4f,%.4f,", ...
            UEp(k,1), ...
            UEp(k,2), ...
            UEp(k,3));
    end

    fprintf( ...
        fid, ...
        "%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%d,%d\n", ...
        m.gNBPos(1), ...
        m.gNBPos(2), ...
        m.gNBPos(3), ...
        m.radarPos(1), ...
        m.radarPos(2), ...
        m.radarPos(3), ...
        m.pathLossModel, ...
        m.numUE, ...
        m.numRx);
end

fclose(fid);

fprintf("Saved metadata table to %s\n", metaFileCSV);
disp("Dataset generation complete with randomized radar types.");