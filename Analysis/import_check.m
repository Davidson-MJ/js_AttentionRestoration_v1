% import check - % Attention RESTORATION


jobs=[];
jobs.import_wrangle=1;
%
jobs.plot_PP_summary=1;


jobs.createGFX_table =0;


cd('/Users/164376/Documents/GitHub/js_AttentionRestoration_v1/Analysis/');
cd('Raw_data')
datadir=pwd;

pfols = dir([pwd filesep 'experiment-data*']);
disp([num2str(length(pfols)) ', datafiles detected'])
%%
if jobs.import_wrangle
%% pseudo code.
% load csv as .mat
% delete unused columns. 

for ippant=1:length(pfols) 

    cd(datadir);
        if ippant <10
            pnum= ['0' num2str(ippant)]; % maintains order 01,02,03...,10..
        else
            pnum = [num2str(ippant)];
        end

%load and delete:
disp(['loading ' pfols(ippant).name]);
mytab=readtable(pfols(ippant).name);
%% delete the bloat columns, single entries we dont need. 
del_columns={'success',...
    'timeout',...
    'failed_images',...
    'failed_video',...
    'failed_audio',...
    'internal_node_id'};

for icol= 1:length(del_columns)

try mytab.([del_columns{icol}])=[];
catch; disp(['no "' del_columns{icol} '" column']);
end
end
% also to make this easy. convert all iscorrect strings into binary.
mytab.is_correctBinary = contains(mytab.is_correct,'true');
mytab= movevars(mytab,'is_correctBinary','After','is_correct');

 
%% seems the conversion to matlab struggles when parsing the JSON strings that
% make the responses to survey data (PRS etc). The data is visible in the
% CSV, but not mytab.

% Read the CSV file using fopen/textscan for more control
fid = fopen(pfols(ippant).name);

% Read header line to get column names
headerLine = fgetl(fid);
headers = textscan(headerLine, '%s', 'Delimiter', ',');
headers = headers{1};

% Find the index of the important columns
responseColIdx = find(contains(headers, 'response'));
taskColIdx = find(contains(headers, 'task'));
attnCheckIdx = find(contains(headers, 'attention'));
% Read the rest of the file as text
data = textscan(fid, '%s', 'Delimiter', '\n');
data = data{1};
fclose(fid);
%% Process Demographic responses:
try pp_age=mytab.participant_age(1);
    pp_gender = mytab.participant_gender(1);
catch %stored in responses (later versions)
        disp('ppant age and gender not recovered');
        pp_age=nan;
        pp_gender={'nan'};
end




%% Process PRS-11 Responses: 
% Initialize variables for PRS fields
prs_fields = {'FA_12', 'FA_7', 'FA_11', 'BA_1', 'BA_5', 'BA_4', 'COH_15rev', 'COH_26', 'newitem', 'FA_10', 'X'};
prs_table = table();
%%
% Initialize output arrays
numRows = length(data);

