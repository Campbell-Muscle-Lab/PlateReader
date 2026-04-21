function test_read

txt_file = '../../demo/demo_plate_reader_data.txt'

rawText=fileread(txt_file)
lines = regexp(rawText, '\r\n|\n|\r', 'split')';
lines = string(lines)











end

