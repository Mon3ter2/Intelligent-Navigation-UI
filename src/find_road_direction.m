function angle = find_road_direction(r, c, roadMask, windowRadius)
%FIND_ROAD_DIRECTION Detect the local road direction at a given pixel.
%   angle = find_road_direction(r, c, roadMask, windowRadius)
%
%   Analyses the distribution of nearby road pixels using principal
%   component analysis (manual 2x2 eigendecomposition) to determine the
%   dominant direction of the road at the specified point.
%
%   Inputs:
%     r, c         - pixel position (row, col)
%     roadMask     - logical H x W road mask
%     windowRadius - search radius in pixels (default 25)
%
%   Output:
%     angle - road direction in degrees (world coords, 0 = east, 90 = north)

    if nargin < 4
        windowRadius = 25;
    end

    [H, W] = size(roadMask);
    r = round(r);
    c = round(c);

    rMin = max(1, r - windowRadius);
    rMax = min(H, r + windowRadius);
    cMin = max(1, c - windowRadius);
    cMax = min(W, c + windowRadius);

    subMask = roadMask(rMin:rMax, cMin:cMax);
    [rows, cols] = find(subMask);
    rows = rows + rMin - 1;
    cols = cols + cMin - 1;

    if length(rows) < 5
        angle = 0;
        return;
    end

    % --- Manual PCA on road pixel coordinates ---
    meanR = mean(rows);
    meanC = mean(cols);
    dr = rows - meanR;
    dc = cols - meanC;

    Ccc = sum(dc .* dc);
    Crr = sum(dr .* dr);
    Ccr = sum(dc .* dr);

    % Analytic eigenvalue of 2x2 covariance [Ccc Ccr; Ccr Crr]
    T = Ccc + Crr;
    D = Ccc * Crr - Ccr * Ccr;
    lambda1 = T / 2 + sqrt(max(0, (T / 2)^2 - D));

    % Eigenvector for the larger eigenvalue
    if abs(Ccr) > 1e-6
        ev_c = lambda1 - Crr;
        ev_r = Ccr;
    elseif Ccc >= Crr
        ev_c = 1;
        ev_r = 0;
    else
        ev_c = 0;
        ev_r = 1;
    end

    % Image coords -> world coords (y-axis flip): direction = (ev_c, -ev_r)
    angle = atan2(-ev_r, ev_c) * 180 / pi;
end
