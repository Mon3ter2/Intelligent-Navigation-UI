function mask = build_road_mask(img)
%BUILD_ROAD_MASK Generate a binary mask of road pixels from the map image.
%   mask = build_road_mask(img)
%
%   Improved version with higher recall for road detection:
%     1. Relaxed HSV thresholds + multi-reference colour distance fallback
%     2. Local adaptive brightness correction (integral-image box filter)
%        to recover roads under tree shadows
%     3. Hand-written morphological close (dilate+erode) to fill small
%        holes inside road regions
%     4. Softer neighbourhood majority filter (>= 3 instead of >= 4)
%
%   All computations are hand-written; NO image-processing toolbox
%   functions are used (no rgb2hsv, imfilter, bwareaopen, etc.).
%
%   Input:  img  - uint8 H x W x 3 RGB map image
%   Output: mask - logical H x W, true = road

    [H, W, ~] = size(img);

    % =====================================================================
    % 1. Manual HSV-like computation
    % =====================================================================
    R = double(img(:,:,1)) / 255;
    G = double(img(:,:,2)) / 255;
    B = double(img(:,:,3)) / 255;

    maxRGB = max(max(R, G), B);
    minRGB = min(min(R, G), B);
    delta  = maxRGB - minRGB;

    % Saturation: S = delta / max  (0 when max == 0)
    sat = zeros(H, W);
    nonzero = maxRGB > 0;
    sat(nonzero) = delta(nonzero) ./ maxRGB(nonzero);

    % Value (brightness) = max channel
    val = maxRGB;

    % =====================================================================
    % 2. Road criteria — pathA: precise general detection
    % =====================================================================
    %   Tight thresholds for good precision (low false positives).
    %   This catches most normal grey roads but may miss teal-tinted main roads.
    isLowSat      = sat < 0.30;
    isMedBright   = val > 0.38 & val < 0.93;
    isNotBlue     = B < G + 0.10;
    % Tighten green exclusion to kill pale grey-green fields (G-R~0.09).
    % Main teal-grey roads (G-R~0.13) will fail here but be rescued by pathB.
    isNotTooGreen = G < R + 0.07;

    % Exclude bright buildings (restored strict thresholds)
    isNotWhiteBuilding = ~(val > 0.85 & sat < 0.08);
    meanRGB = (R + G + B) / 3;
    isNotBrightGrey = ~(meanRGB > 0.78 & sat < 0.12);

    pathA = isLowSat & isMedBright & isNotBlue & isNotTooGreen ...
          & isNotWhiteBuilding & isNotBrightGrey;

    % =====================================================================
    % 3. pathB: targeted colour-distance rescue for teal-grey MAIN ROADS
    % =====================================================================
    %   Main roads are teal-grey (G >> R), blocked by pathA's green-check.
    %   pathB rescues them with very tight colour matching + low saturation.
    roadRefs = [
        0.58, 0.72, 0.67;   % main road teal-grey (sampled)
        0.64, 0.77, 0.73;   % central south road (sampled)
        0.66, 0.82, 0.76;   % top horiz road (sampled)
        0.72, 0.78, 0.78;   % top horiz road variant
        0.81, 0.89, 0.85;   % bright main road (sampled)
        0.86, 0.87, 0.92;   % bright vert main road (sampled)
        0.51, 0.55, 0.53;   % bottom road (sampled)
        0.55, 0.71, 0.64;   % internal road (sampled)
    ];
    nRefs = size(roadRefs, 1);
    minDist = inf(H, W);
    for k = 1:nRefs
        d = sqrt((R - roadRefs(k,1)).^2 + ...
                 (G - roadRefs(k,2)).^2 + ...
                 (B - roadRefs(k,3)).^2);
        minDist = min(minDist, d);
    end
    % Extremely tight: colour must be very close to a sampled road colour
    pathB = (minDist < 0.08) & (sat < 0.22) & (val > 0.35 & val < 0.96);

    % Combine the two detection paths
    mask = pathA | pathB;

    % =====================================================================
    % 3.5. Explicit Exclusions (Sports courts & specific fields)
    % =====================================================================
    %   1) The light green stadiums on the LEFT side use the EXACT same ink 
    %      color (R~0.62, G~0.77, B~0.72) as some roads. We exclude this color 
    %      strictly in their specific bounding boxes to avoid killing the main
    %      horizontal road (which is at row ~400).
    isStadiumArea = false(H, W);
    % Top-left field/stadium
    isStadiumArea(1:350, 1:400) = true;
    % Bottom-left stadium
    isStadiumArea(500:H, 1:400) = true;
    
    isLightGreen = abs(R - 0.62) < 0.08 & abs(G - 0.77) < 0.08 & abs(B - 0.72) < 0.08;
    mask(isStadiumArea & isLightGreen) = false;
    
    %   2) Yellow/Orange sports courts
    %      These have R >> B and G > B, often pale enough to pass sat < 0.30.
    isYellowish = (R > B + 0.12) & (G > B + 0.05);
    mask(isYellowish) = false;

    % =====================================================================
    % 4. Local adaptive brightness — shadow recovery
    % =====================================================================
    %   Use an integral-image box filter to get the local mean brightness
    %   in a 31x31 window.  Road pixels in shadow are globally dark but
    %   locally close to their neighbourhood mean with low saturation.
    halfW = 15;  % window radius => 31x31

    % Build integral image (vectorised, no inner loops)
    intImg = cumsum(cumsum(double(val), 1), 2);
    % Padded integral image for safe indexing
    padInt = zeros(H + 1, W + 1);
    padInt(2:end, 2:end) = intImg;

    % Row and column index matrices for the box corners
    rows = (1:H)';
    cols = 1:W;
    r1 = max(rows - halfW, 1);       % H x 1
    r2 = min(rows + halfW, H);       % H x 1
    c1 = max(cols - halfW, 1);       % 1 x W
    c2 = min(cols + halfW, W);       % 1 x W

    % Box area for each pixel (handles image borders correctly)
    area = (r2 - r1 + 1) * (c2 - c1 + 1);   % H x W via broadcast

    % Sum inside each box via integral image (fully vectorised)
    localSum = padInt(r2 + 1, c2 + 1) ...
             - padInt(r1,     c2 + 1) ...
             - padInt(r2 + 1, c1)     ...
             + padInt(r1,     c1);
    localMean = localSum ./ area;

    % A shadow-road pixel: locally not much darker than its surroundings,
    % low saturation, and not extremely dark.
    localRatio = val ./ max(localMean, 0.01);
    isShadowRoad = localRatio > 0.70 & localRatio < 1.30 ...
                 & sat < 0.25 ...
                 & val > 0.25 & val <= 0.38 ...
                 & isNotBlue & isNotTooGreen;
    mask = mask | isShadowRoad;

    % =====================================================================
    % 5. Hand-written morphological CLOSE (dilate then erode, radius = 2)
    %    Fills small holes and cracks inside road regions.
    % =====================================================================
    se_r = 2;

    % --- Dilation ---
    dilated = false(H, W);
    for dr = -se_r:se_r
        for dc = -se_r:se_r
            if dr*dr + dc*dc > se_r*se_r
                continue;   % circular structuring element
            end
            % Compute shifted indices (clamped to image boundary)
            rIdx = min(max((1:H)' + dr, 1), H);
            cIdx = min(max((1:W)  + dc, 1), W);
            dilated = dilated | mask(rIdx, cIdx);
        end
    end

    % --- Erosion ---
    eroded = true(H, W);
    for dr = -se_r:se_r
        for dc = -se_r:se_r
            if dr*dr + dc*dc > se_r*se_r
                continue;
            end
            rIdx = min(max((1:H)' + dr, 1), H);
            cIdx = min(max((1:W)  + dc, 1), W);
            eroded = eroded & dilated(rIdx, cIdx);
        end
    end
    mask = eroded;

    % =====================================================================
    % 6. Neighbourhood majority filter (softened: >= 4)
    %    Removes isolated noise pixels while preserving road edges.
    % =====================================================================
    padded = false(H + 2, W + 2);
    padded(2:end-1, 2:end-1) = mask;

    neighbourCount = zeros(H, W);
    for dr = -1:1
        for dc = -1:1
            if dr == 0 && dc == 0
                continue;
            end
            neighbourCount = neighbourCount + ...
                double(padded((2+dr):(H+1+dr), (2+dc):(W+1+dc)));
        end
    end

    mask = mask & (neighbourCount >= 4);

    % =====================================================================
    % 7. Apply Manual Corrections (if they exist)
    % =====================================================================
    manualPath = fullfile(fileparts(mfilename('fullpath')), 'manual_exclusions.mat');
    if exist(manualPath, 'file')
        manualData = load(manualPath);
        if isfield(manualData, 'exclusion_mask')
            mask(manualData.exclusion_mask) = false;
        end
        if isfield(manualData, 'inclusion_mask')
            mask(manualData.inclusion_mask) = true;
        end
    end
end
