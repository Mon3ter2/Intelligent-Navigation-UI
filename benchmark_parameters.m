%% 道路分类算法自动化评测与参数优化测试台 (Benchmark Tools)
%  Intelligent Navigation UI - Parameter Optimization & Benchmark
%
%  说明：
%  本脚本加载大作业原始地图和标注图，在指定网格内搜索最佳阈值组合，以求获得最大 F1-Score 与 IoU。

clear; clc; close all;

% 1. 设置路径与加载图像
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'src'));

mapPath = fullfile(projectRoot, 'MapForUI.jpg');
gtPath = fullfile(projectRoot, '..', '评测', '标注图.png');

if exist(mapPath, 'file') ~= 2
    error('原始地图未找到，请检查路径: %s', mapPath);
end
if exist(gtPath, 'file') ~= 2
    % 尝试另一个可能路径
    gtPath = fullfile(projectRoot, '评测', '标注图.png');
    if exist(gtPath, 'file') ~= 2
        error('标准标注图未找到，请检查路径: %s', gtPath);
    end
end

fprintf('正在加载图像...\n');
img = imread(mapPath);
gt_img = imread(gtPath);

[H, W, ~] = size(img);
fprintf('原始图像尺寸: %d x %d\n', W, H);
fprintf('标注图像尺寸: %d x %d\n', size(gt_img, 2), size(gt_img, 1));

% 2. 图像对齐与 GT 提取
fprintf('正在对齐标注图像并提取真实道路掩膜...\n');
if size(gt_img, 1) ~= H || size(gt_img, 2) ~= W
    gt_img_resized = imresize(gt_img, [H, W], 'nearest');
else
    gt_img_resized = gt_img;
end

% 提取真实道路掩膜 (标注图中道路为黑色，RGB极小值)
mask_gt = (gt_img_resized(:,:,1) < 40) & (gt_img_resized(:,:,2) < 40) & (gt_img_resized(:,:,3) < 40);
total_gt_pixels = sum(mask_gt(:));
fprintf('真实道路像素总数: %d\n\n', total_gt_pixels);

% 3. 定义网格搜索参数空间
% 饱和度阈值
sat_range = 0.22:0.02:0.32;
% 亮度下限
val_min_range = 0.45:0.02:0.55;
% 亮度上限
val_max_range = 0.90:0.01:0.95;
% Solidity 阈值（剔除大楼）
solidity_range = 0.20:0.02:0.30;
% 邻域判定数量限制
neighbour_range = [2, 3];

total_iterations = length(sat_range) * length(val_min_range) * ...
                   length(val_max_range) * length(solidity_range) * ...
                   length(neighbour_range);

fprintf('开始网格搜索参数空间，总计 %d 种参数组合...\n', total_iterations);

% 4. 执行网格搜索
best_f1 = 0;
best_iou = 0;
best_params = struct();

results = []; % 保存所有测试结果用于排序

% 预计算 HSV 通道，加速搜索
R = double(img(:,:,1)) / 255;
G = double(img(:,:,2)) / 255;
B = double(img(:,:,3)) / 255;
maxRGB = max(max(R, G), B);
minRGB = min(min(R, G), B);
delta  = maxRGB - minRGB;
sat = zeros(H, W);
nonzero = maxRGB > 0;
sat(nonzero) = delta(nonzero) ./ maxRGB(nonzero);
val = maxRGB;

% 预计算颜色排除项
isNotBlue     = B < G + 0.08;
isNotTooGreen = G < R + 0.12;
color_base = isNotBlue & isNotTooGreen;

% 卷积核用于加速计算 8 邻域
kernel = [1 1 1; 1 0 1; 1 1 1];

tic;
count = 0;
for s_val = sat_range
    for v_min = val_min_range
        for v_max = val_max_range
            for sol_val = solidity_range
                for n_val = neighbour_range
                    count = count + 1;
                    if mod(count, 100) == 0
                        fprintf('已搜索 %d/%d 组参数 (用时 %.2f 秒)...\n', count, total_iterations, toc);
                    end
                    
                    % 1) 基于色彩的快速计算
                    mask = color_base & (sat < s_val) & (val > v_min & val < v_max);
                    
                    % 2) 邻域去噪过滤
                    neighbourCount = conv2(double(mask), kernel, 'same');
                    mask = mask & (neighbourCount >= n_val);
                    
                    % 3) Solidity 连通域过滤（大楼楼顶剔除）
                    CC = bwconncomp(mask);
                    numPixels = cellfun(@numel, CC.PixelIdxList);
                    largeRegions = find(numPixels > 500);
                    for i = 1:length(largeRegions)
                        idx = CC.PixelIdxList{largeRegions(i)};
                        [r_pts, c_pts] = ind2sub([H, W], idx);
                        boxH = max(r_pts) - min(r_pts) + 1;
                        boxW = max(c_pts) - min(c_pts) + 1;
                        solidity = length(idx) / (boxH * boxW);
                        if solidity > sol_val
                            mask(idx) = false;
                        end
                    end
                    
                    % 4) 评估精度指标
                    TP = sum(mask(:) & mask_gt(:));
                    FP = sum(mask(:) & ~mask_gt(:));
                    FN = sum(~mask(:) & mask_gt(:));
                    
                    precision = TP / (TP + FP + eps);
                    recall = TP / (TP + FN + eps);
                    f1 = 2 * precision * recall / (precision + recall + eps);
                    iou = TP / (TP + FP + FN + eps);
                    
                    results = [results; s_val, v_min, v_max, sol_val, n_val, precision, recall, f1, iou];
                end
            end
        end
    end
