function out = fit_linear_model(x,y,varargin);

% Defaults
params.omit_NaNs=1;
params.figure_handle=0;
params.subplot_handle=[];
params.confidence_level=0.95;
params.title_font_size=10;
params.title_rel_y_pos = 1.2;
params.x_fit=linspace(min(x(:)),max(x(:)),100);
params.calculate_confidence_limits=1;

% Update
params=parse_pv_pairs(params,varargin);

% Some error checking and flipping
for i=1:2
    if (i==1)
        temp=x;
    else
        temp=y;
    end
    [r,c]=size(temp);
    if (c>r)
        temp=temp';
    end
    if (i==1)
        x=temp;
    else
        y=temp;
    end
end

if (params.omit_NaNs)
    bi = find(isnan(x)|isnan(y));
    x(bi)=[];
    y(bi)=[];
end

% Code
[b,bint,r,rint,stats]=regress(y,[ones(size(x)) x], ...
    (1-params.confidence_level));

% Calculate stuff about the fit
y_fit = b(2)*params.x_fit' + b(1);
r_matrix = corrcoef(x',y');

% Now get the error on the regression line
% http://mathworks.com/matlabcentral/newsreader/view_thread/309337
if (numel(x)>2)
    [p,s]=polyfit(x,y,1);
    [~,dy]=polyconf(p,params.x_fit,s, ...
        'predopt','curve', ...
        'alpha',1-params.confidence_level);
    y_regression(:,1) = y_fit+dy';
    y_regression(:,2) = y_fit-dy';

    % And errors on where the points lie
    [~,dy]=polyconf(p,params.x_fit,s, ...
        'predopt','observation', ...
        'alpha',1-params.confidence_level);
    y_confidence(:,1) = y_fit+dy';
    y_confidence(:,2) = y_fit-dy';
else
    y_regression(:,1) = NaN*ones(size(x));
    y_regression(:,2) = NaN*ones(size(x));
    y_confidence(:,1) = NaN*ones(size(x));
    y_confidence(:,2) = NaN*ones(size(x));
end

% Store data
out.x=x;
out.y=y;
out.slope=b(2);
out.slope_confidence_limits=bint(2,:);
out.intercept=b(1);
out.intercept_confidence_limits=bint(1,:);
out.x_fit=params.x_fit;
out.y_fit=y_fit;
out.y_confidence=y_confidence;
out.y_regression=y_regression;
out.p=stats(3);
out.r=r_matrix(1,2);
out.title_string=sprintf( ...
        'y = %.5g*x + %.5g\nr=%.5g\np=%.5g', ...
        out.slope,out.intercept,out.r,out.p);


% Display if required
if (params.figure_handle>0)
    figure(params.figure_handle);
    if (isempty(params.subplot_handle))
        clf;
    else
        subplot(params.subplot_handle);
        cla;
    end
    hold on;
    plot(x,y,'bo');
    plot(params.x_fit,y_fit,'r-');
    for i=1:2
        plot(params.x_fit,y_confidence(:,i),'r:');
        plot(params.x_fit,y_regression(:,i),'m:');
    end
    % Display
    x_limits=xlim;
    y_limits=ylim;
    if (params.title_font_size>0)
        text(mean(x_limits), ...
            y_limits(1) + params.title_rel_y_pos * diff(y_limits), ...
            out.title_string, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','top', ...
            'FontSize',params.title_font_size);
    end
end





