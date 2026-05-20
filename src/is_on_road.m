function valid = is_on_road(r, c, roadMask)
%IS_ON_ROAD Check whether pixel position (r, c) lies on a road.
%   valid = is_on_road(r, c, roadMask)
%
%   Inputs:
%     r, c     - pixel row and column (may be non-integer)
%     roadMask - logical matrix (H x W) where true = road
%
%   Output:
%     valid - true if the point is on a road pixel

    [H, W] = size(roadMask);
    ri = round(r);
    ci = round(c);

    if ri < 1 || ri > H || ci < 1 || ci > W
        valid = false;
        return;
    end

    valid = roadMask(ri, ci);
end