%%
% Process each data row
imageCounter=1; % increment after each PRS-11 task.
Attncounter= 0; % increment for Attn checks. 
Attnperformance= []; % increment for Attn checks. 
for i = 1:numRows
    % Parse this row (if not empty)
    if isempty(data{i})
        disp(['Skipping empty data entry for row ' num2str(i)]);
    else
        rowData = textscan(data{i}, '%s', 'Delimiter', ',');
        rowData = rowData{1};
        

        % extract the demographics if it didnt already exist.
        if any(contains(rowData,'demographics'))
            
            %% extract data: 
            startQ= find(contains(rowData, 'age')); % first entry
            endQ = find(contains(rowData, 'gender')); % first entry
            for iR = startQ:endQ
        
                %extract the number.
                stringR = rowData{iR};
                %replace double quotes with singles temporarily:
                 str_cleaned = strrep(stringR, '""', '''');
                 % enclose:
                 str_cleaned = strrep(str_cleaned, '''', '"');
                 % Now extract all field-value pairs using regular expressions
                 if contains(str_cleaned, 'gender') 
                     % pattern should search for two strings:
                     pattern = '"([^"]+)":"([^"]+)"';                     

                 elseif contains(str_cleaned, 'age'); 
                     pattern = '{?"([^"]+)":"([^"]+)"';
                 end
                 matches = regexp(str_cleaned, pattern, 'tokens');


                 % Process each match
                 for i = 1:length(matches)
                     field_name = matches{i}{1};   % Field name (e.g., "FA_12")
                     
                     if contains(str_cleaned, 'gender') 
                         value = matches{i}{2};  % string value
                         pp_gender = value;
                     elseif contains(str_cleaned, 'age')
                         value = str2double(matches{i}{2}) ; % Numeric value (e.g., 6)
                         pp_age = value;
                     end
                     


                     % store and score
                     if ischar(value)
                        % For string values, create a string array column
                        prs_table.(field_name) = strings(height(prs_table), 1);
                        prs_table.(field_name){imageCounter}= value;
                     else
                        prs_table.(field_name)(imageCounter)= value;
                         
                     end

                     end
                 

            end % each response... 
        end

        % check if we have attn check on this row: 
        if any(contains(rowData,'attncheck'))
        
            Attncounter=Attncounter+1; 

            % was it correct?
            if contains(rowData{attnCheckIdx}, 'true');
                Attnperformance(Attncounter)= 1;
            else
                Attnperformance(Attncounter)= 0;
            end
            
        end

        % Check if this is PRS-11 row (one per image)
        if  length(rowData)> taskColIdx && any(contains(rowData,'PRS-11'))
            
            % the Q's are always in order, so find the start and end
            % indices of the PRS questions:
            startQ= find(contains(rowData, 'FA_12'));
            endQ= find(contains(rowData, 'X'));

            prs_table.imageID(imageCounter)= imageCounter;

            for iR = startQ:endQ
        
                %extract the number.
                stringR = rowData{iR};
                %replace double quotes with singles temporarily:
                 str_cleaned = strrep(stringR, '""', '''');
                 % enclose:
                 str_cleaned = strrep(str_cleaned, '''', '"');
                 % Now extract all field-value pairs using regular expressions
                 pattern = '"([^"]+)":(\d+)';
                 matches = regexp(str_cleaned, pattern, 'tokens');


                 % Process each match
                 for i = 1:length(matches)
                     field_name = matches{i}{1};   % Field name (e.g., "FA_12")
                     value = str2double(matches{i}{2});  % Numeric value (e.g., 6)

                     fprintf('Field: %s, Value: %d\n', field_name, value);


                     % store and score
                     prs_table.(field_name)(imageCounter)= value;
                 end
                 

            end % each response... 
           
            imageCounter=imageCounter+1;
        end
    end % empty
end

% Create a results table with just the extracted data

% Display the results


%% now do something similar for the rateAI likelihood features:
% here we can just add to the prs_table.

% Process each data row
imageCounter=1; % increment after each PRS-11 task.

for i = 1:numRows
    % Parse this row (if not empty)
    if isempty(data{i})
        disp(['Skipping empty data entry for row ' num2str(i)]);
    else
        rowData = textscan(data{i}, '%s', 'Delimiter', ',');
        rowData = rowData{1};

        % Check if this is PRS-11 row (one per image)
        if  length(rowData)> taskColIdx && any(contains(rowData,'rate-AI'))
            
            % just a single q per image:
            startQ= find(contains(rowData, 'rateAI'));
            
                stringR = rowData{startQ};
                %replace double quotes with singles temporarily:
                 str_cleaned = strrep(stringR, '""', '''');
                 % enclose:
                 str_cleaned = strrep(str_cleaned, '''', '"');
                 % Now extract all field-value pairs using regular expressions
                 pattern = '"([^"]+)":(\d+)';
                 matches = regexp(str_cleaned, pattern, 'tokens');


                 % Process each match
                 for i = 1:length(matches)
                     field_name = matches{i}{1};   % Field name (e.g., "FA_12")
                     value = str2double(matches{i}{2});  % Numeric value (e.g., 6)

                     fprintf('Field: %s, Value: %d\n', field_name, value);


                     % store and score
                     prs_table.(field_name)(imageCounter)= value;
                 end
            
           
            imageCounter=imageCounter+1;
        end
    end % empty
end

disp(prs_table);
%% according to Pasini et al., score as follows: 
% https://doi.org/10.1016/j.sbspro.2014.12.375

% Fascination (FA12, FA7,FA11)
% Being Away (BA1, BA5, BA4)
% Coherence (Coh15rev, COH26, newitem)
% Scope (FA10, X)

for iImg= 1:height(prs_table)

    Fascination = (prs_table.FA_12(iImg) + prs_table.FA_7(iImg)+ prs_table.FA_11(iImg))/3;
    BA = (prs_table.BA_1(iImg) + prs_table.BA_5(iImg) + prs_table.BA_4(iImg))/3;
    Coh = (prs_table.COH_15rev(iImg) + prs_table.COH_26(iImg) + prs_table.newitem(iImg))/3;
    Scope = (prs_table.FA_10(iImg) + prs_table.X(iImg) )/2;

    % add to table:
    prs_table.imageFascination(iImg) = Fascination;
    prs_table.imageBeingAway(iImg) = BA;
    prs_table.imageCoherence(iImg) = Coh;
    prs_table.imageScope(iImg) = Scope;


end

%% SAVE 
        disp('saving grand participant table')...
        % with mytab now clean, lets save for reuse: 
        save(['Participant_' pnum], 'mytab', ...
            'prs_table', ...
            'Attncounter', ...
            'Attnperformance', 'pnum');

%% now for the experiment.
consolidated_rows = contains(mytab.stimulus,'consolidated-trial-data');
ctable = mytab(consolidated_rows,:);

% need to do some reordering. 
% delete the bloat columns, single entries we dont need. 
del_columns={'trial_type',...
    'trial_index',...
    'participant_age',...
    'participant_gender',...
    'rt',...
    'stimulus',...
    'response',...
    'task',...
    'pixels_per_unit',...   
    'is_correct','is_correctBinary','search_difficulty','enhanced','currentSpanLength',...
    'originalDigits','reversedDigits','span_length','correct_digits','digit_accuracy','trial_Type','VISsearch_propcorrect',...
    'VISsearch_meanRT','attention_check_correct','target_button','question_order','image_id','iamge_set'};
for icol= 1:length(del_columns);

try ctable.([del_columns{icol}])=[];
catch; disp(['no "' del_columns{icol} '" column']);
end
end
%tidy the order. 
ctable= movevars(ctable,'block','After',1);
ctable= movevars(ctable,'trial','After',2);
ctable=movevars(ctable,'VisDifficulty','After',3);
ctable=movevars(ctable,'Vis_meanRT','After',4);
ctable=movevars(ctable,'Vis_propCorr','After',5);

% per trial, calculate the difference in DSB performance: 
diffDSBprop = ctable.DSBpost_propcorrect - ctable.DSBpre_propcorrect;
diffDSBdigit = ctable.DSBpost_digitaccuracy - ctable.DSBpre_digitaccuracy;

ctable.DSBdiff_propcorrect = diffDSBprop;
ctable.DSBdiff_digitaccuracy = diffDSBdigit;
%%
% save the ctable as well.
 disp('saving condensed participant table')...
        % with mytab now clean, lets save for reuse: 
        save(['Participant_' pnum], 'ctable', '-append');

    %% also prep a participant data structure for easy ouput later.
    % things we want to save include: 
    % demographics, exp duration, attn check performance. 

    
    % difference in Vis search performance (accuracy, RT).
    % preDSB per image type (0,1,2,3) or AI (0,1), and combination (1-10).
    % postDSB
    % diffDSB
    % and by VS difficulty.


    ParticipantData=[];
    % First, extract demongraphcis and survey responses:
    ParticipantData.pp_Age= pp_age;
    ParticipantData.pp_gender= {pp_gender};

    % how many attn checks?
    ParticipantData.pp_AttnPerformance= mean(Attnperformance);
    ParticipantData.pp_nAttnChecks= length(Attnperformance);
    
    % Next, extract the data from ctable (after practice)
    
    %create trial lists for data aggregation:
    %vis search difficulty
    vs_easy = find(ctable.VisDifficulty==1);
    vs_hard = find(ctable.VisDifficulty==2);
    
    % veg level:
    v_1 = find(ctable.vegetationLevel==1);
    v_2 = find(ctable.vegetationLevel==2);
    v_3 = find(ctable.vegetationLevel==3);
    v_0 = find(isnan(ctable.vegetationLevel));


    % veg level * VS:
    v_1_E = intersect(v_1, vs_easy); % 6 trials.
    v_2_E = intersect(v_2, vs_easy); % 6 trials.
    v_3_E = intersect(v_3, vs_easy); % 6 trials.
    v_0_E = intersect(v_0, vs_easy); % 6 trials.

    v_1_H = intersect(v_1, vs_hard); % 6 trials.
    v_2_H = intersect(v_2, vs_hard); % 6 trials.
    v_3_H = intersect(v_3, vs_hard); % 6 trials.
    v_0_H = intersect(v_0, vs_hard); % 6 trials.


    % %% now the same but by AI (or not)

    r_1 = find(ctable.imageType==1); % REAL
    r_2 = find(ctable.imageType==2); % AI
    r_0 = find(isnan(ctable.imageType)); % fix cross

    % can also do real x VS
    % or real x Veg (underpowered).




    % imgindx
    im_1 = find(ctable.imageIDX==1);
    im_2 = find(ctable.imageIDX==2);
    im_3 = find(ctable.imageIDX==3);
    im_4 = find(ctable.imageIDX==4);
    im_5 = find(ctable.imageIDX==5);
    im_6 = find(ctable.imageIDX==6);
    im_7 = find(ctable.imageIDX==7);
    im_8 = find(ctable.imageIDX==8);
    im_9 = find(ctable.imageIDX==9);
    im_10 = find(ctable.imageIDX==10);
    
    % imgindx X vissearch
    im_1_E = intersect(im_1, vs_easy); % only 2 trials !
    im_2_E = intersect(im_2, vs_easy); % only 2 trials !
    im_3_E = intersect(im_3, vs_easy); % only 2 trials !
    im_4_E = intersect(im_4, vs_easy); % only 2 trials !
    im_5_E = intersect(im_5, vs_easy); % only 2 trials !
    im_6_E = intersect(im_6, vs_easy); % only 2 trials !
    im_7_E = intersect(im_7, vs_easy); % only 2 trials !
    im_8_E = intersect(im_8, vs_easy); % only 2 trials !
    im_9_E = intersect(im_9, vs_easy); % only 2 trials !
    im_10_E = intersect(im_10, vs_easy); % only 2 trials !


    im_1_H = intersect(im_1, vs_hard); % only 2 trials !
    im_2_H = intersect(im_2, vs_hard); % only 2 trials !
    im_3_H = intersect(im_3, vs_hard); % only 2 trials !
    im_4_H = intersect(im_4, vs_hard); % only 2 trials !
    im_5_H = intersect(im_5, vs_hard); % only 2 trials !
    im_6_H = intersect(im_6, vs_hard); % only 2 trials !
    im_7_H = intersect(im_7, vs_hard); % only 2 trials !
    im_8_H = intersect(im_8, vs_hard); % only 2 trials !
    im_9_H = intersect(im_9, vs_hard); % only 2 trials !
    im_10_H = intersect(im_10, vs_hard); % only 2 trials !


    searchList = {vs_easy, vs_hard, ...
        v_1, v_2, v_3, v_0,...
        v_1_E, v_2_E, v_3_E, v_0_E,...
        v_1_H, v_2_H, v_3_H, v_0_H,...
        r_1, r_2, r_0, ...
        im_1,im_2,im_3,im_4,im_5,im_6,im_7,im_8,im_9,im_10,...
        im_1_E,im_2_E,im_3_E,im_4_E,im_5_E,im_6_E,im_7_E,im_8_E,im_9_E,im_10_E,...
        im_1_H,im_2_H,im_3_H,im_4_H,im_5_H,im_6_H,im_7_H,im_8_H,im_9_H,im_10_H};
    %%
    % create descriptors for the field names/ columns. 
    flist ={'vs_easy',...
        'vs_hard',...
        'veg_1','veg_2','veg_3','veg_0',...}
        'veg_1_E','veg_2_E','veg_3_E','veg_0_E',...}
        'veg_1_H','veg_2_H','veg_3_H','veg_0_H',...}
        'imReal',...
        'imAI',...
        'imFix',...
        'imID_1','imID_2','imID_3','imID_4','imID_5',...
        'imID_6','imID_7','imID_8','imID_9','imID_10',...
        'imID_1_E','imID_2_E','imID_3_E','imID_4_E','imID_5_E',...
        'imID_6_E','imID_7_E','imID_8_E','imID_9_E','imID_10_E',...
        'imID_1_H','imID_2_H','imID_3_H','imID_4_H','imID_5_H',...
        'imID_6_H','imID_7_H','imID_8_H','imID_9_H','imID_10_H'};

    for ilist = 1:length(searchList)
        currlist = searchList{ilist};
        currLabel = flist{ilist};

