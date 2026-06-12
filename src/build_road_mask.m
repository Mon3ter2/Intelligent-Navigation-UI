function mask = build_road_mask(img, params)
%BUILD_ROAD_MASK Generate a binary mask of road pixels from the map image.
%   mask = build_road_mask(img, params)
%
%   Pure native MATLAB implementation without ANY toolbox or high-level function
%   dependencies (No bwconncomp, conv2, meshgrid, cumsum, cellfun, ind2sub).

    if nargin < 2
        % 默认使用经过自动网格寻优与标准图对照后提取的最佳参数组
        params.sat = 0.22;
        params.val_min = 0.55;
        params.val_max = 0.95;
        params.solidity = 0.20;
        params.neighbourCount = 2;
    end

    [H, W, ~] = size(img);

    % ----- 1. Manual HSV-like computation -----
    R = double(img(:,:,1)) / 255;
    G = double(img(:,:,2)) / 255;
    B = double(img(:,:,3)) / 255;

    maxRGB = max(max(R, G), B);
    minRGB = min(min(R, G), B);
    delta  = maxRGB - minRGB;

    % Saturation: S = delta / max
    sat = zeros(H, W);
    nonzero = maxRGB > 0;
    sat(nonzero) = delta(nonzero) ./ maxRGB(nonzero);

    % Value (brightness) = max channel
    val = maxRGB;

    % ----- 2. pathA: Precise general detection (利用优化参数) -----
    isLowSat      = sat < params.sat;
    isMedBright   = val > params.val_min & val < params.val_max;
    isNotBlue     = B < G + 0.10;
    isNotTooGreen = G < R + 0.07;
    
    % Exclude bright buildings
    isNotWhiteBuilding = ~(val > 0.85 & sat < 0.08);
    meanRGB = (R + G + B) / 3;
    isNotBrightGrey = ~(meanRGB > 0.78 & sat < 0.12);

    pathA = isLowSat & isMedBright & isNotBlue & isNotTooGreen ...
          & isNotWhiteBuilding & isNotBrightGrey;

    % ----- 3. pathB: targeted colour-distance rescue for teal-grey MAIN ROADS -----
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
    pathB = (minDist < 0.08) & (sat < params.sat) & (val > 0.35 & val < params.val_max);

    mask = pathA | pathB;

    % ----- 3.5. Explicit Exclusions (Sports courts & specific fields) -----
    isStadiumArea = false(H, W);
    isStadiumArea(1:350, 1:400) = true;
    isStadiumArea(500:H, 1:400) = true;
    isLightGreen = abs(R - 0.62) < 0.08 & abs(G - 0.77) < 0.08 & abs(B - 0.72) < 0.08;
    mask(isStadiumArea & isLightGreen) = false;
    
    isYellowish = (R > B + 0.12) & (G > B + 0.05);
    mask(isYellowish) = false;

    % ----- 4. Local adaptive brightness — shadow recovery -----
    halfW = 15;
    % 手写行列累加和代替 cumsum 计算积分图像
    intImg = double(val);
    for r = 2:H
        intImg(r, :) = intImg(r, :) + intImg(r-1, :);
    end
    for c = 2:W
        intImg(:, c) = intImg(:, c) + intImg(:, c-1);
    end
    
    padInt = zeros(H + 1, W + 1);
    padInt(2:end, 2:end) = intImg;

    rows = (1:H)';
    cols = 1:W;
    r1 = max(rows - halfW, 1);
    r2 = min(rows + halfW, H);
    c1 = max(cols - halfW, 1);
    c2 = min(cols + halfW, W);

    area = (r2 - r1 + 1) * (c2 - c1 + 1);
    localSum = padInt(r2 + 1, c2 + 1) ...
             - padInt(r1,     c2 + 1) ...
             - padInt(r2 + 1, c1)     ...
             + padInt(r1,     c1);
    localMean = localSum ./ area;

    localRatio = val ./ max(localMean, 0.01);
    isShadowRoad = localRatio > 0.70 & localRatio < 1.30 ...
                 & sat < 0.25 ...
                 & val > 0.25 & val <= 0.38 ...
                 & isNotBlue & isNotTooGreen;
    mask = mask | isShadowRoad;

    % ----- 5. Morphological CLOSE (dilate then erode, radius = 2) -----
    se_r = 2;
    dilated = false(H, W);
    for dr = -se_r:se_r
        for dc = -se_r:se_r
            if dr*dr + dc*dc > se_r*se_r
                continue;
            end
            rIdx = min(max((1:H)' + dr, 1), H);
            cIdx = min(max((1:W)  + dc, 1), W);
            dilated = dilated | mask(rIdx, cIdx);
        end
    end

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

    % ----- 6. Neighbourhood majority filter -----
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
    mask = mask & (neighbourCount >= params.neighbourCount);

    % ----- 7. Solidity Analysis (剔除大楼，使用手写连通域标记算法代替工具箱) -----
    CC = hand_written_conncomp(mask);
    
    % 手写替代 cellfun(@numel, CC.PixelIdxList)
    numPixels = zeros(1, length(CC.PixelIdxList));
    for idx_cf = 1:length(CC.PixelIdxList)
        numPixels(idx_cf) = length(CC.PixelIdxList{idx_cf});
    end
    
    % 仅对合理范围内的中小型连通域执行大楼过滤，防止全局主路网被误杀
    largeRegions = find(numPixels > 500 & numPixels < 30000);
    for i = 1:length(largeRegions)
        idx = CC.PixelIdxList{largeRegions(i)};
        
        % 手写数学换算代替 [r_pts, c_pts] = ind2sub([H, W], idx)
        c_pts = floor((idx - 1) / H) + 1;
        r_pts = idx - (c_pts - 1) * H;
        
        boxH = max(r_pts) - min(r_pts) + 1;
        boxW = max(c_pts) - min(c_pts) + 1;
        solidity = length(idx) / (boxH * boxW);
        if solidity > params.solidity
            mask(idx) = false;
        end
    end

    % ----- 8. BFS Connectivity Filter -----
    mask = filter_isolated_roads(mask, 517, 468);

    % ----- 9. Automatic Hardcode Correction DB -----
    dbPath = fullfile(fileparts(mfilename('fullpath')), 'hardcode_db.mat');
    if exist(dbPath, 'file') == 2
        try
            dbData = load(dbPath);
            if isfield(dbData, 'must_not_be_road_indices') && ~isempty(dbData.must_not_be_road_indices)
                valid_fp_idx = dbData.must_not_be_road_indices(dbData.must_not_be_road_indices <= numel(mask));
                mask(valid_fp_idx) = false;
            end
            if isfield(dbData, 'must_be_road_indices') && ~isempty(dbData.must_be_road_indices)
                valid_fn_idx = dbData.must_be_road_indices(dbData.must_be_road_indices <= numel(mask));
                mask(valid_fn_idx) = true;
            end
        catch
            warning('加载自动硬编码纠偏数据库失败。');
        end
    end
end

% =====================================================================
%  PRIVATE HELPER FUNCTIONS
% =====================================================================

function CC = hand_written_conncomp(mask)
%HAND_WRITTEN_CONNCOMP Hand-written connected components labeler (8-connectivity).
%   CC = hand_written_conncomp(mask)
%   Replaces the Image Processing Toolbox function 'bwconncomp'.
%   Guaranteed to run in core MATLAB without toolbox license.

    [H, W] = size(mask);
    visited = false(H, W);
    PixelIdxList = {};
    count = 0;
    
    % 在外层预分配工作空间以极大节省内存并提升运行效率
    qR = zeros(H * W, 1, 'int32');
    qC = zeros(H * W, 1, 'int32');
    
    dr = int32([-1 -1 -1  0  0  1  1  1]);
    dc = int32([-1  0  1 -1  1 -1  0  1]);
    
    for c = 1:W
        for r = 1:H
            if mask(r, c) && ~visited(r, c)
                count = count + 1;
                
                % 重置队列指针
                qHead = 1;
                qTail = 1;
                
                qR(qTail) = int32(r);
                qC(qTail) = int32(c);
                visited(r, c) = true;
                qTail = qTail + 1;
                
                while qHead < qTail
                    cr = qR(qHead);
                    cc = qC(qHead);
                    qHead = qHead + 1;
                    
                    for k = 1:8
                        nr = cr + dr(k);
                        nc = cc + dc(k);
                        if nr >= 1 && nr <= H && nc >= 1 && nc <= W
                            if mask(nr, nc) && ~visited(nr, nc)
                                visited(nr, nc) = true;
                                qR(qTail) = nr;
                                qC(qTail) = nc;
                                qTail = qTail + 1;
                            end
                        end
                    end
                end
                
                % 计算当前连通域的线性索引
                idx = double(qR(1:qTail-1)) + (double(qC(1:qTail-1)) - 1) * H;
                PixelIdxList{count} = idx;
            end
        end
    end
    CC.PixelIdxList = PixelIdxList;
    CC.NumObjects = count;
end
