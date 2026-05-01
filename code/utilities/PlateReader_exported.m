classdef PlateReader_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        PlateReaderUIFigure        matlab.ui.Figure
        CitrateSynthaseButton      matlab.ui.control.Button
        BradfordAssayButton        matlab.ui.control.Button
        AssayTabs                  matlab.ui.container.TabGroup
        BradfordTab                matlab.ui.container.Tab
        CitrateSynthaseTab         matlab.ui.container.Tab
        SampleValuesPanelCS        matlab.ui.container.Panel
        StandardCurveAxesCS_4      matlab.ui.control.UIAxes
        StandardCurveAxesCS_3      matlab.ui.control.UIAxes
        StandardCurvePanelCS       matlab.ui.container.Panel
        InterceptEditFieldCS       matlab.ui.control.NumericEditField
        InterceptEditField_2Label  matlab.ui.control.Label
        rvalueEditFieldCS          matlab.ui.control.NumericEditField
        rvalueEditField_2Label     matlab.ui.control.Label
        SlopeEditFieldCS           matlab.ui.control.NumericEditField
        SlopeEditField_2Label      matlab.ui.control.Label
        StandardCurveAxesCS_2      matlab.ui.control.UIAxes
        StandardCurveAxesCS        matlab.ui.control.UIAxes
    end


    properties (Access = public)
        plate_reader_data % Description
    end
    
    properties (Access = private)
        BradfordAssay % Description
        CSAssay
    end

    methods (Access = public)

        function CalculateStandardCurveBradford(app)

            col_names = app.plate_reader_data.col_names;
            plate_layout = app.plate_reader_data.plate_layout;
            formatted_data = app.plate_reader_data.formatted_data;
            standard_concentrations = app.plate_reader_data.standard_concentrations.concentration;
            analyzed_data = formatted_data;



            for i = 1 : numel(col_names)
                standard_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Standard');
            end
        
            standard_values = formatted_data(any(standard_mask,2),any(standard_mask,1));

            standard_mean = mean(standard_values,2,'omitnan');

        
            x = standard_concentrations;
            y = standard_mean;

            line_fit = fit_linear_model(x, y);

            hold(app.StandardCurveAxesBradford,"on")
            plot(app.StandardCurveAxesBradford,line_fit.x_fit, line_fit.y_fit, 'LineStyle','-', ...
                'LineWidth', 1.75,'Color',[0 0 0 0.7]);
            scatter(app.StandardCurveAxesBradford,standard_concentrations,standard_mean,50,'MarkerFaceColor','g','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)
            xlim(app.StandardCurveAxesBradford,[0 max(standard_concentrations)])
            ylim(app.StandardCurveAxesBradford,[0 round(max(standard_mean))])

            app.SlopeEditFieldBradford.Value = line_fit.slope;
            app.InterceptEditFieldBradford.Value = line_fit.intercept;
            app.rvalueEditFieldBradford.Value = line_fit.r;


            app.plate_reader_data.standard_curve_fit = line_fit;
            app.plate_reader_data.standard_values = standard_values;
            app.plate_reader_data.standard_mean = standard_mean;
            app.plate_reader_data.analyzed_data = analyzed_data;


            CalculateSampleValues(app)



        end

        function CalculateSampleValues(app)

            col_names = app.plate_reader_data.col_names;
            plate_layout = app.plate_reader_data.plate_layout;
            formatted_data = app.plate_reader_data.formatted_data;
            analyzed_data = app.plate_reader_data.analyzed_data;
            dilution_factor = app.DilutionfactorEditFieldBradford.Value;

            slope = app.plate_reader_data.standard_curve_fit.slope;
            intercept = app.plate_reader_data.standard_curve_fit.intercept;

            for i = 1 : numel(col_names)
                sample_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Sample');
            end

            sample_matrix = formatted_data(any(sample_mask,2),any(sample_mask,1));

            sample_values = dilution_factor*(sample_matrix - intercept)./slope;

            analyzed_data(any(sample_mask,2),any(sample_mask,1)) = sample_values;

            scatter(app.SampleValuesAxesBradford,sample_values,sample_matrix,50,'MarkerFaceColor','b','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)

            app.plate_reader_data.dilution_factor = dilution_factor;
            app.plate_reader_data.sample_values = sample_values;
            app.plate_reader_data.analyzed_data = analyzed_data;
        end

        function RefreshDisplay(app)

            figs = {'StandardCurveAxes','SampleValuesAxes'};
            for i = 1 : numel(figs)
                clf(App.(figs{i}))
            end

            txt = {'Slope','Intercept','rvalue'};

            for i = 1 : numel(txt)
                App.(txt{i}).Value = 0;
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
            app.CalculateStandardCurveBradford



        end

        function ReloadDisplay(app)
            app.plate_reader_data
            line_fit = app.plate_reader_data.standard_curve_fit;
            standard_concentrations = app.plate_reader_data.standard_concentrations.concentration;
            standard_mean = app.plate_reader_data.standard_mean;

            hold(app.StandardCurveAxesBradford,"on")
            plot(app.StandardCurveAxesBradford,line_fit.x_fit, line_fit.y_fit, 'LineStyle','-', ...
                'LineWidth', 1.75,'Color',[0 0 0 0.7]);
            scatter(app.StandardCurveAxesBradford,standard_concentrations,standard_mean,50,'MarkerFaceColor','g','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)
            xlim(app.StandardCurveAxesBradford,[0 max(standard_concentrations)])
            ylim(app.StandardCurveAxesBradford,[0 round(max(standard_mean))])

            app.SlopeEditFieldBradford.Value = line_fit.slope;
            app.InterceptEditFieldBradford.Value = line_fit.intercept;
            app.rvalueEditFieldBradford.Value = line_fit.r;

            col_names = app.plate_reader_data.col_names;
            plate_layout = app.plate_reader_data.plate_layout;
            formatted_data = app.plate_reader_data.formatted_data;
            sample_values = app.plate_reader_data.sample_values;

            for i = 1 : numel(col_names)
                sample_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Sample');
            end

            sample_matrix = formatted_data(any(sample_mask,2),any(sample_mask,1));

            scatter(app.SampleValuesAxesBradford,sample_values,sample_matrix,50,'MarkerFaceColor','b','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)


        end

        function ConvertData(app)
            assay = app.AssayTabs.SelectedTab.Title;
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

            switch assay
                case 'Bradford'
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
                app.CalculateStandardCurveBradford

                case 'Citrate Synthase'
                    time_column = parts(:,1);
                    d_parts = double(parts);
                    d_parts(:,1) = [];
                    app.plate_reader_data.temperature = d_parts(1,1);
                    d_parts(:,1) = [];
                    mat_size = size(d_parts);
                    if mat_size(2) ~= layout_size(2)
                        d_parts(:,layout_size(2)+1:end) = [];
                    end

                    time_points = sum(~strcmp(time_column,""));

                    initial_matrix = nan(layout_size(1),layout_size(2),time_points);

                    for i = 1 : time_points
                        initial_matrix(:,:,i) = d_parts(1+(i-1)*8:i*8,:);
                    end
                    col_names = app.plate_reader_data.plate_layout.Properties.VariableNames;
                    col_names(1) = [];
                    app.plate_reader_data.formatted_data = initial_matrix;
                    app.plate_reader_data.col_names = col_names;
                    app.CalculateStandardCurveCS

            end







        end
        
        function CalculateStandardCurveCS(app)
            col_names = app.plate_reader_data.col_names;
            plate_layout = app.plate_reader_data.plate_layout;
            formatted_data = app.plate_reader_data.formatted_data;
            standard_concentrations = app.plate_reader_data.standard_concentrations.concentration;
            analyzed_data = formatted_data;
            assay = app.AssayTabs.SelectedTab.Title;


            formatted_data_size = size(formatted_data);

            if ndims(formatted_data) > 2
                counter = formatted_data_size(3);
            end


            for i = 1 : numel(col_names)
                standard_mask(:,i) = strcmpi(plate_layout.(col_names{i}),'Standard');
            end
        

            for i = 1 : counter
                time_point_data = []
                time_point_data = formatted_data(:,:,i)
                standard_values = []
                standard_values = formatted_data(any(standard_mask,2),any(standard_mask,1));
                standard_mean(:,i) = mean(standard_values,2,'omitnan');
            end
            standard_mean = mean(standard_mean,2)
            
            


            x = standard_concentrations;
            y = standard_mean;

            line_fit = fit_linear_model(x, y);

            hold(app.StandardCurveAxesCS,"on")
            plot(app.StandardCurveAxesCS,line_fit.x_fit, line_fit.y_fit, 'LineStyle','-', ...
                'LineWidth', 1.75,'Color',[0 0 0 0.7]);
            scatter(app.StandardCurveAxesCS,standard_concentrations,standard_mean,50,'MarkerFaceColor','g','MarkerEdgeColor','k','MarkerFaceAlpha',0.5)
            xlim(app.StandardCurveAxesCS,[0 max(standard_concentrations)])
            ylim(app.StandardCurveAxesCS,[0 round(max(standard_mean))])

            app.SlopeEditFieldBradford.Value = line_fit.slope;
            app.InterceptEditFieldBradford.Value = line_fit.intercept;
            app.rvalueEditFieldBradford.Value = line_fit.r;


            app.plate_reader_data.standard_curve_fit = line_fit;
            app.plate_reader_data.standard_values = standard_values;
            app.plate_reader_data.standard_mean = standard_mean;
            app.plate_reader_data.analyzed_data = analyzed_data;


            CalculateSampleValues(app)
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            addpath(genpath('utilities'))
            movegui(app.PlateReaderUIFigure,'center')
        end

        % Callback function
        function LoadlayoutMenuSelected(app, event)
            app.PlateReaderUIFigure.Visible = 'off';
            [file_string,path_string]=uigetfile2( ...
                {'*.xlsx','XLSX'}, ...
                'Select Layout File');
            app.PlateReaderUIFigure.Visible = 'on';
            figure(app.PlateReaderUIFigure)

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

        % Callback function
        function LoaddataMenuSelected(app, event)
            app.PlateReaderUIFigure.Visible = 'off';

            [file_string,path_string]=uigetfile2( ...
                {'*.txt','TXT'}, ...
                'Select Data File');
            app.PlateReaderUIFigure.Visible = 'on';
            figure(app.PlateReaderUIFigure)

            if (path_string~=0)
                app.plate_reader_data.data_file_string = fullfile(path_string,file_string);
                % app.FormatData;
                app.ConvertData;
            end
        end

        % Callback function
        function ExportanalysisMenuSelected(app, event)
            app.PlateReaderUIFigure.Visible = 'off';
            [file_string,path_string] = uiputfile2( ...
                {'*.xlsx','Excel file'},'Enter Excel File Name For Analysis Results');
            app.PlateReaderUIFigure.Visible = 'on';
            figure(app.PlateReaderUIFigure)

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
                un_specimen = unique(result_layout.specimen_no);

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
                        s_ix = find(strcmp(result_layout(h_ix,:).specimen_no,un_specimen{j}));
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

        % Callback function
        function LoadanalysisMenuSelected(app, event)
            app.PlateReaderUIFigure.Visible = 'off';

            [file_string,path_string]=uigetfile2( ...
                {'*.pr','PR'}, ...
                'Select PlateReader File');
            app.PlateReaderUIFigure.Visible = 'on';
            figure(app.PlateReaderUIFigure)
            if (path_string~=0)
                temp = load(fullfile(path_string,file_string),'-mat','analysis_session');
                analysis_session = temp.analysis_session;
                app.plate_reader_data = [];
                app.plate_reader_data = analysis_session;
                ReloadDisplay(app);
            end

        end

        % Callback function
        function DilutionfactorEditFieldBradfordValueChanged(app, event)
            CalculateSampleValues(app)
        end

        % Button pushed function: BradfordAssayButton
        function BradfordAssayButtonPushed(app, event)
            app.BradfordAssay = Bradford(app);
        end

        % Button pushed function: CitrateSynthaseButton
        function CitrateSynthaseButtonPushed(app, event)
            app.CSAssay = CitrateSynthase(app);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create PlateReaderUIFigure and hide until all components are created
            app.PlateReaderUIFigure = uifigure('Visible', 'off');
            app.PlateReaderUIFigure.Position = [100 100 118 80];
            app.PlateReaderUIFigure.Name = 'PlateReader';

            % Create AssayTabs
            app.AssayTabs = uitabgroup(app.PlateReaderUIFigure);
            app.AssayTabs.Position = [-469 385 954 474];

            % Create BradfordTab
            app.BradfordTab = uitab(app.AssayTabs);
            app.BradfordTab.Title = 'Bradford';

            % Create CitrateSynthaseTab
            app.CitrateSynthaseTab = uitab(app.AssayTabs);
            app.CitrateSynthaseTab.Title = 'Citrate Synthase';

            % Create StandardCurvePanelCS
            app.StandardCurvePanelCS = uipanel(app.CitrateSynthaseTab);
            app.StandardCurvePanelCS.Title = 'Standard Curve';
            app.StandardCurvePanelCS.Position = [10 10 463 428];

            % Create StandardCurveAxesCS
            app.StandardCurveAxesCS = uiaxes(app.StandardCurvePanelCS);
            xlabel(app.StandardCurveAxesCS, 'Concentration (ug/ml)')
            ylabel(app.StandardCurveAxesCS, 'Absorbance')
            zlabel(app.StandardCurveAxesCS, 'Z')
            app.StandardCurveAxesCS.Box = 'on';
            app.StandardCurveAxesCS.Position = [20 218 430 185];

            % Create StandardCurveAxesCS_2
            app.StandardCurveAxesCS_2 = uiaxes(app.StandardCurvePanelCS);
            xlabel(app.StandardCurveAxesCS_2, 'Concentration (ug/ml)')
            ylabel(app.StandardCurveAxesCS_2, 'Absorbance')
            zlabel(app.StandardCurveAxesCS_2, 'Z')
            app.StandardCurveAxesCS_2.Box = 'on';
            app.StandardCurveAxesCS_2.Position = [20 24 317 185];

            % Create SlopeEditField_2Label
            app.SlopeEditField_2Label = uilabel(app.StandardCurvePanelCS);
            app.SlopeEditField_2Label.HorizontalAlignment = 'right';
            app.SlopeEditField_2Label.Position = [348 178 36 22];
            app.SlopeEditField_2Label.Text = 'Slope';

            % Create SlopeEditFieldCS
            app.SlopeEditFieldCS = uieditfield(app.StandardCurvePanelCS, 'numeric');
            app.SlopeEditFieldCS.Editable = 'off';
            app.SlopeEditFieldCS.FontSize = 9;
            app.SlopeEditFieldCS.Position = [409 178 42 22];

            % Create rvalueEditField_2Label
            app.rvalueEditField_2Label = uilabel(app.StandardCurvePanelCS);
            app.rvalueEditField_2Label.HorizontalAlignment = 'right';
            app.rvalueEditField_2Label.Position = [348 114 42 22];
            app.rvalueEditField_2Label.Text = 'r-value';

            % Create rvalueEditFieldCS
            app.rvalueEditFieldCS = uieditfield(app.StandardCurvePanelCS, 'numeric');
            app.rvalueEditFieldCS.Editable = 'off';
            app.rvalueEditFieldCS.FontSize = 9;
            app.rvalueEditFieldCS.Position = [409 113 43 22];

            % Create InterceptEditField_2Label
            app.InterceptEditField_2Label = uilabel(app.StandardCurvePanelCS);
            app.InterceptEditField_2Label.HorizontalAlignment = 'right';
            app.InterceptEditField_2Label.Position = [348 147 52 22];
            app.InterceptEditField_2Label.Text = 'Intercept';

            % Create InterceptEditFieldCS
            app.InterceptEditFieldCS = uieditfield(app.StandardCurvePanelCS, 'numeric');
            app.InterceptEditFieldCS.Editable = 'off';
            app.InterceptEditFieldCS.FontSize = 9;
            app.InterceptEditFieldCS.Position = [409 147 42 22];

            % Create SampleValuesPanelCS
            app.SampleValuesPanelCS = uipanel(app.CitrateSynthaseTab);
            app.SampleValuesPanelCS.Title = 'Sample Values';
            app.SampleValuesPanelCS.Position = [484 10 461 428];

            % Create StandardCurveAxesCS_3
            app.StandardCurveAxesCS_3 = uiaxes(app.SampleValuesPanelCS);
            xlabel(app.StandardCurveAxesCS_3, 'Concentration (ug/ml)')
            ylabel(app.StandardCurveAxesCS_3, 'Absorbance')
            zlabel(app.StandardCurveAxesCS_3, 'Z')
            app.StandardCurveAxesCS_3.Box = 'on';
            app.StandardCurveAxesCS_3.Position = [16 208 430 185];

            % Create StandardCurveAxesCS_4
            app.StandardCurveAxesCS_4 = uiaxes(app.SampleValuesPanelCS);
            xlabel(app.StandardCurveAxesCS_4, 'Concentration (ug/ml)')
            ylabel(app.StandardCurveAxesCS_4, 'Absorbance')
            zlabel(app.StandardCurveAxesCS_4, 'Z')
            app.StandardCurveAxesCS_4.Box = 'on';
            app.StandardCurveAxesCS_4.Position = [16 9 430 185];

            % Create BradfordAssayButton
            app.BradfordAssayButton = uibutton(app.PlateReaderUIFigure, 'push');
            app.BradfordAssayButton.ButtonPushedFcn = createCallbackFcn(app, @BradfordAssayButtonPushed, true);
            app.BradfordAssayButton.Position = [8 51 104 23];
            app.BradfordAssayButton.Text = 'Bradford Assay';

            % Create CitrateSynthaseButton
            app.CitrateSynthaseButton = uibutton(app.PlateReaderUIFigure, 'push');
            app.CitrateSynthaseButton.ButtonPushedFcn = createCallbackFcn(app, @CitrateSynthaseButtonPushed, true);
            app.CitrateSynthaseButton.Position = [8 21 104 23];
            app.CitrateSynthaseButton.Text = 'Citrate Synthase';

            % Show the figure after all components are created
            app.PlateReaderUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = PlateReader_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.PlateReaderUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.PlateReaderUIFigure)
        end
    end
end