%Grouped by Visual search conditions (easy vs hard)
%Acc and RT
ParticipantData.(['meanVis_Accuracy_' currLabel ]) = nanmean(ctable.Vis_propCorr(currlist));
ParticipantData.(['meanVis_RT_' currLabel ]) = nanmean(ctable.Vis_meanRT(currlist));

%preImage DSB (proportion correct)
ParticipantData.(['preImgDSB_' currLabel]) = nanmean(ctable.DSBpre_propcorrect(currlist));
%preImage DSB (by digits correct)
ParticipantData.(['preImgDSBbydigits_' currLabel])= nanmean(ctable.DSBpre_digitaccuracy(currlist));

%postImage DSB (proportion correct)
ParticipantData.(['postImgDSB_' currLabel]) = nanmean(ctable.DSBpost_propcorrect(currlist));

%postImage DSB (by digits correct)
ParticipantData.(['postImgDSBbydigits_' currLabel])= nanmean(ctable.DSBpost_digitaccuracy(currlist));

%diff in DSB (proportion);
ParticipantData.(['diffImgDSB_' currLabel])= nanmean(ctable.DSBdiff_propcorrect(currlist));

%diff in DSB (by digits).
ParticipantData.(['diffImgDSBbydigits_' currLabel])= nanmean(ctable.DSBdiff_digitaccuracy(currlist));

    end

    % include demographics, attention checks, and survey responses: 
    %%
