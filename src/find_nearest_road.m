function [roadR, roadC] = find_nearest_road(r, c, roadMask)
%FIND_NEAREST_ROAD Find the closest road pixel to an arbitrary point.
%   [roadR, roadC] = find_nearest_road(r, c, roadMask)
%
%   Performs an expanding-square search from (r, c) until a road pixel is
%   found.  Used by OR-5 (Path Planning) to snap arbitrary map clicks to
%   the road network.

    [H, W] = size(roadMask);
    r = round(r);
    c = round(c);

    % Already on road?
    if r >= 1 && r <= H && c >= 1 && c <= W && roadMask(r, c)
        roadR = r;
        roadC = c;
        return;
    end

    maxRadius = max(H, W);
    for radius = 1:maxRadius
        for dr = -radius:radius
            for dc = -radius:radius
                if abs(dr) ~= radius && abs(dc) ~= radius
                    continue;           % only check the border ring
                end
                nr = r + dr;
                nc = c + dc;
                if nr >= 1 && nr <= H && nc >= 1 && nc <= W && roadMask(nr, nc)
                    roadR = nr;
                    roadC = nc;
                    return;
                end
            end
        end
    end

    % Fallback (should never happen on a valid map)
    roadR = r;
    roadC = c;
end
