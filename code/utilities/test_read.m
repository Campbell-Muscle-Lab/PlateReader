function test_read

txt_file = '../../demo/demo_plate_reader_data.txt'
txt_file = 'CS_6April2026 1.txt'

rawText=fileread(txt_file)
lines = regexp(rawText, '\r\n|\n|\r', 'split')';
lines = string(lines)

idxEnd = find(contains(lines, "~End"), 1);
if isempty(idxEnd)
    idxEnd = numel(lines);
else
    idxEnd = idxEnd - 1;
end
dataRegion = lines(1:idxEnd)

headerIdx = find(contains(dataRegion, "Temperature"), 1)
candidateLines = dataRegion(headerIdx+1:end);
candidateLines = candidateLines(strlength(strtrim(candidateLines)) > 0)

parts = split(candidateLines, sprintf('\t'))
parts(1,1)
strcmp(parts(:,1),"")
% parts(:,1:2) = []

% double(parts)



end

