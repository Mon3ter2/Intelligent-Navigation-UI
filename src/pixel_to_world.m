function [wx, wy] = pixel_to_world(r, c, mapHeight, scale)
%PIXEL_TO_WORLD Convert pixel coordinates to real-world coordinates.
%   [wx, wy] = pixel_to_world(r, c, mapHeight, scale)
%
%   Inputs:
%     r         - row index (1-indexed, top to bottom)
%     c         - column index (1-indexed, left to right)
%     mapHeight - height of map image in pixels (803)
%     scale     - meters per pixel (1.7)
%
%   Outputs:
%     wx - real-world x coordinate (meters, left to right)
%     wy - real-world y coordinate (meters, bottom to top)
%
%   The origin (0,0) is at the bottom-left corner of the map.

    wx = (c - 0.5) * scale;
    wy = (mapHeight - r + 0.5) * scale;
end