% save processed data:
    save(['Participant_' pnum], 'ParticipantData', '-append');

end % ippant. 

end % import job.


if jobs.plot_PP_summary
    
%% summary can be a single figure, 
cd(datadir)
ppantfols = dir([pwd filesep 'Participant_*']);
%%

for ippant=1:length(pfols);
cd(datadir)
load(ppantfols(ippant).name);

set(gcf,'color','w', 'units','normalized','position', [0 0 1 1]); clf
shg
%%
% first plot VS split by easy/hard
% use the flist from above.
compareIVs= {[1,2],... % easy vs hard
    [3,4,5,6],... % veg levels 
    [15,16,17],... %imReal,AI, fix }
    [18:27]};%, ...% all im.
    % [20:29], ...% all imE.
    % [30:39]}; % ...% all imH.


for icompare = 1:length(compareIVs);

    fieldindx = compareIVs{icompare};
   
    % reset bar data
    [visAcc, visRT, preDSB, postDSB, diffDSB]= deal([]);

    for ifield = 1:length(fieldindx)
        
        visAcc(ifield) = ParticipantData.(['meanVis_Accuracy_' flist{fieldindx(ifield)}]);
        visRT(ifield) = ParticipantData.(['meanVis_RT_' flist{fieldindx(ifield)}]);
        preDSB(ifield) = ParticipantData.(['preImgDSBbydigits_' flist{fieldindx(ifield)}]);
        postDSB(ifield) = ParticipantData.(['postImgDSBbydigits_' flist{fieldindx(ifield)}]);
        diffDSB(ifield) = ParticipantData.(['diffImgDSBbydigits_' flist{fieldindx(ifield)}]);
    end
