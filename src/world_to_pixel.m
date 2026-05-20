function [r, c] = world_to_pixel(wx, wy, mapHeight, scale)
%WORLD_TO_PIXEL Convert real-world coordinates to pixel coordinates.
%   [r, c] = world_to_pixel(wx, wy, mapHeight, scale)
%
%   Inputs:
%     wx        - real-world x coordinate (meters)
%     wy        - real-world y coordinate (meters)
%     mapHeight - height of map image in pixels (803)
%     scale     - meters per pixel (1.7)
%
%   Outputs:
%     r - row index (1-indexed, top to bottom)
%     c - column index (1-indexed, left to right)

    c = round(wx / scale + 0.5);
    r = round(mapHeight - wy / scale + 0.5);
end
