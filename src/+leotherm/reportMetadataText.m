function [label, text] = reportMetadataText(key, value, language)
%REPORTMETADATATEXT Shared PDF/Markdown labels for orbit and telemetry records.
zh = strcmp(language, 'zh');
text = char(value);
switch key
    case 'trajectory_frame'
        label = choose(zh, '轨道坐标系', 'Trajectory coordinate system');
        switch text
            case 'approximate_geocentric_equatorial'
                text = choose(zh, '地心赤道坐标系（内置近似轨道模型）', ...
                    'Geocentric equatorial axes (built-in approximate orbit model)');
            case 'source_frame_not_recorded'
                text = choose(zh, '源轨道未记录坐标定义；请声明坐标系后重新运行', ...
                    'Source axes were not recorded; declare the coordinate system and rerun');
        end
    case 'telemetry_status'
        label = choose(zh, '遥测比较', 'Telemetry comparison');
        switch text
            case 'not_run_no_data'
                text = choose(zh, '未执行（本次未导入遥测数据）', ...
                    'Not run (no telemetry data imported for this task)');
            case 'not_run'
                text = choose(zh, '尚未生成比较结果', 'Comparison results not yet generated');
            case 'comparison_available'
                text = choose(zh, '已生成比较结果（评价见遥测分析）', ...
                    'Comparison results generated (see telemetry analysis for assessment)');
        end
    otherwise
        error('leotherm:ReportMetadata', 'Unsupported metadata field: %s', key);
end
end

function value = choose(zh, chinese, english)
if zh, value = chinese; else, value = english; end
end