% plot! 
subplot(length(compareIVs),5,1+ (5*(icompare-1)));
% yyaxis left 
bar(1:length(fieldindx),visAcc);
ylabel('Prop. Correct');
title('Vis search Accuracy')
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')

subplot(length(compareIVs),5,2+ (5*(icompare-1)));
bar(1:length(fieldindx), visRT);
ylabel('RT (ms)')
title('Vis search RT')
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')
shg

% DSB pre by VS easy/hard (should be balanced), by digits.
subplot(length(compareIVs),5,3+ (5*(icompare-1)))
bar(1:length(fieldindx), preDSB);
ylabel('DSB by digits')
title('Pre-image DSB')
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')
ylim([0 1])

subplot(length(compareIVs),5,4+ (5*(icompare-1)))
bar(1:length(fieldindx), postDSB);
ylabel('DSB by digits')
title('Post-image DSB')
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')
ylim([0 1])

subplot(length(compareIVs),5,5+ (5*(icompare-1)))
bar(1:length(fieldindx), diffDSB);
title('Difference in DSB')
ylabel('\Delta DSB by digits')
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')
ylim([-.5 .5])
end

%%
cd(datadir)
cd ../Figures

print('-dpng', ['Participant_' pnum '_summary'])

end

end



%%
if jobs.createGFX_table
   %% 
   cd(datadir)
    

    ppantfols = dir([pwd filesep 'Participant_*']);
