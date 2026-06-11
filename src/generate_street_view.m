function streetImg = generate_street_view(mapImage, centreR, centreC, ...
                                          roadAngle, mapHeight, scale)
%GENERATE_STREET_VIEW Create a perspective street view from a 2D map using a physical camera model.
%   streetImg = generate_street_view(mapImage, centreR, centreC,
%                                     roadAngle, mapHeight, scale)
%
%   Generates a perspective-warped view of the map as if standing at the
%   specified road point and looking along the road direction.
%   Uses a pinhole camera model to query ground points, supporting curved roads.
%   Includes a sky gradient and distance-based fog for visual realism.
%
%   Output: uint8 400 x 500 x 3 RGB image.

    outH = 400;
    outW = 500;
    streetImg = uint8(zeros(outH, outW, 3));

    % ---- 摄像机物理内外参标定 ----
    u0 = (outW + 1) / 2;     % 水平图像中心光心 (250.5 像素)
    v0 = (outH + 1) / 2;     % 垂直图像中心光心 (200.5 像素)
    f  = 260;                % 焦距 (像素值，决定约 85 度的水平视场角 FOV)
    alpha = 13.1 * pi / 180; % 摄像机俯仰角 (弧度，向下倾斜约 13.1 度，使地平线刚好投影在 V = 140 处)
    hc = 3.5;                % 摄像机离地面的实际高度 (米)

    % ---- 建立像素坐标网格 ----
    [U, V] = meshgrid(1:outW, 1:outH);

    % ---- 射线在世界坐标系 Z 轴 (垂直地面向上) 的投影分量 ----
    % 图像的 V 轴向下为正，因此相机本地 Y 轴分量对应于地面的向下方向
    dWZ = -(V - v0) * cos(alpha) - f * sin(alpha);
    isGround = dWZ < 0;

    % ---- 渲染天空 (V <= 140) ----
    % 天空采用天蓝色到浅蓝白色的渐变效果，利用垂直像素行进行插值
    skyMask = ~isGround;
    V_sky = double(V);
    V_sky(~skyMask) = 140;   % 限制天空最大高度边界为 140 像素
    t_sky = (V_sky - 1) / 139;
    
    skyR = uint8(135 + 100 * t_sky);
    skyG = uint8(180 +  60 * t_sky);
    skyB = uint8(235 -  10 * t_sky);

    streetImg(:,:,1) = skyR;
    streetImg(:,:,2) = skyG;
    streetImg(:,:,3) = skyB;

    % ---- 渲染地面 (基于针孔摄像机模型逆向投影) ----
    % 计算摄像机当前所在的二维世界坐标
    [xc, yc] = pixel_to_world(centreR, centreC, mapHeight, scale);

    angRad = roadAngle * pi / 180;
    cosA   = cos(angRad);
    sinA   = sin(angRad);

    % 摄像机射线在相机本地前向与右向的水平投影分量
    dProjForward = -(V - v0) * sin(alpha) + f * cos(alpha);
    dProjRight   = U - u0;

    % 旋转投影分量到世界坐标系 (X_w, Y_w)
    dWX = dProjForward * cosA + dProjRight * sinA;
    dWY = dProjForward * sinA - dProjRight * cosA;

    % 求解射线与地面 Z_w = 0 平面的交点拉伸系数 t
    t_intersect = -hc ./ dWZ;

    % 计算地面交点在世界坐标系中的物理位置 (X_w, Y_w)
    wx = xc + t_intersect .* dWX;
    wy = yc + t_intersect .* dWY;

    % 将地面实际物理坐标转换回原始地图像素坐标 (pr, pc)
    pr = round(mapHeight - wy / scale + 0.5);
    pc = round(wx / scale + 0.5);

    % 越界及合法性掩膜检查
    [imgH, imgW, ~] = size(mapImage);
    valid = isGround & pr >= 1 & pr <= imgH & pc >= 1 & pc <= imgW;
    validIdx = find(valid);

    % 对合法地面区域进行地图颜色采样
    if ~isempty(validIdx)
        linIdx = pr(validIdx) + (pc(validIdx) - 1) * imgH;
        for ch = 1:3
            channel = mapImage(:,:,ch);
            tmp = streetImg(:,:,ch);
            tmp(validIdx) = channel(linIdx);
            streetImg(:,:,ch) = tmp;
        end
    end

    % 地图范围外的无效地面填充默认的大雾底色，防止出现黑色边缘
    invalidGround = isGround & ~valid;
    invalidGroundIdx = find(invalidGround);
    fogClr = [210, 230, 240];
    if ~isempty(invalidGroundIdx)
        for ch = 1:3
            tmp = streetImg(:,:,ch);
            tmp(invalidGroundIdx) = fogClr(ch);
            streetImg(:,:,ch) = tmp;
        end
    end

    % ---- 大气消隐效果 (基于三维物理距离渲染大雾) ----
    % 计算摄像机到地面交点的三维直线物理距离 (米)
    dist3D = hc * sqrt(dWX.^2 + dWY.^2 + dWZ.^2) ./ (-dWZ);
    
    % 大雾遮罩浓度随物理距离增加呈 1.5 次方非线性增强，上限设定为 75%
    fogAmt = min(0.75, (dist3D / 250).^1.5);
    
    % 将雾气混合渲染到地表区域上
    for ch = 1:3
        orig = double(streetImg(:,:,ch));
        target = orig .* (1 - fogAmt) + fogClr(ch) .* fogAmt;
        streetImg_ch = streetImg(:,:,ch);
        streetImg_ch(isGround) = uint8(target(isGround));
        streetImg(:,:,ch) = streetImg_ch;
    end
end
