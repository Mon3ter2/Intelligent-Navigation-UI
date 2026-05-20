function iv = create_iv(id, wx, wy, angle, scaleFactor)
%CREATE_IV Create an Intelligent Vehicle (IV) data structure.
%   iv = create_iv(id, wx, wy, angle, scaleFactor)
%
%   Inputs:
%     id          - unique integer ID
%     wx, wy      - real-world centre position (meters)
%     angle       - heading angle in degrees (0 = east, 90 = north)
%     scaleFactor - visualisation scale multiplier (1 = true size)
%
%   Output:
%     iv - struct with fields: ID, WorldX, WorldY, Angle, Length, Width, ScaleFactor

    iv.ID          = id;
    iv.WorldX      = wx;
    iv.WorldY      = wy;
    iv.Angle       = angle;
    iv.Length       = 8;    % metres
    iv.Width        = 3;    % metres
    iv.ScaleFactor = scaleFactor;
end