%%
    GFX_table=[];

for ippant=1:length(pfols);
cd(datadir)
load(ppantfols(ippant).name);
%conver tto table and append. 
ptable = struct2table(ParticipantData);

% remove the attn checls
if ippant==1
    GFX_table = ptable;
else
    GFX_table= [GFX_table; ptable];
end

    
end % end ppant

% here also add some ppants (random) based on jitter.
% thinking mean +- SD

nCreate = 10; 
GFX_table_Pseudo = GFX_table;


for idata= 1:nCreate
% take the average of real (per field), and then add some jitter.
    
    pnew= table(); % new per ppant.
    vrnames = ptable.Properties.VariableNames;
    for ifield = 1:length(vrnames);
        if ifield~=2 % avoid the gender column.
        tmpd= nanmean(GFX_table.([vrnames{ifield}]));
        %lowerbound: a
    a = tmpd - 2*nanstd(GFX_table.([vrnames{ifield}]));
    % upper bound: b
    b = tmpd + 2*nanstd(GFX_table.([vrnames{ifield}]));

    %generate singly number between range (a - b)
    % Generate a single random number
    random_value = a + (b-a) * rand();
        else
            random_value = nan;
        end
    % add this jittered value (somewhere within -2SD + 2SD of mean), to
    % table:
    pnew.([vrnames{ifield}]) = random_value;
    
    end

    % now add to GFXtable:
    GFX_table_Pseudo = [GFX_table_Pseudo; pnew];

end

%% export
writetable(GFX_table, 'GFX_table_Pseudo.csv')
writetable(GFX_table, 'GFX_table.csv')
end