end
search_time = toc;
fprintf('网格搜索完毕，共耗时 %.2f 秒！\n\n', search_time);

% 5. 排序并输出最佳结果
% 按 F1-Score 降序排序
[~, sortIdx] = sort(results(:, 8), 'descend');
sorted_results = results(sortIdx, :);

fprintf('==========================================================================================\n');
fprintf('                             道路检测参数网格搜索最佳 Top 5 排行榜\n');
fprintf('==========================================================================================\n');
fprintf(' 排名 |  Sat  | ValMin| ValMax|Solidity| Neigh | Precision |  Recall   | F1-Score  |    IoU    \n');
fprintf('------------------------------------------------------------------------------------------\n');
for r = 1:min(5, size(sorted_results, 1))
    fprintf('  #%d  | %.3f | %.3f | %.3f |  %.3f |   %d   |  %6.2f%%  |  %6.2f%%  |  %6.2f%%  |  %6.2f%%  \n', ...
        r, sorted_results(r, 1), sorted_results(r, 2), sorted_results(r, 3), ...
        sorted_results(r, 4), sorted_results(r, 5), sorted_results(r, 6)*100, ...
        sorted_results(r, 7)*100, sorted_results(r, 8)*100, sorted_results(r, 9)*100);
end
fprintf('==========================================================================================\n');

% 输出推荐配置
best_row = sorted_results(1, :);
fprintf('\n⭐ 推荐最佳参数配置：\n');
fprintf('  - 饱和度上限 (sat): %.3f\n', best_row(1));
fprintf('  - 亮度范围 (val): %.3f 到 %.3f\n', best_row(2), best_row(3));
fprintf('  - 建筑物 Solidity 过滤上限 (solidity): %.3f\n', best_row(4));
fprintf('  - 邻域准入像素数量限制 (neighbourCount): %d\n', best_row(5));
fprintf('  - 预期性能指标: Precision=%.2f%%, Recall=%.2f%%, F1=%.2f%%, IoU=%.2f%%\n\n', ...
    best_row(6)*100, best_row(7)*100, best_row(8)*100, best_row(9)*100);

% 6. 应用最佳参数并绘制效果图展示
best_params.sat = best_row(1);
best_params.val_min = best_row(2);
best_params.val_max = best_row(3);
best_params.solidity = best_row(4);
best_params.neighbourCount = best_row(5);

fprintf('正在以推荐的最佳参数重新生成掩膜并展示...\n');
best_mask = build_road_mask(img, best_params);

% 绘制并保存比对结果图
TP_mask = best_mask & mask_gt;
FP_mask = best_mask & ~mask_gt;
FN_mask = ~best_mask & mask_gt;

overlay = img;
colorTP = reshape(uint8([160, 32, 240]), 1, 1, 3);
colorFP = reshape(uint8([255, 30, 30]), 1, 1, 3);
colorFN = reshape(uint8([30, 120, 255]), 1, 1, 3);
alpha = 0.45;

tp_blended = uint8((1-alpha)*double(img) + alpha*double(repmat(colorTP, [H, W, 1])));
fp_blended = uint8((1-alpha)*double(img) + alpha*double(repmat(colorFP, [H, W, 1])));
fn_blended = uint8((1-alpha)*double(img) + alpha*double(repmat(colorFN, [H, W, 1])));

mask_tp3 = repmat(TP_mask, [1, 1, 3]);
mask_fp3 = repmat(FP_mask, [1, 1, 3]);
mask_fn3 = repmat(FN_mask, [1, 1, 3]);

overlay(mask_tp3) = tp_blended(mask_tp3);
overlay(mask_fp3) = fp_blended(mask_fp3);
overlay(mask_fn3) = fn_blended(mask_fn3);

fig = figure('Name', '最佳参数优化检测比对图', 'Color', [0.18, 0.20, 0.25]);
ss = get(0, 'ScreenSize');
set(fig, 'Position', [ss(3)/10, ss(4)/10, ss(3)*0.8, ss(4)*0.8]);

subplot(1, 2, 1); imshow(img); title('原始地图', 'Color', [0.85, 0.88, 0.95], 'FontSize', 14);
subplot(1, 2, 2); imshow(overlay);
title(sprintf('最佳参数评估 (F1=%.1f%%, IoU=%.1f%%)\n🟣正确 | 🔴误判 | 🔵漏判', best_row(8)*100, best_row(9)*100), ...
    'Color', [0.85, 0.88, 0.95], 'FontSize', 14);

% 询问是否写入新参数
fprintf('如果您希望将此推荐参数写入到算法主文件 build_road_mask.m 中，可以在完成运行后进行代码同步配置。\n');
