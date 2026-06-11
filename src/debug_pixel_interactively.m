function debug_pixel_interactively(projectRoot)
%DEBUG_PIXEL_INTERACTIVELY Interactive tool to inspect pixel-level road detection details.
%   debug_pixel_interactively(projectRoot)
%
%   Opens the map image and lets user click points. For each click, it
%   extracts the pixel's RGB, computes its HSV, checks the 4 criteria
%   from build_road_mask.m, inspects the 8-neighbourhood count, and prints
%   a comprehensive diagnostic report to the command window.

    mapPath = fullfile(projectRoot, 'MapForUI.jpg');
    if exist(mapPath, 'file') ~= 2
        error('Map image not found: %s', mapPath);
    end
    img = imread(mapPath);
    
    fprintf('正在计算全局道路掩膜与邻域特征...\n');
    [H, W, ~] = size(img);
    
    % --- 运行并解构 build_road_mask.m 的关键步骤，以便单点 Debug ---
    R_map = double(img(:,:,1)) / 255;
    G_map = double(img(:,:,2)) / 255;
    B_map = double(img(:,:,3)) / 255;
    
    maxRGB = max(max(R_map, G_map), B_map);
    minRGB = min(min(R_map, G_map), B_map);
    delta  = maxRGB - minRGB;
    
    S_map = zeros(H, W);
    nonzero = maxRGB > 0;
    S_map(nonzero) = delta(nonzero) ./ maxRGB(nonzero);
    V_map = maxRGB;
    
    % 四个核心判定条件的布尔矩阵
    cond_sat_map   = S_map < 0.28;
    cond_bright_map= V_map > 0.5 & V_map < 0.93;
    cond_water_map = B_map < G_map + 0.08;
    cond_green_map = G_map < R_map + 0.12;
    
    color_pass_map = cond_sat_map & cond_bright_map & cond_water_map & cond_green_map;
    
    % 计算 8 邻域道路像素数
    padded = false(H + 2, W + 2);
    padded(2:end-1, 2:end-1) = color_pass_map;
    
    neighbourCount = zeros(H, W);
    for dr = -1:1
        for dc = -1:1
            if dr == 0 && dc == 0, continue; end
            neighbourCount = neighbourCount + ...
                double(padded((2+dr):(H+1+dr), (2+dc):(W+1+dc)));
        end
    end
    
    % 最终分类结果 (邻域阈值改为 >= 2)
    final_mask = color_pass_map & (neighbourCount >= 2);
    
    % --- 打开图形交互界面 ---
    fig = figure('Name', '方案二：交互式单点道路判定 Debug 探测器', 'NumberTitle', 'off', ...
                 'Color', [0.18, 0.20, 0.25]);
    
    imshow(img);
    title({'点击地图任意位置以探测该像素判定细节', '在命令窗口查看详细 Debug 报告，关闭窗口以退出'}, ...
          'Color', [0.85, 0.88, 0.95], 'FontSize', 11, 'FontWeight', 'bold');
          
    hold on;
    hMarker = []; % 点击标记句柄
    
    fprintf('\n=================================================================\n');
    fprintf(' 交互式像素探测器启动成功！请在弹出的地图窗口中用鼠标左键点击任意点。\n');
    fprintf('=================================================================\n');
    
    while isgraphics(fig)
        try
            % 捕获点击坐标
            [c_click, r_click] = ginput(1);
            r = round(r_click);
            c = round(c_click);
            
            % 越界判定
            if r < 1 || r > H || c < 1 || c > W
                fprintf('\n⚠️ 点击位置超出地图边界 (Row: %d, Col: %d)，请重新点击。\n', r, c);
                continue;
            end
            
            % 在图上动态绘制标记红圈与十字准星
            if ~isempty(hMarker) && all(isgraphics(hMarker))
                delete(hMarker);
            end
            h1 = plot(c, r, 'ro', 'MarkerSize', 12, 'LineWidth', 2, 'MarkerFaceColor', [1 0.3 0.3]);
            h2 = plot([c-20, c+20], [r, r], 'r-', 'LineWidth', 1.5);
            h3 = plot([c, c], [r-20, r+20], 'r-', 'LineWidth', 1.5);
            hMarker = [h1; h2; h3];
            
            % 读取并打印当前点的 Debug 数据
            valR = R_map(r, c);
            valG = G_map(r, c);
            valB = B_map(r, c);
            valS = S_map(r, c);
            valV = V_map(r, c);
            
            p_sat    = cond_sat_map(r, c);
            p_bright = cond_bright_map(r, c);
            p_water  = cond_water_map(r, c);
            p_green  = cond_green_map(r, c);
            p_color  = color_pass_map(r, c);
            
            n_count  = neighbourCount(r, c);
            p_final  = final_mask(r, c);
            
            fprintf('\n📍 像素探测位置: 行(Row)=%-4d, 列(Col)=%-4d  | 像素原始颜色 RGB = [%-3.0f, %-3.0f, %-3.0f]\n', ...
                    r, c, valR*255, valG*255, valB*255);
            fprintf('-----------------------------------------------------------------\n');
            fprintf('色彩指标评估 (Manually-computed HSV):\n');
            fprintf('  - [1] 饱和度 S = %-5.3f  (道路要求 S < 0.28):          %s\n', valS, check_status(p_sat));
            fprintf('  - [2] 亮度   V = %-5.3f  (道路要求 0.5 < V < 0.93):  %s\n', valV, check_status(p_bright));
            fprintf('  - [3] 排除水体分量 (蓝光 B < G + 0.08):           %s (差值: %+.3f)\n', check_status(p_water), valB - valG);
            fprintf('  - [4] 排除植被分量 (绿光 G < R + 0.12):           %s (差值: %+.3f)\n', check_status(p_green), valG - valR);
            fprintf('  => 色彩判定综合结论:                              %s\n', check_status(p_color));
            
            fprintf('空间邻域过滤评估 (Neighbourhood Filter):\n');
            fprintf('  - 8-邻域中被判定为道路的像素个数: %d 个\n', n_count);
            fprintf('  - 邻域准入条件 (周边道路像素 >= 2 个):            %s\n', check_status(n_count >= 2));
            
            fprintf('-----------------------------------------------------------------\n');
            if p_final
                fprintf('🔥 最终综合决策: [ON ROAD] (属于合法道路) 🟢\n');
            else
                % 深入分析为何判定不通过
                if ~p_color
                    fprintf('❌ 最终综合决策: [OUT OF ROAD] (非道路) 🔴 (原因: 像素本身色彩不符合道路标准)\n');
                else
                    fprintf('❌ 最终综合决策: [OUT OF ROAD] (非道路) 🔴 (原因: 色彩达标，但由于周边道路像素仅 %d 个，被判定为孤立噪点并被滤波器过滤)\n', n_count);
                end
            end
            fprintf('=================================================================\n');
            
        catch ME
            if ~isgraphics(fig)
                fprintf('\n👋 交互式 Debug 探测器已关闭，退出调试。\n');
            else
                fprintf('\n⚠️ 交互发生错误: %s\n', ME.message);
            end
            break;
        end
    end
end

function str = check_status(cond)
    if cond
        str = '【通过 PASS】';
    else
        str = '【不通过 FAIL】';
    end
end