if job.plotGFX==1

% plot the current estimate of Group effects, using format above, but adding errorbars.
set(gcf,'color','w', 'units','normalized','position', [0 0 1 1]); clf
shg
%
nppants= height(GFX_table);
% first plot VS split by easy/hard
% use the flist from above.
compareIVs= {[1,2],... % easy vs hard
    [3,4,5,6],... % veg levels 
    [15,16,17],... %imReal,AI, fix }
    [18:27]};%, ...% all im.
    % [20:29], ...% all imE.
    % [30:39]}; % ...% all imH.


for icompare = 1:length(compareIVs);

    fieldindx = compareIVs{icompare};
   
    % reset bar data
    [visAcc, visRT, preDSB, postDSB, diffDSB]= deal([]);

    for ifield = 1:length(fieldindx)
        
        visAcc(ifield,:) = GFX_table.(['meanVis_Accuracy_' flist{fieldindx(ifield)}]);
        visRT(ifield,:) = GFX_table.(['meanVis_RT_' flist{fieldindx(ifield)}]);
        preDSB(ifield,:) = GFX_table.(['preImgDSBbydigits_' flist{fieldindx(ifield)}]);
        postDSB(ifield,:) = GFX_table.(['postImgDSBbydigits_' flist{fieldindx(ifield)}]);
        diffDSB(ifield,:) = GFX_table.(['diffImgDSBbydigits_' flist{fieldindx(ifield)}]);
    end
% plot! 
subplot(length(compareIVs),5,1+ (5*(icompare-1)));
% yyaxis left 
bar(1:length(fieldindx),mean(visAcc,2));
sem= CousineauSEM(visAcc');
hold on;
errorbar(1:length(fieldindx), mean(visAcc,2), sem, 'linewidth',2,'color', 'k','LineStyle', 'none') 
ylabel('Prop. Correct');
title('Vis search Accuracy')
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')
%
subplot(length(compareIVs),5,2+ (5*(icompare-1)));
bar(1:length(fieldindx), mean(visRT,2));
hold on;
sem= CousineauSEM(visRT');
errorbar(1:length(fieldindx), mean(visRT,2), sem, 'linewidth',2,'color', 'k','LineStyle', 'none') 
ylabel('RT (ms)')
title('Vis search RT')
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')
shg

% DSB pre by VS easy/hard (should be balanced), by digits.
subplot(length(compareIVs),5,3+ (5*(icompare-1)))
bar(1:length(fieldindx), mean(preDSB,2));
hold on;
sem= CousineauSEM(preDSB');
errorbar(1:length(fieldindx), mean(preDSB,2), sem, 'linewidth',2,'color', 'k','LineStyle', 'none') 
ylabel('DSB by digits')
title('Pre-image DSB')
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')
ylim([0 1])

subplot(length(compareIVs),5,4+ (5*(icompare-1)))
bar(1:length(fieldindx), mean(postDSB,2));
hold on;
sem= CousineauSEM(postDSB');
errorbar(1:length(fieldindx), mean(postDSB,2), sem, 'linewidth',2,'color', 'k','LineStyle', 'none') 
ylabel('DSB by digits');
title('Post-image DSB');
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')
ylim([0 1])

subplot(length(compareIVs),5,5+ (5*(icompare-1)))
bar(1:length(fieldindx), mean(diffDSB,2));
hold on;
sem= CousineauSEM(diffDSB');
errorbar(1:length(fieldindx), mean(diffDSB,2), sem, 'linewidth',2,'color', 'k','LineStyle', 'none') 
title('Difference in DSB')
ylabel('\Delta DSB by digits')
set(gca,'XTickLabels', flist(fieldindx), 'fontsize', 15, 'TickLabelInterpreter', 'none')
ylim([-.5 .5])
end

%%
cd(datadir)
cd ../Figures

print('-dpng', ['GFX_n=' num2str(nppants) '_summary'])


end