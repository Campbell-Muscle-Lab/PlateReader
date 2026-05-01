classdef CitrateSynthase_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        BradfordUIFigure                matlab.ui.Figure
        Menu                            matlab.ui.container.Menu
        LoadlayoutMenu                  matlab.ui.container.Menu
        LoaddataMenu                    matlab.ui.container.Menu
        ExportanalysisMenu              matlab.ui.container.Menu
        LoadanalysisMenu                matlab.ui.container.Menu
        AssayParametersPanel            matlab.ui.container.Panel
        CSActivityperChamberEditField   matlab.ui.control.NumericEditField
        CSActivityperChamberEditFieldLabel  matlab.ui.control.Label
        AddedVolumeuLEditField          matlab.ui.control.NumericEditField
        AddedVolumeuLEditFieldLabel     matlab.ui.control.Label
        StockMitoVolumeuLEditField      matlab.ui.control.NumericEditField
        StockMitoVolumeuLEditFieldLabel  matlab.ui.control.Label
        ReactionVolumeuLEditField       matlab.ui.control.NumericEditField
        ReactionVolumeuLEditFieldLabel  matlab.ui.control.Label
        SampleValuesPanel               matlab.ui.container.Panel
        ResultsTable                    matlab.ui.control.Table
        SummaryTable                    matlab.ui.control.Table
        SampleValuesTimeAxes            matlab.ui.control.UIAxes
        SampleValuesAxes                matlab.ui.control.UIAxes
        StandardCurvePanel              matlab.ui.container.Panel
        rvalueEditField                 matlab.ui.control.NumericEditField
        rvalueEditField_2Label          matlab.ui.control.Label
        InterceptEditField              matlab.ui.control.NumericEditField
        InterceptEditField_2Label       matlab.ui.control.Label
        SlopeEditField                  matlab.ui.control.NumericEditField
        SlopeEditField_2Label           matlab.ui.control.Label
        StandardCurveAxes               matlab.ui.control.UIAxes
        StandardCurveTimeAxes           matlab.ui.control.UIAxes
    end


    properties (Access = public)
        plate_reader_data % Description
    end
    
    properties (Access = private)
        PlateReaderApp % Description
    end

    methods (Access = public)

        function CalculateStandardCurve(app)

            col_names = app.plate_reader_data.col_names;
            plate_layout = app.plate_reader_data.plate_layout;
            formatted_data = app.plate_reader_data.formatted_data;
            standard_concentrations = app.plate_reader_data.standard_concentrations.concentration;
            analyzed_data = formatted_data;
            time = app.plate_reader_data.time;


            formatted_data_size = size(formatted_data);

            if ndims(formatted_data) > 2
                counter = formatted_data_size(3);
            end


            for i = 1 : numel(col_names)
                standard_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Standard');
            end
        
            col_map = return_matplotlib_default_colors;
            for i = 1 : counter
                hold(app.StandardCurveTimeAxes,"on")
                time_point_data = [];
                time_point_data = formatted_data(:,:,i);
                standard_values = [];
                standard_values = formatted_data(any(standard_mask,2),any(standard_mask,1),i);
                standard_mean_time(:,i) = mean(standard_values,2,'omitnan');

            end

            for i = 1 : size(standard_mean_time,1)
                hold(app.StandardCurveTimeAxes,"on")
                plot(app.StandardCurveTimeAxes,time,standard_mean_time(i,:), ...
                    'o','LineStyle','-','Color',col_map(i,:),'MarkerFaceColor',col_map(i,:),'MarkerEdgeColor','k')
            end

            standard_mean = mean(standard_mean_time,2);
            %Master mix correction April 23, 26
            standard_mean = standard_mean - standard_mean(1)
            
            x = standard_concentrations;
            y = standard_mean;

            line_fit = fit_linear_model(x, y)
            line_fit_wo_int = fitlm(x,y,"Intercept",false)


            hold(app.StandardCurveAxes,"on")
            plot(app.StandardCurveAxes,line_fit.x_fit, line_fit.y_fit, 'LineStyle','-', ...
                'LineWidth', 1.75,'Color',[0 0 0 0.7]);
            scatter(app.StandardCurveAxes,standard_concentrations,standard_mean,50,'MarkerFaceColor','g','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)
            xlim(app.StandardCurveAxes,[0 max(standard_concentrations)])
            ylim(app.StandardCurveAxes,[0 max(standard_mean)])

            app.SlopeEditField.Value = line_fit.slope;
            app.InterceptEditField.Value = line_fit.intercept;
            app.rvalueEditField.Value = line_fit.r;


            app.plate_reader_data.standard_curve_fit = line_fit;
            app.plate_reader_data.standard_values = standard_values;
            app.plate_reader_data.standard_mean = standard_mean;
            app.plate_reader_data.analyzed_data = analyzed_data;


            CalculateSampleValues(app)


        end

        function CalculateSampleValues(app)

            col_names = app.plate_reader_data.col_names;
            sample_layout = app.plate_reader_data.sample_layout;
            plate_layout = app.plate_reader_data.plate_layout;
            formatted_data = app.plate_reader_data.formatted_data;
            analyzed_data = app.plate_reader_data.analyzed_data;
            time = app.plate_reader_data.time;

            formatted_data_size = size(formatted_data);

            if ndims(formatted_data) > 2
                counter = formatted_data_size(3);
            end

            slope = app.plate_reader_data.standard_curve_fit.slope;
            intercept = app.plate_reader_data.standard_curve_fit.intercept;

            for i = 1 : numel(col_names)
                sample_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Sample');
                blank_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Blank');

            end

            for i = 1 : counter
                sample_matrix(:,:,i) = formatted_data(any(sample_mask,2),any(sample_mask,1),i);
                blank_matrix(:,:,i) = formatted_data(any(blank_mask,2),any(blank_mask,1),i);
            end

            sample_matrix(:,:,:) = sample_matrix(:,:,:) - sample_matrix(:,:,1);

            sample_values(:,:,:) = (sample_matrix(:,:,:) - intercept)./slope;
            blank_values(:,:,:) = (blank_matrix(:,:,:) - intercept)./slope;

            % 
            % sample_values(:,:,i) = (sample_matrix(:,:,i) - intercept)./slope;

            % analyzed_data(any(sample_mask,2),any(sample_mask,1),i) = sample_values(:,:,i);

            for i = 1 : counter
                analyzed_data(any(sample_mask,2),any(sample_mask,1),i) = sample_values(:,:,i);
                analyzed_data(any(blank_mask,2),any(blank_mask,1),i) = blank_values(:,:,i);
            end
            
            col_map = turbo(numel(sample_matrix(:,:,1)));
            hold(app.SampleValuesTimeAxes,"on")
            m = 1;
            for j = 1 : size(sample_matrix,2)
                for i = 1 : size(sample_matrix,1)
                    
                    time_data = [];
                    time_data = squeeze(sample_matrix(i,j,1:end))
                    h(m) = plot(app.SampleValuesTimeAxes,time,time_data, ...
                        'o','LineStyle','-','MarkerEdgeColor','k', ...
                        'MarkerFaceColor',col_map(m,:),'Color',col_map(m,:));
                    m = m + 1;
                end
            end

            for j = 1 : size(blank_matrix,2)
                for i = 1 : size(blank_matrix,1)
                    blank_time_data = [];
                    blank_time_data = squeeze(blank_matrix(i,j,1:end))
                    plot(app.SampleValuesTimeAxes,time,blank_time_data, ...
                        'o','LineStyle','-','MarkerEdgeColor','k','Color','k', ...
                        'MarkerFaceColor','k');
                    m = m + 1;
                end
            end

            app.plate_reader_data.blank_values = blank_values;
            app.plate_reader_data.sample_values = sample_values;
            app.plate_reader_data.analyzed_data = analyzed_data;

            app.ConcentrationOverTime;
        end

        function RefreshDisplay(app)

            figs = {'StandardCurveAxes','SampleValuesAxes','StandardCurveTimeAxes','SampleValuesTimeAxes'};
            for i = 1 : numel(figs)
                cla(app.(figs{i}))
            end

            txt = {'SlopeEditField','InterceptEditField','rvalueEditField'};

            for i = 1 : numel(txt)
                app.(txt{i}).Value = 0;
            end

            app.SummaryTable.Data = [];
            app.ResultsTable.Data = [];
        end

        function FormatData(app)

            initial_matrix = [];
            initial_matrix = readmatrix(app.plate_reader_data.data_file_string);
            app.plate_reader_data.temperature = initial_matrix(1,1);
            [m,n] = size(initial_matrix);
            shifted_matrix = NaN(m,n);

            shifted_matrix(1, :) = initial_matrix(1, :);
            shifted_matrix(2:end, 2:end) = initial_matrix(2:end, 1:end-1);

            shifted_matrix(:,1) = [];

            k = 1;
            size(shifted_matrix,1)
            for i = 1 : size(shifted_matrix,1)
                if sum(isnan(shifted_matrix(i,:))) == size(shifted_matrix,2)
                    rem_ix(k) = i;
                    k = k + 1;
                end
            end

            shifted_matrix(rem_ix,:) = []
            rem_ix = [];
            size(shifted_matrix,1)
            k = 1;
            for i = 1 : size(shifted_matrix,2)
                sum(isnan(shifted_matrix(:,i)))
                if sum(isnan(shifted_matrix(:,i))) == size(shifted_matrix,1)
                    rem_ix(k) = i;
                    k = k + 1;
                end
            end
            shifted_matrix(:,rem_ix) = [];

            col_names = app.plate_reader_data.plate_layout.Properties.VariableNames;
            col_names(1) = [];


            k = 1;
            for i = 1:numel(col_names)

                if any(~strcmpi(app.plate_reader_data.plate_layout.(col_names{i}),'Blank'))
                    formatted_data(:,i) = shifted_matrix(:,k);
                    k = k + 1;
                else
                    formatted_data(:,i) = NaN(size(shifted_matrix,1),1);
                end

            end

            app.plate_reader_data.formatted_data = formatted_data;
            app.plate_reader_data.col_names = col_names;
            app.CalculateStandardCurve



        end

        function ReloadDisplay(app)
            app.plate_reader_data
            line_fit = app.plate_reader_data.standard_curve_fit;
            standard_concentrations = app.plate_reader_data.standard_concentrations.concentration;
            standard_mean = app.plate_reader_data.standard_mean;

            hold(app.StandardCurveTimeAxes,"on")
            plot(app.StandardCurveTimeAxes,line_fit.x_fit, line_fit.y_fit, 'LineStyle','-', ...
                'LineWidth', 1.75,'Color',[0 0 0 0.7]);
            scatter(app.StandardCurveTimeAxes,standard_concentrations,standard_mean,50,'MarkerFaceColor','g','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)
            xlim(app.StandardCurveTimeAxes,[0 max(standard_concentrations)])
            ylim(app.StandardCurveTimeAxes,[0 round(max(standard_mean))])

            app.SlopeEditField.Value = line_fit.slope;
            app.InterceptEditField.Value = line_fit.intercept;
            app.rvalueEditField.Value = line_fit.r;

            col_names = app.plate_reader_data.col_names;
            plate_layout = app.plate_reader_data.plate_layout;
            formatted_data = app.plate_reader_data.formatted_data;
            sample_values = app.plate_reader_data.sample_values;

            for i = 1 : numel(col_names)
                sample_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Sample');
            end

            sample_matrix = formatted_data(any(sample_mask,2),any(sample_mask,1));

            scatter(app.SampleValuesAxes,sample_values,sample_matrix,50,'MarkerFaceColor','b','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)


        end

        function ConvertData(app)
            layout_size = size(app.plate_reader_data.plate_layout);
            layout_size(2) = layout_size(2)-1;

            lines = [];
            lines = fileread(app.plate_reader_data.data_file_string);
            lines = regexp(lines, '\r\n|\n|\r', 'split')';
            lines = string(lines);

            read_until_ix = find(contains(lines, "~End"), 1);
            if isempty(read_until_ix)
                read_until_ix = numel(lines);
            else
                read_until_ix = read_until_ix - 1;
            end

            lines = lines(1:read_until_ix);

            read_after_ix = find(contains(lines, "Temperature"), 1);

            lines = lines(read_after_ix+1:end);
            lines = lines(strlength(strtrim(lines)) > 0);
            parts = split(lines, sprintf('\t'));


            time_column = parts(:,1);
            time_column(strcmp(time_column,"")) = [];
            time_column = duration(time_column, 'InputFormat', 'hh:mm:ss');
            time_column = seconds(time_column)

            d_parts = double(parts);
            d_parts(:,1) = [];
            app.plate_reader_data.temperature = d_parts(1,1);
            d_parts(:,1) = [];
            mat_size = size(d_parts);
            if mat_size(2) ~= layout_size(2)
                d_parts(:,layout_size(2)+1:end) = [];
            end

            initial_matrix = nan(layout_size(1),layout_size(2),numel(time_column));

            for i = 1 : numel(time_column)
                initial_matrix(:,:,i) = d_parts(1+(i-1)*8:i*8,:);
            end
            col_names = app.plate_reader_data.plate_layout.Properties.VariableNames;
            col_names(1) = [];
            app.plate_reader_data.formatted_data = initial_matrix;
            app.plate_reader_data.time = time_column;
            app.plate_reader_data.col_names = col_names;
            app.CalculateStandardCurve

        end
        
        function ConcentrationOverTime(app)

            blank_values = app.plate_reader_data.blank_values
            sample_values = app.plate_reader_data.sample_values

            time = app.plate_reader_data.time;
            m = 1;

            for j = 1 : size(blank_values,2)
                for i = 1 : size(blank_values,1)
                    x = time
                    y = squeeze(blank_values(i,j,1:end))
                    line_fit = fit_linear_model(x, y)
                    blank_slopes(m) = line_fit.slope
                    m = m + 1;
                end
            end

            mean_blank_slopes = mean(blank_slopes);
            m = 1;
            col_map = turbo(numel(sample_values(:,:,1)));

            for j = 1 : size(sample_values,2)
                for i = 1 : size(sample_values,1)
                    x = time
                    y = squeeze(sample_values(i,j,1:end))
                    line_fit = fit_linear_model(x, y)
                    sample_slopes(m) = line_fit.slope
                    m = m + 1;
                end
            end

            corr_sample_slopes = sample_slopes - mean_blank_slopes;

            hold(app.SampleValuesAxes,"on")
            plot(app.SampleValuesAxes,time, corr_sample_slopes.*time, 'LineStyle','-', ...
                'LineWidth', 1.75);
            colororder(app.SampleValuesAxes,col_map)

            app.plate_reader_data.sample_slopes = sample_slopes;
            app.plate_reader_data.corr_sample_slopes = corr_sample_slopes;
            app.plate_reader_data.blank_slopes = blank_slopes;

            UpdateSummaryTable(app)

        end
        
        function UpdateSummaryTable(app)

            sample_layout = app.plate_reader_data.sample_layout;
            sample_slopes = app.plate_reader_data.sample_slopes;
            corr_sample_slopes = app.plate_reader_data.corr_sample_slopes;
            blank_slopes = app.plate_reader_data.blank_slopes;
            bt = [];
            pt = [];
           
            
            for i = 1 : numel(sample_slopes)
                pt.sample_type{i,:} = sample_layout.region{i};
                pt.color{i,:} = '';
                pt.slope(i,:) = sample_slopes(i);
                pt.corr_slope(i,:) = corr_sample_slopes(i);
            end
           
            app.SummaryTable.Data = [app.SummaryTable.Data; struct2table(pt)];
            
            col_map = turbo(numel(sample_slopes));
            for i = 1 : numel(sample_slopes)
                s = uistyle("BackgroundColor",col_map(i,:));
                addStyle(app.SummaryTable,s,"cell",[i 2])
            end
            
            for i = 1 : numel(blank_slopes)
                bt.sample_type{i,:} = 'Blank';
                bt.color{i,:} = '';
                bt.slope(i,:) = blank_slopes(i);
                bt.corr_slope(i,:) = blank_slopes(i) - mean(blank_slopes);
            end
            app.SummaryTable.Data = [app.SummaryTable.Data; struct2table(bt)];

            starting_ix = numel(sample_slopes);
            for i = 1 : numel(sample_slopes)
                s = uistyle("BackgroundColor",'k');
                addStyle(app.SummaryTable,s,"cell",[starting_ix+i 2])
            end

            UpdateResultsTable(app)
        end
        
        function UpdateResultsTable(app)

            sample_layout = app.plate_reader_data.sample_layout;
            corr_sample_slopes = app.plate_reader_data.corr_sample_slopes;
            cs_assay_volumes = app.plate_reader_data.cs_assay_volumes;
            reaction_volume = app.ReactionVolumeuLEditField.Value/1e6;
            added_volume = app.AddedVolumeuLEditField.Value;
            stock_mito_volume_input = app.StockMitoVolumeuLEditField.Value;
            cs_activity_per_chamber = app.CSActivityperChamberEditField.Value;

            converted_slopes = corr_sample_slopes * 60 * reaction_volume;

            un_hashcode = unique(sample_layout.hashcode);
            un_specimen = unique(sample_layout.sample_no);

            m = 1;
            for i = 1 : numel(un_hashcode)
                for j = 1 : numel(un_specimen)
                    h_ix = find(strcmp(sample_layout.hashcode,un_hashcode{i}));
                    s_ix = find(sample_layout(h_ix,:).sample_no==un_specimen(j));
                    results_table.region{m,1} = sample_layout.region{h_ix(s_ix(1))};
                    activity_per_well(m,1) = mean(converted_slopes(s_ix));
                    m = m + 1;
                end
            end
            

            un_region = unique(results_table.region);

            for i = 1 : numel(un_region)

                ix = find(strcmp(un_region{i},cs_assay_volumes.region))

                u_ix = find(strcmp(un_region{i},results_table.region));

                stock_mito_volume(i,1) = added_volume * stock_mito_volume_input/cs_assay_volumes.volume_for_cs_assay(ix)

            end
            
            results_table.cs_activity = activity_per_well./stock_mito_volume
            results_table.mito_volume = cs_activity_per_chamber./results_table.cs_activity;


            app.ResultsTable.Data = [app.ResultsTable.Data; struct2table(results_table)];

            app.plate_reader_data.results_table = results_table;


            
            
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, caller)
            addpath(genpath('utilities'))
            movegui(app.BradfordUIFigure,'center')
            app.PlateReaderApp = caller;

        end

        % Menu selected function: LoadlayoutMenu
        function LoadlayoutMenuSelected(app, event)
            app.BradfordUIFigure.Visible = 'off';
            [file_string,path_string]=uigetfile2( ...
                {'*.xlsx','XLSX'}, ...
                'Select Layout File');
            app.BradfordUIFigure.Visible = 'on';
            figure(app.BradfordUIFigure)

            if (path_string~=0)
                app.plate_reader_data = [];
                app.plate_reader_data.layout_file_string = fullfile(path_string,file_string);
                app.plate_reader_data.sample_layout = readtable(app.plate_reader_data.layout_file_string,'Sheet','sample_layout');
                app.plate_reader_data.plate_layout = readtable(app.plate_reader_data.layout_file_string,'Sheet','plate_layout');
                app.plate_reader_data.standard_concentrations = readtable(app.plate_reader_data.layout_file_string,'Sheet','standard_concentrations');
                app.plate_reader_data.cs_assay_volumes = readtable(app.plate_reader_data.layout_file_string,'Sheet','cs_assay_volumes');
                app.LoaddataMenu.Enable = 1;
                app.ExportanalysisMenu.Enable = 1;
            end

        end

        % Menu selected function: LoaddataMenu
        function LoaddataMenuSelected(app, event)
            app.BradfordUIFigure.Visible = 'off';

            [file_string,path_string]=uigetfile2( ...
                {'*.txt','TXT'}, ...
                'Select Data File');
            app.BradfordUIFigure.Visible = 'on';
            figure(app.BradfordUIFigure)

            if (path_string~=0)
                app.plate_reader_data.data_file_string = fullfile(path_string,file_string);
                % app.FormatData;
                app.RefreshDisplay;
                app.ConvertData;
            end
        end

        % Menu selected function: ExportanalysisMenu
        function ExportanalysisMenuSelected(app, event)
            app.BradfordUIFigure.Visible = 'off';
            [file_string,path_string] = uiputfile2( ...
                {'*.xlsx','Excel file'},'Enter Excel File Name For Analysis Results');
            app.BradfordUIFigure.Visible = 'on';
            figure(app.BradfordUIFigure)

            if (path_string~=0)
                output_file_string = fullfile(path_string,file_string);

                try
                    delete(output_file_string);
                end


                result_layout = app.plate_reader_data.sample_layout;
                plate_layout = app.plate_reader_data.plate_layout;
                analyzed_data = app.plate_reader_data.analyzed_data;
                standard_values = app.plate_reader_data.standard_values;

                for i = 1 : numel(result_layout.well_no)

                    well_info = regexp(result_layout.well_no(i), '(\d+|[a-zA-Z]+)', 'match');
                    well_info = well_info{1};
                    well_row = well_info{1};
                    well_column = str2double(well_info{2});
                    well_row_ix = find(strcmp(plate_layout.Row,well_row));
                    result_layout.concentration_mg_per_ml(i) = analyzed_data(well_row_ix,well_column);
                    result_layout.volume_for_cs_assay_ul(i) = result_layout.concentration(i)*30;
                end

                un_hashcode = unique(result_layout.hashcode);
                un_specimen = unique(result_layout.sample_no);

                var_names = result_layout.Properties.VariableNames;
                var_types = result_layout.Properties.VariableTypes;

                summary_table = table('Size', [0, numel(var_names)], 'VariableNames', var_names, 'VariableTypes', var_types);
                summary_table = removevars(summary_table,'well_no');
                new_var_names = summary_table.Properties.VariableNames;
                new_var_names(strcmp(new_var_names,'concentration')) = [];

                m = 1;
                for i = 1 : numel(un_hashcode)
                    for j = 1 : numel(un_specimen)
                        h_ix = find(strcmp(result_layout.hashcode,un_hashcode{i}));
                        s_ix = find(strcmp(result_layout(h_ix,:).sample_no,un_specimen{j}));
                        for u = 1 : numel(new_var_names)
                            summary_table.(new_var_names{u})(m) = result_layout.(new_var_names{u})(s_ix(1));
                        end
                        summary_table.concentration(m) = mean(result_layout.concentration(s_ix));
                        m = m + 1;
                    end
                end
            end

            standard_table = table;

            for i = 1 : size(standard_values,2)
                col_name = sprintf('standard_col_%i',i);
                standard_table.(col_name) = standard_values(:,i);
            end

            writetable(summary_table,output_file_string,'Sheet','analysis_summary')
            writetable(result_layout,output_file_string,'Sheet','plate_results')
            writetable(standard_table,output_file_string,'Sheet','standard_columns')

            output_file_string = replace(output_file_string,'.xlsx','.pr');
            analysis_session = app.plate_reader_data;
            save(output_file_string,'analysis_session')



        end

        % Menu selected function: LoadanalysisMenu
        function LoadanalysisMenuSelected(app, event)
            app.BradfordUIFigure.Visible = 'off';

            [file_string,path_string]=uigetfile2( ...
                {'*.pr','PR'}, ...
                'Select PlateReader File');
            app.BradfordUIFigure.Visible = 'on';
            figure(app.BradfordUIFigure)
            if (path_string~=0)
                temp = load(fullfile(path_string,file_string),'-mat','analysis_session');
                analysis_session = temp.analysis_session;
                app.plate_reader_data = [];
                app.plate_reader_data = analysis_session;
                ReloadDisplay(app);
            end

        end

        % Value changed function: AddedVolumeuLEditField, 
        % ...and 3 other components
        function UpdateCalculations(app, event)
            RefreshDisplay(app);
            CalculateStandardCurve(app);            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create BradfordUIFigure and hide until all components are created
            app.BradfordUIFigure = uifigure('Visible', 'off');
            app.BradfordUIFigure.Position = [100 100 1365 463];
            app.BradfordUIFigure.Name = 'PlateReader';

            % Create Menu
            app.Menu = uimenu(app.BradfordUIFigure);
            app.Menu.Text = 'Menu';

            % Create LoadlayoutMenu
            app.LoadlayoutMenu = uimenu(app.Menu);
            app.LoadlayoutMenu.MenuSelectedFcn = createCallbackFcn(app, @LoadlayoutMenuSelected, true);
            app.LoadlayoutMenu.Text = 'Load layout';

            % Create LoaddataMenu
            app.LoaddataMenu = uimenu(app.Menu);
            app.LoaddataMenu.MenuSelectedFcn = createCallbackFcn(app, @LoaddataMenuSelected, true);
            app.LoaddataMenu.Enable = 'off';
            app.LoaddataMenu.Text = 'Load data';

            % Create ExportanalysisMenu
            app.ExportanalysisMenu = uimenu(app.Menu);
            app.ExportanalysisMenu.MenuSelectedFcn = createCallbackFcn(app, @ExportanalysisMenuSelected, true);
            app.ExportanalysisMenu.Enable = 'off';
            app.ExportanalysisMenu.Text = 'Export analysis';

            % Create LoadanalysisMenu
            app.LoadanalysisMenu = uimenu(app.Menu);
            app.LoadanalysisMenu.MenuSelectedFcn = createCallbackFcn(app, @LoadanalysisMenuSelected, true);
            app.LoadanalysisMenu.Text = 'Load analysis';

            % Create StandardCurvePanel
            app.StandardCurvePanel = uipanel(app.BradfordUIFigure);
            app.StandardCurvePanel.Title = 'Standard Curve';
            app.StandardCurvePanel.Position = [15 9 477 330];

            % Create StandardCurveTimeAxes
            app.StandardCurveTimeAxes = uiaxes(app.StandardCurvePanel);
            xlabel(app.StandardCurveTimeAxes, 'Time (s)')
            ylabel(app.StandardCurveTimeAxes, 'Absorbance')
            zlabel(app.StandardCurveTimeAxes, 'Z')
            app.StandardCurveTimeAxes.Box = 'on';
            app.StandardCurveTimeAxes.Position = [12 145 441 155];

            % Create StandardCurveAxes
            app.StandardCurveAxes = uiaxes(app.StandardCurvePanel);
            xlabel(app.StandardCurveAxes, 'Concentration (uM)')
            ylabel(app.StandardCurveAxes, 'Absorbance')
            zlabel(app.StandardCurveAxes, 'Z')
            app.StandardCurveAxes.Box = 'on';
            app.StandardCurveAxes.Position = [12 1 319 133];

            % Create SlopeEditField_2Label
            app.SlopeEditField_2Label = uilabel(app.StandardCurvePanel);
            app.SlopeEditField_2Label.HorizontalAlignment = 'right';
            app.SlopeEditField_2Label.Position = [340 99 36 22];
            app.SlopeEditField_2Label.Text = 'Slope';

            % Create SlopeEditField
            app.SlopeEditField = uieditfield(app.StandardCurvePanel, 'numeric');
            app.SlopeEditField.Editable = 'off';
            app.SlopeEditField.FontSize = 9;
            app.SlopeEditField.Position = [401 99 60 22];

            % Create InterceptEditField_2Label
            app.InterceptEditField_2Label = uilabel(app.StandardCurvePanel);
            app.InterceptEditField_2Label.HorizontalAlignment = 'right';
            app.InterceptEditField_2Label.Position = [340 68 52 22];
            app.InterceptEditField_2Label.Text = 'Intercept';

            % Create InterceptEditField
            app.InterceptEditField = uieditfield(app.StandardCurvePanel, 'numeric');
            app.InterceptEditField.Editable = 'off';
            app.InterceptEditField.FontSize = 9;
            app.InterceptEditField.Position = [401 68 60 22];

            % Create rvalueEditField_2Label
            app.rvalueEditField_2Label = uilabel(app.StandardCurvePanel);
            app.rvalueEditField_2Label.HorizontalAlignment = 'right';
            app.rvalueEditField_2Label.Position = [340 35 42 22];
            app.rvalueEditField_2Label.Text = 'r-value';

            % Create rvalueEditField
            app.rvalueEditField = uieditfield(app.StandardCurvePanel, 'numeric');
            app.rvalueEditField.Editable = 'off';
            app.rvalueEditField.FontSize = 9;
            app.rvalueEditField.Position = [401 34 60 22];

            % Create SampleValuesPanel
            app.SampleValuesPanel = uipanel(app.BradfordUIFigure);
            app.SampleValuesPanel.Title = 'Sample Values';
            app.SampleValuesPanel.Position = [506 10 851 446];

            % Create SampleValuesAxes
            app.SampleValuesAxes = uiaxes(app.SampleValuesPanel);
            xlabel(app.SampleValuesAxes, 'Time (s)')
            ylabel(app.SampleValuesAxes, 'Concentration (uM)')
            zlabel(app.SampleValuesAxes, 'Z')
            app.SampleValuesAxes.Box = 'on';
            app.SampleValuesAxes.Position = [16 13 426 185];

            % Create SampleValuesTimeAxes
            app.SampleValuesTimeAxes = uiaxes(app.SampleValuesPanel);
            xlabel(app.SampleValuesTimeAxes, 'Time (s)')
            ylabel(app.SampleValuesTimeAxes, 'Absorbance')
            zlabel(app.SampleValuesTimeAxes, 'Z')
            app.SampleValuesTimeAxes.Box = 'on';
            app.SampleValuesTimeAxes.Position = [16 219 426 185];

            % Create SummaryTable
            app.SummaryTable = uitable(app.SampleValuesPanel);
            app.SummaryTable.ColumnName = {'Sample Type'; 'Color'; 'Slope (uM/s)'; 'Corr. Slope (uM/s)'};
            app.SummaryTable.RowName = {};
            app.SummaryTable.Position = [452 197 391 206];

            % Create ResultsTable
            app.ResultsTable = uitable(app.SampleValuesPanel);
            app.ResultsTable.ColumnName = {'Region'; 'CS Activity (U/uL)'; 'Mito Volume (uL)'};
            app.ResultsTable.RowName = {};
            app.ResultsTable.Position = [452 24 391 164];

            % Create AssayParametersPanel
            app.AssayParametersPanel = uipanel(app.BradfordUIFigure);
            app.AssayParametersPanel.Title = 'Assay Parameters';
            app.AssayParametersPanel.Position = [12 346 480 110];

            % Create ReactionVolumeuLEditFieldLabel
            app.ReactionVolumeuLEditFieldLabel = uilabel(app.AssayParametersPanel);
            app.ReactionVolumeuLEditFieldLabel.HorizontalAlignment = 'right';
            app.ReactionVolumeuLEditFieldLabel.Position = [15 50 120 22];
            app.ReactionVolumeuLEditFieldLabel.Text = 'Reaction Volume (uL)';

            % Create ReactionVolumeuLEditField
            app.ReactionVolumeuLEditField = uieditfield(app.AssayParametersPanel, 'numeric');
            app.ReactionVolumeuLEditField.ValueChangedFcn = createCallbackFcn(app, @UpdateCalculations, true);
            app.ReactionVolumeuLEditField.Position = [149 50 80 22];
            app.ReactionVolumeuLEditField.Value = 150;

            % Create StockMitoVolumeuLEditFieldLabel
            app.StockMitoVolumeuLEditFieldLabel = uilabel(app.AssayParametersPanel);
            app.StockMitoVolumeuLEditFieldLabel.HorizontalAlignment = 'right';
            app.StockMitoVolumeuLEditFieldLabel.Position = [240 50 129 22];
            app.StockMitoVolumeuLEditFieldLabel.Text = 'Stock Mito Volume (uL)';

            % Create StockMitoVolumeuLEditField
            app.StockMitoVolumeuLEditField = uieditfield(app.AssayParametersPanel, 'numeric');
            app.StockMitoVolumeuLEditField.ValueChangedFcn = createCallbackFcn(app, @UpdateCalculations, true);
            app.StockMitoVolumeuLEditField.Position = [384 50 80 22];
            app.StockMitoVolumeuLEditField.Value = 3;

            % Create AddedVolumeuLEditFieldLabel
            app.AddedVolumeuLEditFieldLabel = uilabel(app.AssayParametersPanel);
            app.AddedVolumeuLEditFieldLabel.HorizontalAlignment = 'right';
            app.AddedVolumeuLEditFieldLabel.Position = [15 13 108 22];
            app.AddedVolumeuLEditFieldLabel.Text = 'Added Volume (uL)';

            % Create AddedVolumeuLEditField
            app.AddedVolumeuLEditField = uieditfield(app.AssayParametersPanel, 'numeric');
            app.AddedVolumeuLEditField.ValueChangedFcn = createCallbackFcn(app, @UpdateCalculations, true);
            app.AddedVolumeuLEditField.Position = [149 13 80 22];
            app.AddedVolumeuLEditField.Value = 3;

            % Create CSActivityperChamberEditFieldLabel
            app.CSActivityperChamberEditFieldLabel = uilabel(app.AssayParametersPanel);
            app.CSActivityperChamberEditFieldLabel.HorizontalAlignment = 'right';
            app.CSActivityperChamberEditFieldLabel.Position = [236 13 136 22];
            app.CSActivityperChamberEditFieldLabel.Text = 'CS Activity per Chamber';

            % Create CSActivityperChamberEditField
            app.CSActivityperChamberEditField = uieditfield(app.AssayParametersPanel, 'numeric');
            app.CSActivityperChamberEditField.ValueChangedFcn = createCallbackFcn(app, @UpdateCalculations, true);
            app.CSActivityperChamberEditField.Position = [384 13 80 22];
            app.CSActivityperChamberEditField.Value = 0.2;

            % Show the figure after all components are created
            app.BradfordUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = CitrateSynthase_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.BradfordUIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.BradfordUIFigure)
        end
    end
end