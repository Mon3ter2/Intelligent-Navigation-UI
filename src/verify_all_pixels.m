function verify_all_pixels(projectRoot)
%VERIFY_ALL_PIXELS Verify all pixels on the map and display classification.
%   verify_all_pixels(projectRoot)
%
%   Loads the map image, runs the road classification mask algorithm, and
%   visualizes the "on-road" pixels by blending them with a purple overlay.
%   Uses fast vectorized matrix computation for pixel operations.

    mapPath = fullfile(projectRoot, 'MapForUI.jpg');
    if exist(mapPath, 'file') ~= 2
        error('Map image not found: %s', mapPath);
    end
    img = imread(mapPath);
    
    fprintf('正在构建道路掩膜...\n');
    mask = build_road_mask(img); % 调用已有的道路掩膜提取算法
    [H, W, ~] = size(img);
    
    fprintf('正在进行像素级分类混合渲染（紫色半透明）...\n');
    overlay = img;
    
    % 定义紫色道路图层颜色 (洋紫 [160, 32, 240])
    roadColorRGB = reshape(uint8([160, 32, 240]), 1, 1, 3);
    alpha = 0.45; % 45% 的透明度使得道路底层细节依然清晰可见
    
    % 快速向量化图像混合，避免耗时的双重循环
    mask3 = repmat(mask, [1, 1, 3]);
    roadColorMap = repmat(roadColorRGB, [H, W, 1]);
    
    % 混合公式：(1 - alpha) * 原图 + alpha * 覆盖层颜色
    blended = uint8((1 - alpha) * double(img) + alpha * double(roadColorMap));
    
    % 将混色区域只覆盖到判定为道路的像素上
    overlay(mask3) = blended(mask3);
    
    % 创建可视化窗口进行对比
    fig = figure('Name', '方案一：全像素道路判定覆盖验证图 (紫色)', 'NumberTitle', 'off', ...
                 'Color', [0.18, 0.20, 0.25]);
    
    % 设置窗口尺寸
    ss = get(0, 'ScreenSize');
    fw = min(1200, ss(3) * 0.85); fh = min(600, ss(4) * 0.75);
    set(fig, 'Position', [(ss(3) - fw)/2, (ss(4) - fh)/2, fw, fh]);
    
    % 左子图：原始地图
    subplot(1, 2, 1);
    imshow(img);
    title('原始地图 (Original Map)', 'Color', [0.85, 0.88, 0.95], 'FontSize', 12, 'FontWeight', 'bold');
    
    % 右子图：紫色道路像素叠加图
    subplot(1, 2, 2);
    imshow(overlay);
    title('道路判定结果 (On-Road Pixels in Purple)', 'Color', [0.85, 0.88, 0.95], 'FontSize', 12, 'FontWeight', 'bold');
    
    fprintf('批量像素验证渲染完成！图窗已展示。\n');
end
