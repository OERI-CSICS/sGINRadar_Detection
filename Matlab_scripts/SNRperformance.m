%% Performance vs SNR and SIR for wavelet + linear detector
clear; clc;
rng(1234);

%% 1  Load dataset metadata and trained model

% Image datastore
imds = imageDatastore("dataset", ...
    "IncludeSubfolders", true, ...
    "LabelSource", "foldernames");

numImages  = numel(imds.Files);
labelsCat  = imds.Labels;                  % categorical: 5G_only, Radar_plus_5G
labels     = zeros(numImages, 1);
labels(labelsCat == "Radar_plus_5G") = 1;  % 0 = 5G only, 1 = Radar present

% Metadata with SNR and SIR
metaData   = load(fullfile("dataset","metadata.mat"));
meta       = metaData.meta;

% Trained model from previous script
load("wavelet_linear_bestModel.mat", ...
     "linModel_best");   % we will recompute X here

%% 2  Align each image with SNR and SIR using filenames

snrPerImg = zeros(numImages,1);
sirPerImg = zeros(numImages,1);

allMetaNames = strings(numel(meta),1);
for k = 1:numel(meta)
    allMetaNames(k) = string(meta(k).fileName);
end

for i = 1:numImages
    [~, base, ext] = fileparts(imds.Files{i});

    % Convert to string before concatenation
    thisName = string(base) + string(ext);   % e.g. "Radar_plus_5G_example_001.png"

    idx = find(allMetaNames == thisName, 1);
    if isempty(idx)
        error("Could not find metadata entry for %s", thisName);
    end

    snrPerImg(i) = meta(idx).SNR_dB;    % SNR in dB
    sirPerImg(i) = meta(idx).SIR_dB;    % SIR in dB, NaN for 5G only
end

fprintf("Metadata alignment complete. %d images mapped to SNR and SIR.\n", numImages);

%% 3  Recompute 6 dimensional wavelet features X for each image

featHaar     = zeros(numImages, 3);   % [E_CH, E_CV, E_CD]
featDaub     = zeros(numImages, 3);

for i = 1:numImages
    I = imread(imds.Files{i});
    I = im2double(I);
    if size(I,3) == 3
        I = rgb2gray(I);
    end

    Id = imgaussfilt(I, 1);

    [~, CHh, CVh, CDh] = dwt2(Id, "haar");
    [~, CHd, CVd, CDd] = dwt2(Id, "db4");

    featHaar(i,:) = [sum(abs(CHh(:))), sum(abs(CVh(:))), sum(abs(CDh(:)))];
    featDaub(i,:) = [sum(abs(CHd(:))), sum(abs(CVd(:))), sum(abs(CDd(:)))];
end

X = [featHaar, featDaub];   % [numImages x 6]

%% 4  Predict on all images with the frozen linear model

[predAll, ~] = predict(linModel_best, X);

% Global metrics for sanity check
[Mglobal, cmGlobal] = numeric_metrics(labels, predAll);
fprintf("\nGlobal performance over all SNR and SIR:\n");
disp(cmGlobal);
fprintf("  Acc: %.3f  Pd: %.3f  Pfa: %.3f\n", ...
    Mglobal.accuracy, Mglobal.Pd, Mglobal.Pfa);

%% 5  Performance vs SNR (bins)

snrEdges = 0:5:30;                 % adjust as you like
numSNRbins = numel(snrEdges) - 1;
snrCenters = 0.5 * (snrEdges(1:end-1) + snrEdges(2:end));

accSNR = nan(numSNRbins,1);
PdSNR  = nan(numSNRbins,1);
PfaSNR = nan(numSNRbins,1);

for b = 1:numSNRbins
    idxBin = snrPerImg >= snrEdges(b) & snrPerImg < snrEdges(b+1);

    if nnz(idxBin) < 5
        % not enough samples in this bin
        continue;
    end

    yTrueBin = labels(idxBin);
    yPredBin = predAll(idxBin);

    [Mb, ~] = numeric_metrics(yTrueBin, yPredBin);

    accSNR(b) = Mb.accuracy;
    PdSNR(b)  = Mb.Pd;
    PfaSNR(b) = Mb.Pfa;
end

%% 6  Performance vs SIR (bins, radar only)

sirEdges   = -15:5:15;               % SIR range from dataset
numSIRbins = numel(sirEdges) - 1;
sirCenters = 0.5 * (sirEdges(1:end-1) + sirEdges(2:end));

PdSIR = nan(numSIRbins,1);

for b = 1:numSIRbins
    % Only radar present samples (label = 1) with valid SIR
    idxBin = labels == 1 & ~isnan(sirPerImg) & ...
             sirPerImg >= sirEdges(b) & sirPerImg < sirEdges(b+1);

    if nnz(idxBin) < 5
        continue;
    end

    yTrueBin = labels(idxBin);
    yPredBin = predAll(idxBin);

    % For SIR we care mainly about detection probability
    TP = sum(yPredBin == 1 & yTrueBin == 1);
    FN = sum(yPredBin == 0 & yTrueBin == 1);
    PdSIR(b) = TP / (TP + FN + eps);
end

%% 7  Plot metrics vs SNR

figure;
subplot(3,1,1);
plot(snrCenters, accSNR, "o-");
xlabel("SNR (dB)");
ylabel("Accuracy");
grid on;

subplot(3,1,2);
plot(snrCenters, PdSNR, "o-");
xlabel("SNR (dB)");
ylabel("Pd");
grid on;

subplot(3,1,3);
plot(snrCenters, PfaSNR, "o-");
xlabel("SNR (dB)");
ylabel("Pfa");
grid on;

sgtitle("Wavelet plus linear detector performance vs SNR");

%% 8  Plot detection probability vs SIR

figure;
plot(sirCenters, PdSIR, "o-");
xlabel("SIR (dB)");
ylabel("Pd for radar present");
grid on;
title("Detection probability vs SIR (radar only)");

%% Local metrics function

function [M, cm] = numeric_metrics(yTrue, yPred)
    cm = confusionmat(yTrue, yPred, "Order", [0 1]);

    TN = cm(1,1);
    FP = cm(1,2);
    FN = cm(2,1);
    TP = cm(2,2);

    total = TN + FP + FN + TP;

    M.accuracy = (TP + TN) / total;
    M.Pd       = TP / (TP + FN + eps);
    M.Pfa      = FP / (FP + TN + eps);
end
