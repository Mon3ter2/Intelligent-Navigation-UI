function h = draw_iv(ax, iv, mapHeight, scale, rotAngle, origCenter, rotCenter, isSelected, isHovered)
%DRAW_IV Draw an IV rectangle (with heading indicator) on map axes.
%   h = draw_iv(ax, iv, mapHeight, scale, rotAngle, origCenter, rotCenter)
%
%   Inputs:
%     ax         - axes handle to draw on
%     iv         - IV struct (from create_iv)
%     mapHeight  - map pixel height (803)
%     scale      - m/px (1.7)
%     rotAngle   - current map rotation in degrees
%     origCenter - [cx, cy] of original image centre
%     rotCenter  - [cx, cy] of rotated image centre
%
%   Output:
%     h - column vector of graphics handles (patch, line, text)

    % ----- Colour palette (cycles by IV id) -----
    palette = [ ...
        0.30 0.60 1.00; ...
        1.00 0.40 0.40; ...
        0.35 0.85 0.45; ...
        1.00 0.75 0.20; ...
        0.75 0.40 0.90; ...
        0.20 0.85 0.85];
    cidx = mod(iv.ID - 1, size(palette, 1)) + 1;
    faceClr = palette(cidx, :);

    % ----- IV half-dimensions in metres (scaled) -----
    halfL = (iv.Length * iv.ScaleFactor) / 2;   % along heading
    halfW = (iv.Width  * iv.ScaleFactor) / 2;   % perpendicular

    % Corner offsets in local frame (heading = +x)
    local = [-halfL, -halfW;
              halfL, -halfW;
              halfL,  halfW;
             -halfL,  halfW];

    % ----- Rotate by heading angle (world coords) -----
    iv_rad = iv.Angle * pi / 180;
    cosA = cos(iv_rad);
    sinA = sin(iv_rad);

    worldC = zeros(4, 2);   % [wx, wy] per corner
    for k = 1:4
        worldC(k,1) = iv.WorldX + cosA * local(k,1) - sinA * local(k,2);
        worldC(k,2) = iv.WorldY + sinA * local(k,1) + cosA * local(k,2);
    end

    % Heading-tip points (for direction indicator triangle)
    % 保证箭头在 1x 缩放下也足够大（最小长度 30 米，约屏幕 18 像素）
    aLen = max(halfL * 2.9, 36);
    aWid = max(halfW * 2.6, 15);
    arrow_local = [
        aLen, 0;                    % Front tip
        aLen - aWid, -aWid * 0.7;   % Left back
        aLen - aWid,  aWid * 0.7    % Right back
    ];
    arrowW = zeros(3, 2);
    for k = 1:3
        arrowW(k,1) = iv.WorldX + cosA * arrow_local(k,1) - sinA * arrow_local(k,2);
        arrowW(k,2) = iv.WorldY + sinA * arrow_local(k,1) + cosA * arrow_local(k,2);
    end

    % ----- Convert to pixel coordinates -----
    pixC = zeros(4,1);   % column (x in axes)
    pixR = zeros(4,1);   % row    (y in axes)
    for k = 1:4
        [pixR(k), pixC(k)] = world_to_pixel(worldC(k,1), worldC(k,2), mapHeight, scale);
    end
    
    arrowC = zeros(3,1);
    arrowR = zeros(3,1);
    for k = 1:3
        [arrowR(k), arrowC(k)] = world_to_pixel(arrowW(k,1), arrowW(k,2), mapHeight, scale);
    end
    bodyFrontW = [iv.WorldX + cosA * halfL, iv.WorldY + sinA * halfL];
    bodyBackW  = [iv.WorldX - cosA * halfL, iv.WorldY - sinA * halfL];
    [frontR, frontC] = world_to_pixel(bodyFrontW(1), bodyFrontW(2), mapHeight, scale);
    [backR,  backC]  = world_to_pixel(bodyBackW(1),  bodyBackW(2),  mapHeight, scale);

    % ----- Apply map rotation (original -> rotated pixel space) -----
    if abs(rotAngle) > 0.001
        mapRad = rotAngle * pi / 180;
        cosM = cos(mapRad);
        sinM = sin(mapRad);
        for k = 1:4
            dc = pixC(k) - origCenter(1);
            dr = pixR(k) - origCenter(2);
            pixC(k) =  cosM * dc + sinM * dr + rotCenter(1);
            pixR(k) = -sinM * dc + cosM * dr + rotCenter(2);
        end
        % heading arrow
        for k = 1:3
            dc = arrowC(k) - origCenter(1);  dr = arrowR(k) - origCenter(2);
            arrowC(k) =  cosM * dc + sinM * dr + rotCenter(1);
            arrowR(k) = -sinM * dc + cosM * dr + rotCenter(2);
        end
        % front/back anchor line
        dc = frontC - origCenter(1);  dr = frontR - origCenter(2);
        frontC =  cosM * dc + sinM * dr + rotCenter(1);
        frontR = -sinM * dc + cosM * dr + rotCenter(2);
        dc = backC - origCenter(1);  dr = backR - origCenter(2);
        backC =  cosM * dc + sinM * dr + rotCenter(1);
        backR = -sinM * dc + cosM * dr + rotCenter(2);
    end

    if nargin < 8, isSelected = false; end
    if nargin < 9, isHovered = false; end

    % ----- Configure Patch Style based on Selected/Hovered status -----
    if isSelected
        % 选中高亮反馈：金黄色极粗边框，完全不透明
        edgeClr = [1 0.85 0];
        lineWidth = 3.5;
        faceAlpha = 1.0;
        arrowFill = [1 0.08 0.08];
        arrowEdge = [1 1 1];
        arrowWidth = 2.3;
        spineClr = [1 1 1];
        spineWidth = 2.0;
    elseif isHovered
        % 鼠标滑过悬浮初始交互：亮橙色中等粗边框，微透明
        edgeClr = [1 0.6 0.1];
        lineWidth = 2.0;
        faceAlpha = 0.9;
        arrowFill = [1 0.15 0.15];
        arrowEdge = [1 0.95 0.65];
        arrowWidth = 1.9;
        spineClr = [1 0.95 0.65];
        spineWidth = 1.6;
    else
        % 默认状态：常规黑色细边框，中度透明
        edgeClr = 'k';
        lineWidth = 1;
        faceAlpha = 0.75;
        arrowFill = [1 0.12 0.12];
        arrowEdge = [1 1 1];
        arrowWidth = 1.7;
        spineClr = [1 0.97 0.72];
        spineWidth = 1.4;
    end

    % ----- Draw -----
    h1 = patch(ax, pixC, pixR, faceClr, ...
        'FaceAlpha', faceAlpha, 'EdgeColor', edgeClr, 'LineWidth', lineWidth, ...
        'PickableParts', 'none');
    set(h1, 'HitTest', 'off');


    h2 = line(ax, [backC frontC], [backR frontR], ...
        'Color', spineClr, 'LineWidth', spineWidth, 'Clipping', 'on', ...
        'PickableParts', 'none');
    set(h2, 'HitTest', 'off');

    h3 = patch(ax, arrowC, arrowR, arrowFill, ...
        'FaceAlpha', 0.96, 'EdgeColor', arrowEdge, 'LineWidth', arrowWidth, ...
        'PickableParts', 'none');
    set(h3, 'HitTest', 'off');


    % Calculate screen direction to place text behind the car
    % (We choose not to draw text on map to conform strictly to 8mx3m scale, keeping it clean)
    h = [h1; h2; h3];
end

