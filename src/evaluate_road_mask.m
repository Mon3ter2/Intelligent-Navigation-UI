function evaluate_road_mask(projectRoot)
%EVALUATE_ROAD_MASK Evaluate classification errors (False Positives/Negatives) of the road mask.
%   evaluate_road_mask(projectRoot)
%
%   This function checks for the existence of '标注图.png' (Ground Truth).
%   - Scenario A: If GT exists, it performs exact binary classification 
%     comparison and highlights True Positives (Purple), False Positives (Red),
%     and False Negatives (Blue). It also prints Precision, Recall, F1-Score, and IoU.
%   - Scenario B: If GT does not exist, it runs a heuristic anomaly detection.

    mapPath = fullfile(projectRoot, 'MapForUI.jpg');
    if exist(mapPath, 'file') ~= 2
        error('Map image not found: %s', mapPath);
    end
    img = imread(mapPath);
    [H, W, ~] = size(img);
    
    fprintf('正在生成算法预测的道路掩膜...\n');
    mask_pred = build_road_mask(img);
    
    % 初始化颜色标记掩膜
    color_tp = false(H, W); % 正确判定 (True Positive) -> 紫色
    color_fp = false(H, W); % 误判 (False Positive)   -> 红色
    color_fn = false(H, W); % 漏判 (False Negative)   -> 蓝色
    
    % 检查标注图是否存在
    gtPath = '';
    possible_paths = {
        fullfile(projectRoot, '..', '评测', '标注图.png'), ...
        fullfile(projectRoot, '评测', '标注图.png'), ...
        fullfile(projectRoot, '标注图.png')
    };
    for i = 1:length(possible_paths)
        if exist(possible_paths{i}, 'file') == 2
            gtPath = possible_paths{i};
            break;
        end
    end
    
    if ~isempty(gtPath)
        fprintf('检测到标准答案: %s\n', gtPath);
        fprintf('正在对齐并提取标注图中的道路区域...\n');
        
        gt_img = imread(gtPath);
        % 调整标准图尺寸到原图尺寸
        if size(gt_img, 1) ~= H || size(gt_img, 2) ~= W
            gt_img = imresize(gt_img, [H, W], 'nearest');
        end
        
        % 道路在标注图中为黑色
        mask_gt = (gt_img(:,:,1) < 40) & (gt_img(:,:,2) < 40) & (gt_img(:,:,3) < 40);
        
        % 计算误差分类
        color_tp = mask_pred & mask_gt;  % TP: 预测为路，GT为路
        color_fp = mask_pred & ~mask_gt; % FP: 预测为路，GT非路（误判）
        color_fn = ~mask_pred & mask_gt; % FN: 预测非路，GT为路（漏判）
        
        tp_count = sum(color_tp(:));
        fp_count = sum(color_fp(:));
        fn_count = sum(color_fn(:));
        
        precision = tp_count / (tp_count + fp_count + eps);
        recall = tp_count / (tp_count + fn_count + eps);
        f1 = 2 * precision * recall / (precision + recall + eps);
        iou = tp_count / (tp_count + fp_count + fn_count + eps);
        
        fprintf('\n=================================================================\n');
        fprintf('                 道路分类算法 Benchmark 定量分析报告\n');
        fprintf('=================================================================\n');
        fprintf('分析模式：对照标注图精确评测\n');
        fprintf('  - 准确判定像素 (🟣 紫色): %d 像素 (True Positive)\n', tp_count);
        fprintf('  - 算法误判像素 (🔴 红色): %d 像素 (False Positive)\n', fp_count);
        fprintf('  - 算法漏判像素 (🔵 蓝色): %d 像素 (False Negative)\n', fn_count);
        fprintf('-----------------------------------------------------------------\n');
        fprintf('  - 精确率 (Precision): %.2f%%\n', precision * 100);
        fprintf('  - 召回率 (Recall):    %.2f%%\n', recall * 100);
        fprintf('  - F1 综合得分 (F1):   %.2f%%\n', f1 * 100);
        fprintf('  - 交并比 (IoU):       %.2f%%\n', iou * 100);
        fprintf('=================================================================\n');
        
        titleStr = sprintf('定量诊断 (🟣正确 %.1f%% | 🔴误判 %.1f%% | 🔵漏判 %.1f%%)', precision*100, fp_count/sum(mask_gt(:))*100, fn_count/sum(mask_gt(:))*100);
    else
        fprintf('未检测到标准答案，执行自特征启发式异常分类分析...\n');
        
        % 1. 疑似误判点识别：查找面积小于 150 像素的孤立碎片连通分量
        CC = bwconncomp(mask_pred);
        numPixels = cellfun(@numel, CC.PixelIdxList);
        smallRegionsIdx = find(numPixels < 150);
        
        for idx = 1:length(smallRegionsIdx)
            regionIdx = smallRegionsIdx(idx);
            color_fp(CC.PixelIdxList{regionIdx}) = true;
        end
        
        % 2. 疑似漏判点识别：手写 5x5 卷积闭运算桥接细微裂隙
        K_dilate = ones(5, 5);
        dilated = conv2(double(mask_pred), K_dilate, 'same') > 0;
        eroded = conv2(double(dilated), K_dilate, 'same') >= 24; % 5x5 腐蚀
        closed_mask = eroded;
        
        % 闭运算桥接出来（增加）的非道路像素判定为疑似漏判点
        color_fn = closed_mask & ~mask_pred;
        
        % 3. 正确判定像素（预测为道路且排除孤立噪点）
        color_tp = mask_pred & ~color_fp;
        
        tp_count = sum(color_tp(:));
        fp_count = sum(color_fp(:));
        fn_count = sum(color_fn(:));
        
        fprintf('\n=================================================================\n');
        fprintf('                 道路分类算法启发式异常分析报告\n');
        fprintf('=================================================================\n');
        fprintf('分析模式：无对照源自适应异常检测（基于形状与邻域连通度）\n');
        fprintf('  - 正确道路区域 (紫色): %d 像素 (主干道路或大型连通区域)\n', tp_count);
        fprintf('  - 疑似误判区域 (红色): %d 像素 (判定为道路但面积过小极孤立的噪点块)\n', fp_count);
        fprintf('  - 疑似漏判区域 (蓝色): %d 像素 (原本未判为道路但处于断裂桥接处的空隙)\n', fn_count);
        fprintf('=================================================================\n');
        
        titleStr = '自适应异常诊断 (🟣道路区域 | 🔴疑似误判 | 🔵疑似漏判)';
    end
    
    % ===============================================================
    % 三色半透明叠加渲染图生成
    % ===============================================================
    overlay = img;
    
    % 三种像素的高亮颜色
    colorTP_RGB = reshape(uint8([160, 32, 240]), 1, 1, 3);  % 正确 -> 亮紫色
    colorFP_RGB = reshape(uint8([255, 30, 30]), 1, 1, 3);    % 误判 -> 亮红色
    colorFN_RGB = reshape(uint8([30, 120, 255]), 1, 1, 3);   % 漏判 -> 亮蓝色
    
    alpha = 0.45; % 混合透明度 40%-50% 最佳
    
    % 全矩阵色块构建
    tp_map = repmat(colorTP_RGB, [H, W, 1]);
    fp_map = repmat(colorFP_RGB, [H, W, 1]);
    fn_map = repmat(colorFN_RGB, [H, W, 1]);
    
    % 向量化渲染
    tp_blended = uint8((1-alpha)*double(img) + alpha*double(tp_map));
    fp_blended = uint8((1-alpha)*double(img) + alpha*double(fp_map));
    fn_blended = uint8((1-alpha)*double(img) + alpha*double(fn_map));
    
    % 根据掩膜贴入
    mask_tp3 = repmat(color_tp, [1, 1, 3]);
    mask_fp3 = repmat(color_fp, [1, 1, 3]);
    mask_fn3 = repmat(color_fn, [1, 1, 3]);
    
    overlay(mask_tp3) = tp_blended(mask_tp3);
    overlay(mask_fp3) = fp_blended(mask_fp3);
    overlay(mask_fn3) = fn_blended(mask_fn3);
    
    % 打开结果窗口
    fig = figure('Name', '道路判定误差分类分析评估图', 'NumberTitle', 'off', ...
                 'Color', [0.18, 0.20, 0.25]);
    
    ss = get(0, 'ScreenSize');
    fw = min(1300, ss(3) * 0.90); fh = min(650, ss(4) * 0.80);
    set(fig, 'Position', [(ss(3) - fw)/2, (ss(4) - fh)/2, fw, fh]);
    
    subplot(1, 2, 1);
    imshow(img);
    title('原始地图 (Original Map)', 'Color', [0.85, 0.88, 0.95], 'FontSize', 12, 'FontWeight', 'bold');
    
    subplot(1, 2, 2);
    imshow(overlay);
    title(titleStr, 'Color', [0.85, 0.88, 0.95], 'FontSize', 12, 'FontWeight', 'bold');
    
    fprintf('误差判定渲染完成，图窗已成功绘制！\n');
end

