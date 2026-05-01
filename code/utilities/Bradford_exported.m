classdef Bradford_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        BradfordUIFigure              matlab.ui.Figure
        Menu                          matlab.ui.container.Menu
        LoadlayoutMenu                matlab.ui.container.Menu
        LoaddataMenu                  matlab.ui.container.Menu
        ExportanalysisMenu            matlab.ui.container.Menu
        LoadanalysisMenu              matlab.ui.container.Menu
        SampleValuesPanel             matlab.ui.container.Panel
        DilutionfactorEditField       matlab.ui.control.NumericEditField
        DilutionfactorEditFieldLabel  matlab.ui.control.Label
        SampleValuesAxes              matlab.ui.control.UIAxes
        StandardCurvePanel            matlab.ui.container.Panel
        InterceptEditField            matlab.ui.control.NumericEditField
        InterceptEditFieldLabel       matlab.ui.control.Label
        rvalueEditField               matlab.ui.control.NumericEditField
        rvalueEditFieldLabel          matlab.ui.control.Label
        SlopeEditField                matlab.ui.control.NumericEditField
        SlopeEditFieldLabel           matlab.ui.control.Label
        StandardCurveAxes             matlab.ui.control.UIAxes
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

            for i = 1 : numel(col_names)
                standard_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Standard');
            end
        

            standard_values = formatted_data(any(standard_mask,2),any(standard_mask,1));
            standard_correction = standard_values(1,:);
            standard_values = standard_values - standard_values(1,:);

            standard_mean = mean(standard_values,2,'omitnan');

            x = standard_concentrations;
            y = standard_mean;

            line_fit = fit_linear_model(x, y);

            hold(app.StandardCurveAxes,"on")
            plot(app.StandardCurveAxes,line_fit.x_fit, line_fit.y_fit, 'LineStyle','-', ...
                'LineWidth', 1.75,'Color',[0 0 0 0.7]);
            scatter(app.StandardCurveAxes,standard_concentrations,standard_mean,50,'MarkerFaceColor','g','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)
            xlim(app.StandardCurveAxes,[0 max(standard_concentrations)])
            ylim(app.StandardCurveAxes,[0 round(max(standard_mean))])

            app.SlopeEditField.Value = line_fit.slope;
            app.InterceptEditField.Value = line_fit.intercept;
            app.rvalueEditField.Value = line_fit.r;


            app.plate_reader_data.standard_curve_fit = line_fit;
            app.plate_reader_data.standard_values = standard_values;
            app.plate_reader_data.standard_correction = standard_correction;
            app.plate_reader_data.standard_mean = standard_mean;
            app.plate_reader_data.analyzed_data = analyzed_data;


            CalculateSampleValues(app)



        end

        function CalculateSampleValues(app)

            col_names = app.plate_reader_data.col_names;
            plate_layout = app.plate_reader_data.plate_layout;
            formatted_data = app.plate_reader_data.formatted_data;
            analyzed_data = app.plate_reader_data.analyzed_data;
            dilution_factor = app.DilutionfactorEditField.Value;

            slope = app.plate_reader_data.standard_curve_fit.slope;
            intercept = app.plate_reader_data.standard_curve_fit.intercept;
            standard_correction = app.plate_reader_data.standard_correction;

            for i = 1 : numel(col_names)
                sample_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Sample');
            end

            sample_matrix = formatted_data(any(sample_mask,2),any(sample_mask,1));
            sample_matrix = sample_matrix - mean(standard_correction)

            sample_values = dilution_factor*(sample_matrix - intercept)./slope;

            analyzed_data(any(sample_mask,2),any(sample_mask,1)) = sample_values;

            scatter(app.SampleValuesAxes,sample_values,sample_matrix,50,'MarkerFaceColor','b','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)

            app.plate_reader_data.dilution_factor = dilution_factor;
            app.plate_reader_data.sample_values = sample_values;
            app.plate_reader_data.analyzed_data = analyzed_data;
        end

        function RefreshDisplay(app)

            figs = {'StandardCurveAxes','SampleValuesAxes'};
            for i = 1 : numel(figs)
                clf(app.(figs{i}))
            end

            txt = {'Slope','Intercept','rvalue'};

            for i = 1 : numel(txt)
                app.(txt{i}).Value = 0;
            end
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

            hold(app.StandardCurveAxes,"on")
            plot(app.StandardCurveAxes,line_fit.x_fit, line_fit.y_fit, 'LineStyle','-', ...
                'LineWidth', 1.75,'Color',[0 0 0 0.7]);
            scatter(app.StandardCurveAxes,standard_concentrations,standard_mean,50,'MarkerFaceColor','g','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)
            xlim(app.StandardCurveAxes,[0 max(standard_concentrations)])
            ylim(app.StandardCurveAxes,[0 round(max(standard_mean))])

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


            initial_matrix = double(parts);
            initial_matrix(:,1) = [];
            app.plate_reader_data.temperature = initial_matrix(1,1);
            initial_matrix(:,1) = [];
            mat_size = size(initial_matrix);

            if mat_size(2) ~= layout_size(2)
                initial_matrix(:,layout_size(2)+1:end) = [];
            end

            col_names = app.plate_reader_data.plate_layout.Properties.VariableNames;
            col_names(1) = [];
            app.plate_reader_data.formatted_data = initial_matrix;
            app.plate_reader_data.col_names = col_names;
            app.CalculateStandardCurve

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
                    result_layout.volume_for_cs_assay_ul(i) = result_layout.concentration_mg_per_ml(i)*30;
                end

                un_hashcode = unique(result_layout.hashcode);

                var_names = result_layout.Properties.VariableNames;
                var_types = result_layout.Properties.VariableTypes;

                summary_table = table('Size', [0, numel(var_names)], 'VariableNames', var_names, 'VariableTypes', var_types);
                summary_table = removevars(summary_table,'well_no');
                new_var_names = summary_table.Properties.VariableNames;
                new_var_names(strcmp(new_var_names,'concentration_mg_per_ml')) = [];
                new_var_names(strcmp(new_var_names,'volume_for_cs_assay_ul')) = [];

                m = 1;
                for i = 1 : numel(un_hashcode)
                    h_ix = find(strcmp(result_layout.hashcode,un_hashcode{i}))
                    un_specimen = unique(result_layout.specimen_no(h_ix))
                    for j = 1 : numel(un_specimen)
                        s_ix = find(strcmp(result_layout.specimen_no(h_ix),un_specimen{j}))
                        summary_table;
                        for u = 1 : numel(new_var_names)
                            summary_table.(new_var_names{u})(m) = result_layout.(new_var_names{u})(h_ix(s_ix(1)))
                        end
                        summary_table.concentration_mg_per_ml(m) = mean(result_layout.concentration_mg_per_ml(s_ix));
                        summary_table.volume_for_cs_assay_ul(m) = mean(result_layout.volume_for_cs_assay_ul(s_ix));

                        m = m + 1;
                    end
                end
            end

            standard_table = table;

            for i = 1 : size(standard_values,2)
                col_name = sprintf('standard_col_%i',i);
                standard_table.(col_name) = standard_values(:,i);
            end
            result_layout

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

        % Value changed function: DilutionfactorEditField
        function DilutionfactorEditFieldValueChanged(app, event)
            CalculateSampleValues(app)
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create BradfordUIFigure and hide until all components are created
            app.BradfordUIFigure = uifigure('Visible', 'off');
            app.BradfordUIFigure.Position = [100 100 597 479];
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
            app.StandardCurvePanel.Position = [15 248 568 215];

            % Create StandardCurveAxes
            app.StandardCurveAxes = uiaxes(app.StandardCurvePanel);
            xlabel(app.StandardCurveAxes, 'Concentration (ug/ml)')
            ylabel(app.StandardCurveAxes, 'Absorbance')
            zlabel(app.StandardCurveAxes, 'Z')
            app.StandardCurveAxes.Box = 'on';
            app.StandardCurveAxes.Position = [20 5 441 185];

            % Create SlopeEditFieldLabel
            app.SlopeEditFieldLabel = uilabel(app.StandardCurvePanel);
            app.SlopeEditFieldLabel.HorizontalAlignment = 'right';
            app.SlopeEditFieldLabel.Position = [461 151 36 22];
            app.SlopeEditFieldLabel.Text = 'Slope';

            % Create SlopeEditField
            app.SlopeEditField = uieditfield(app.StandardCurvePanel, 'numeric');
            app.SlopeEditField.Editable = 'off';
            app.SlopeEditField.FontSize = 9;
            app.SlopeEditField.Position = [522 151 42 22];

            % Create rvalueEditFieldLabel
            app.rvalueEditFieldLabel = uilabel(app.StandardCurvePanel);
            app.rvalueEditFieldLabel.HorizontalAlignment = 'right';
            app.rvalueEditFieldLabel.Position = [461 87 42 22];
            app.rvalueEditFieldLabel.Text = 'r-value';

            % Create rvalueEditField
            app.rvalueEditField = uieditfield(app.StandardCurvePanel, 'numeric');
            app.rvalueEditField.Editable = 'off';
            app.rvalueEditField.FontSize = 9;
            app.rvalueEditField.Position = [522 86 43 22];

            % Create InterceptEditFieldLabel
            app.InterceptEditFieldLabel = uilabel(app.StandardCurvePanel);
            app.InterceptEditFieldLabel.HorizontalAlignment = 'right';
            app.InterceptEditFieldLabel.Position = [461 120 52 22];
            app.InterceptEditFieldLabel.Text = 'Intercept';

            % Create InterceptEditField
            app.InterceptEditField = uieditfield(app.StandardCurvePanel, 'numeric');
            app.InterceptEditField.Editable = 'off';
            app.InterceptEditField.FontSize = 9;
            app.InterceptEditField.Position = [522 120 42 22];

            % Create SampleValuesPanel
            app.SampleValuesPanel = uipanel(app.BradfordUIFigure);
            app.SampleValuesPanel.Title = 'Sample Values';
            app.SampleValuesPanel.Position = [15 29 568 215];

            % Create SampleValuesAxes
            app.SampleValuesAxes = uiaxes(app.SampleValuesPanel);
            xlabel(app.SampleValuesAxes, 'Concentration (ug/ml)')
            ylabel(app.SampleValuesAxes, 'Absorbance')
            zlabel(app.SampleValuesAxes, 'Z')
            app.SampleValuesAxes.Box = 'on';
            app.SampleValuesAxes.Position = [20 6 441 185];

            % Create DilutionfactorEditFieldLabel
            app.DilutionfactorEditFieldLabel = uilabel(app.SampleValuesPanel);
            app.DilutionfactorEditFieldLabel.HorizontalAlignment = 'center';
            app.DilutionfactorEditFieldLabel.WordWrap = 'on';
            app.DilutionfactorEditFieldLabel.Position = [461 137 42 32];
            app.DilutionfactorEditFieldLabel.Text = 'Dilution factor';

            % Create DilutionfactorEditField
            app.DilutionfactorEditField = uieditfield(app.SampleValuesPanel, 'numeric');
            app.DilutionfactorEditField.ValueChangedFcn = createCallbackFcn(app, @DilutionfactorEditFieldValueChanged, true);
            app.DilutionfactorEditField.Position = [518 142 42 22];
            app.DilutionfactorEditField.Value = 1;

            % Show the figure after all components are created
            app.BradfordUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = Bradford_exported(varargin)

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