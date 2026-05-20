function mask = build_road_mask(img)
%BUILD_ROAD_MASK Generate a binary mask of road pixels from the map image.
%   mask = build_road_mask(img)
%
%   The function converts the image to a manually-computed HSV-like colour
%   space (no built-in rgb2hsv) and identifies road pixels by:
%     - Low colour saturation  (grey-ish, not vivid green / blue)
%     - Medium brightness       (not pure-white buildings, not dark edges)
%     - Not dominated by blue   (exclude water bodies)
%     - Not dominated by green  (exclude vegetation with low saturation)
%
%   A simple neighbourhood majority filter is then applied to remove
%   isolated noise pixels.
%
%   Input:  img  - uint8 H x W x 3 RGB map image
%   Output: mask - logical H x W, true = road

    [H, W, ~] = size(img);

    % ----- Manual HSV-like computation -----
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

    % ----- Road criteria -----
    isLowSat      = sat < 0.28;
    isMedBright   = val > 0.42 & val < 0.92;
    isNotBlue     = B < G + 0.08;       % blue not dominant (water)
    isNotTooGreen = G < R + 0.12;       % green not dominant (vegetation)

    mask = isLowSat & isMedBright & isNotBlue & isNotTooGreen;

    % ----- Neighbourhood majority filter -----
    % A pixel is kept only if >= 4 of its 8 neighbours are also road.
    % This removes small isolated false positives.
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
end
