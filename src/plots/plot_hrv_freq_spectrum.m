function [] = plot_hrv_freq_spectrum( ax, plot_data, varargin )
%PLOT_HRV_FREQ_SPECTRUM Plots the spectrums generated by hrv_freq.
%   ax: axes handle to plot to.
%   plot_data: struct returned from hrv_freq.
%

%% Input
SUPPORTED_METHODS = {'Lomb', 'AR', 'Welch', 'FFT'};

p = inputParser;
p.addRequired('ax', @(x) isgraphics(x, 'axes'));
p.addRequired('plot_data', @isstruct);
p.addParameter('clear', false, @islogical);
p.addParameter('tag', default_axes_tag(mfilename), @ischar);
p.addParameter('xscale', 'linear', @(x)strcmpi(x,'log')||strcmpi(x,'linear'));
p.addParameter('yscale', 'linear', @(x)strcmpi(x,'log')||strcmpi(x,'linear'));
p.addParameter('ylim', 'auto');
p.addParameter('peaks', false);
p.addParameter('detailed_legend', true);
p.addParameter('methods', SUPPORTED_METHODS, @(x) cellfun(@(m) any(cellfun(@(ms) strcmp(m,ms), SUPPORTED_METHODS)), x));
p.addParameter('normalize', false);

p.parse(ax, plot_data, varargin{:});
clear = p.Results.clear;
tag = p.Results.tag;
xscale = p.Results.xscale;
yscale = p.Results.yscale;
yrange = p.Results.ylim;
plot_peaks = p.Results.peaks;
detailed_legend = p.Results.detailed_legend;
methods = p.Results.methods;
normalize = p.Results.normalize;

f_axis          = plot_data.f_axis;
vlf_band        = plot_data.vlf_band;
lf_band         = plot_data.lf_band;
hf_band         = plot_data.hf_band;
f_max           = plot_data.f_max;
t_win           = plot_data.t_win;
welch_overlap   = plot_data.welch_overlap;
ar_order        = plot_data.ar_order;
num_windows     = plot_data.num_windows;
lf_peak         = plot_data.lf_peaks(1);
hf_peak         = plot_data.hf_peaks(1);

%% Plot
if clear
    cla(ax);
end

colors = lines(length(SUPPORTED_METHODS));

% Check for pre-existing plots frequency plots on this axes
legend_handles = findall(ax,'Tag','freq');
legend_entries = {};
if ~isempty(legend_handles)
    legend_entries = {legend_handles.DisplayName};
    colors = colors((length(legend_handles)+1):end,:);
end

hold(ax, 'on');
% Plot PSDs
for ii = 1:length(methods)
    curr_pxx_type = ['pxx_' lower(methods{ii})];

    % Skip this power method if it wasn't calculated or if it wasn't requested for plotting
    if isempty(plot_data.(curr_pxx_type)) || ~any(cellfun(@(m) strcmp(methods{ii}, m), methods))
        continue;
    end

    % Get PSD and normalize if requested
    pxx = plot_data.(curr_pxx_type);
    if normalize
        total_power = freqband_power(pxx, f_axis, [min(f_axis), max(f_axis)]);
        pxx = pxx ./ total_power;
        pxx = pxx ./ max(pxx);
    end

    % Plot PSD
    hp = plot(ax, f_axis, pxx, 'Color', colors(ii,:), 'LineWidth', 1.5, 'Tag', 'freq');

    % Save handle
    legend_handles(end+1) = hp;
    
    % Create legend label
    if detailed_legend
        switch lower(methods{ii})
            case {'fft', 'lomb'}
                legend_entries{end+1} = sprintf('%s (t_{win}=%.1fm, n=%d)', methods{ii}, t_win/60, num_windows);
            case 'welch'
                legend_entries{end+1} = sprintf('%s (%d%%)', methods{ii}, welch_overlap);
            case 'ar'
                legend_entries{end+1} = sprintf('%s (%d)', methods{ii}, ar_order);
        end
    else
        legend_entries{end+1} = methods{ii};
    end
end

% Remove legend entries for unused methods
skipped_idx = find(legend_handles == 0);
legend_handles(skipped_idx) = [];
legend_entries(skipped_idx) = [];

% Peaks
if plot_peaks && ~isnan(lf_peak)
    hp = plot(ax, lf_peak, pxx(f_axis==lf_peak).*1.25, 'bv', 'MarkerSize', 8, 'MarkerFaceColor', 'blue');
    legend_handles(end+1) = hp;
    legend_entries{end+1} = sprintf('%.3f Hz', lf_peak);
end
if plot_peaks && ~isnan(hf_peak)
    hp = plot(ax, hf_peak, pxx(f_axis==hf_peak).*1.25, 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'red');
    legend_handles(end+1) = hp;
    legend_entries{end+1} = sprintf('%.3f Hz', hf_peak);
end

% Set axes scales (linear/log)
set(ax, 'XScale', xscale, 'YScale', yscale);
grid(ax, 'on');
axis(ax, 'tight');

% Axes limits
xrange = [0,f_max*1.01];
xlim(ax, xrange);
ylim(ax, yrange);
yrange = ylim(ax); % in case it was 'auto'

if isempty(findall(ax,'Tag','freqband'))
    % Vertical lines of frequency ranges
    lw = 3; ls = ':'; lc = 'black';
    line(vlf_band(1) * ones(1,2), yrange, 'Parent', ax, 'LineStyle', ls, 'Color', lc, 'LineWidth', lw, 'Tag', 'freqband');
    line(lf_band(1)  * ones(1,2), yrange, 'Parent', ax, 'LineStyle', ls, 'Color', lc, 'LineWidth', lw, 'Tag', 'freqband');
    line(hf_band(1)  * ones(1,2), yrange, 'Parent', ax, 'LineStyle', ls, 'Color', lc, 'LineWidth', lw, 'Tag', 'freqband');
    line(hf_band(2)  * ones(1,2), yrange, 'Parent', ax, 'LineStyle', ls, 'Color', lc, 'LineWidth', lw, 'Tag', 'freqband');

    % Names of frequency ranges
    text(vlf_band(1), yrange(2) * 0.9, ' VLF', 'Parent', ax);
    text( lf_band(1), yrange(2) * 0.9,  ' LF', 'Parent', ax);
    text( hf_band(1), yrange(2) * 0.9,  ' HF', 'Parent', ax);
end

%% Legend
legend(ax, legend_handles, legend_entries);

%% Labels
% X
if strcmpi(xscale, 'linear')
    xlabel(ax, 'Frequency [Hz]');
else
    xlabel(ax, 'Log Frequency [Hz]');
end

% Y
if normalize
    ylabel_prefix = 'Normalized';
    ylabel_units = 'n.u.';
else
    ylabel_prefix = '';
    ylabel_units = 's^2/Hz';
end
if strcmpi(yscale, 'log')
    ylabel_prefix = ['Log ' ylabel_prefix];
end

ylabel(ax, sprintf('%s Power Spectral Density [%s]', ylabel_prefix, ylabel_units));


%% Tag
ax.Tag = tag;

end

