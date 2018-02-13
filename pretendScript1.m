function [out] = messyGaze(eventFilename, gazeFilename, parIndex, settleDur, missingDataDur)

%%%%%%%%%%%%%%%%%%%
%% Set up
%%%%%%%%%%%%%%%%%%%

%prop of datapoints that must be valid to consider trial
propValid = 0.6;

%load event data
fid_event = fopen(eventFilename);
eventData = textscan(fid_event, '%s %f %f %s %f %s %f %s %f %s %f');

%load track data
fid_track = fopen(gazeFilename);
trackData = textscan(fid_track, '%d %d %f %f %f %f %f %f %f %f %d %d %f %f %f %f %f');

fclose('all');

%pull variables from events
event_types = eventData{1}; %strings
trial_indices = nans(length(event_types),1);
for event_num = 1:length(trial_indices)
    trial_indices(event_num) = (event_types{event_num}(1) == 'i'); %find indices of trials (exclude attention getter)
end
trial_indices = logical(trial_indices);
event_types = event_types(find(trial_indices == 1)); %discard null events

%Variables from data
event_time = eventData{2}(trial_indices); %in seconds, w/ decimal
durations = eventData{5}(trial_indices); %in seconds, whole numbers
location = eventData{7}(trial_indices); %in pixels, position of image
gap = eventData{9}(trial_indices); % 0 = gap, 1 = no gap
condition = eventData{11}(trial_indices); %0 = non-social 1 = social

%Hard coded variables
%See Go1.m
%--imgsizex = 200; imgsizey = 200;  %% size of the images
%--peripheralshift = 400;  %% how much the peripheral stimulus is lateralized
screenRes = [1024 768]; %CER 2017 - confirmed
pic_width = 200;%256; %CER 2017 - pixels
pic_halfwidth = pic_width/2; %100; %CER 2017 - shouldn't this be 256?
pic_locs = unique(location); %CER 2017

%pull variables from track - CER 2017 what are these units?  
left_x = trackData{:,3}; %proportion of screen, 0 to 1 (from top left)
left_y = trackData{:,4}; %proportion of screen, 0 to 1 (from top left)
right_x = trackData{:,5}; %proportion of screen, 0 to 1 (from top left)
right_y = trackData{:,6}; %proportion of screen, 0 to 1 (from top left)
track_time = trackData{:,17}; %in seconds, w/ decimal 

%CER 2017 If this is a prop of screen, why is it ever > 1??  
left_x(find(left_x >1)) = NaN; %proportion of screen, 0 to 1 (from top left)
left_y(find(left_y >1)) = NaN; %proportion of screen, 0 to 1 (from top left)
right_x(find(right_x >1)) = NaN; %proportion of screen, 0 to 1 (from top left)
right_y(find(right_y >1)) = NaN; %proportion of screen, 0 to 1 (from top left)

%change gaze coordinate to botoom left to match matlab CER 2017
left_y = 1-left_y;
right_y = 1-right_y;


%average left and right eyes. NOTE: currently treats negative values as bad
left_x(left_x<0) = NaN; right_x(right_x<0) = NaN;
left_y(left_y<0) = NaN; right_y(right_y<0) = NaN;
average_x = nanmean([left_x right_x],2);
average_y = nanmean([left_y right_y],2);
average_x(isnan(average_x)) = -1;
average_y(isnan(average_y)) = -1;


%Define boundaries of the stimuli
%Coded as a proportion of the screen
left_rectxl = pic_locs(1)/screenRes(1) - pic_halfwidth/screenRes(1);
left_rectxr = pic_locs(1)/screenRes(1) + pic_halfwidth/screenRes(1);
right_rectxl = pic_locs(3)/screenRes(1) - pic_halfwidth/screenRes(1);
right_rectxr = pic_locs(3)/screenRes(1) + pic_halfwidth/screenRes(1);
center_rectxl = pic_locs(2)/screenRes(1) - pic_halfwidth/screenRes(1);
center_rectxr = pic_locs(2)/screenRes(1) + pic_halfwidth/screenRes(1);
y_top = screenRes(2)/2/screenRes(2) - pic_halfwidth/screenRes(2);
y_bottom = screenRes(2)/2/screenRes(2) + pic_halfwidth/screenRes(2);

left_rect = [left_rectxl left_rectxr y_top y_bottom];
right_rect = [right_rectxl right_rectxr y_top y_bottom];
center_rect = [center_rectxl center_rectxr y_top y_bottom];

%     figure;
%     scatter(left_rectxl,screenRes(2)); hold on;
%     scatter(left_rectxr,screenRes(2)); hold on;
%     scatter(right_rectxl,screenRes(2)); hold on;
%     scatter(right_rectxr,screenRes(2)); hold on;
%     scatter(center_rectxl,screenRes(2)); hold on;
%     scatter(center_rectxr,screenRes(2)); hold on;

out = nans((length(event_time))/2,13);
    
    for trial = 1:2:length(event_time)
        
        %define empties
        firstlookcenterTime = NaN;
        lastlookcenterTime = NaN;
        firstlookperiphTime = NaN;
        
        %define stimuli
        periphDur = durations(trial+1); %always 3 seconds
        if gap(trial) == 1
            centralDur = 2; %gap
        else
            centralDur = 5; %overlap
        end
        centerStartTime = event_time(trial); %time
        centerEndTime = centerStartTime + centralDur; %time
        peripheralStimStartTime = event_time(trial+1);%time
        peripheralStimEndTime = peripheralStimStartTime + periphDur;
        
        if peripheralStimStartTime >  max(track_time)
            sprintf([num2str(parIndex) ' is missing Gaze Data']);
            out((trial+1)/2,:) = nan(1,13);
            
            continue
        end
        
        %collect x & y position during peripheral stim
        pOnOffIndices = intersect(find(track_time > peripheralStimStartTime), find(track_time < peripheralStimEndTime));
        periph_x = average_x(pOnOffIndices); 
        periph_y = average_y(pOnOffIndices);
        pTime = track_time(pOnOffIndices);
        
        %collect x & y position during central stim
        cOnOffIndices = intersect(find(track_time > centerStartTime), find(track_time < centerEndTime));
        center_x = average_x(cOnOffIndices); 
        center_y = average_y(cOnOffIndices);
        cTime = track_time(cOnOffIndices);
        
        %collect x & y position during both stims
        aOnOffIndices = intersect(find(track_time > centerStartTime), find(track_time < peripheralStimEndTime));
        all_x = average_x(aOnOffIndices); 
        all_y = average_y(aOnOffIndices);
        aTime = track_time(aOnOffIndices);
        
        trialTime = track_time(aOnOffIndices); %cer 2017 
   
        %count bad samples
        sample_quality = mean(all_x == -1); %proportion of samples during stimulus period that were bad
        
        %pic_locs(1) left, pic_locs(2) center, pic_locs(3) right
        if location(trial+1)==pic_locs(1)
            periph_rect = left_rect;
        elseif location(trial+1)==pic_locs(3)
            periph_rect = right_rect;
        end
        
        %% Deal with periph gaze
        %find gazepoint when gaze first landed on the peripheral stimulus
        in_periph = (((periph_x > periph_rect(1))+(periph_x < periph_rect(2))+(periph_y > periph_rect(3))+(periph_y < periph_rect(4)))==4);
        firstlookperiph = find(in_periph,1);
        lastlookperiph = find(in_periph,1,'last');
        
        %cer 2017
        if isempty(firstlookperiph) || firstlookperiph+settleDur > length(in_periph)
            firstlookperiph = NaN;
        elseif mean(in_periph(firstlookperiph:firstlookperiph+settleDur)) < propValid
            firstlookperiph = NaN;
        end
        if firstlookperiph > 0 
            firstlookperiphTime = pTime(firstlookperiph);
        end

        
        if firstlookperiphTime > peripheralStimEndTime || isnan(firstlookperiphTime) || (firstlookperiphTime) < 0
            out((trial+1)/2,:) = nan(1,13); %exit if a peripheral saccade occurs after stim offset
            continue
        end
        
        if max(cTime) > firstlookperiphTime
            stopSearchRowC = find(cTime == firstlookperiphTime); %row where first periph glance
        else
            stopSearchRowC = length(cTime); %row where first periph glance
        end
        stopSearchRowA = find(aTime == firstlookperiphTime); %row where first periph glance

        %% Deal with central gaze
        %define the range where we'll look for gaze departing from center
        aTime = aTime(1:stopSearchRowA);
        all_x = all_x(1:stopSearchRowA);
        all_y = all_y(1:stopSearchRowA);
        
        in_center = (((all_x > center_rect(1))+(all_x < center_rect(2))+...
            (all_y > center_rect(3))+(all_y < center_rect(4)))==4);
        
        firstlookcenter = find(in_center,1);
        lastlookcenter = find(in_center,1,'last'); %-(length(all_x)-length(periph_x));

        if isempty(lastlookcenter) || isempty(firstlookcenter) 
            sprintf([num2str(parIndex) ' has no look center']);
            out((trial+1)/2,:) = nan(1,13);
            continue
        end
        
        rowIndex = 1;
        while rowIndex < length(in_center - 1) && rowIndex < lastlookcenter 
            bin =  lastlookcenter - rowIndex - missingDataDur: lastlookcenter - rowIndex;
            
            if bin(1) <= 0
               firstlookcenter = lastlookcenter - rowIndex;
               break
            end
            
            if nanmean(in_center(bin)) > propValid
                rowIndex = rowIndex + 1;
            else
               firstlookcenter = lastlookcenter - rowIndex;
               break
            end
            
            firstlookcenter = lastlookcenter - rowIndex + 1;
        end
        
        
        if lastlookcenter > 0
            lastlookcenterTime = aTime(lastlookcenter);
            firstlookcenterTime = aTime(firstlookcenter);
        end
        
        if lastlookcenter - firstlookcenter < settleDur || lastlookperiph - firstlookperiph < settleDur
            lastlookcenter  = NaN;
            firstlookcenter  = NaN;
            lastlookcenterTime = NaN;
            firstlookcenterTime = NaN;
            lastlookperiph= NaN;
            firstlookperiph = NaN;
            lastlookperiphTime = NaN;
            firstlookperiphTime = NaN;
        end
        
        firstlookperiphTime = firstlookperiphTime - peripheralStimStartTime;
        lastlookcenterTime = lastlookcenterTime - peripheralStimStartTime;        
        
        
        %% Analyze eye vs. mouth
        load gazepoints.mat
        centralStim = char(event_types(trial));
        periphStim = char(event_types(trial+1));
        
        EyesOverMouth = NaN; onEyes = NaN; onMouth = NaN; onStim = NaN; onFirst = NaN;
        analCenter = 0; %0 means analyze only gazes to periph stim, 1 to central
        if analCenter == 1
            isSoc = max([strfind(centralStim,'face') strfind(centralStim,'body')]); %is the central stim a face?
        else
            isSoc = max([strfind(periphStim,'face') strfind(periphStim,'body')]); %is the periph stim a face?
        end
        
        if ~isempty(isSoc) 

                %find when gaze left the central stimulus
                if analCenter == 1
                    imNum = find(strcmp(gazepoints.imNames, centralStim(8:end)));
                    eyeMouthGazeX = all_x(1:stopSearchRow);
                    eyeMouthGazeY = all_y(1:stopSearchRow); 
                else
                    imNum = find(strcmp(gazepoints.imNames, periphStim(8:end)));
                    eyeMouthGazeX = periph_x;
                    eyeMouthGazeY = periph_y;
                    onStim = in_periph;
                end
                
            if ~isempty(imNum)
                %x and y from top left?
                mouthCenter = gazepoints.mouth(imNum,:); % define center of mouth region for this image
                eyesCenter = gazepoints.eyes(imNum,:); % define center of mouth region for this image

                mouthCenter = mouthCenter*pic_width/256; %mouthCenters were determined assuming a 256 pixel image
                eyesCenter = eyesCenter*pic_width/256;%eyeCenters were determined assuming a 256 pixel image

                mouthCenter(2) = pic_width - mouthCenter(2); %these were coded with yx coordinates = top left
                eyesCenter(2) = pic_width - eyesCenter(2);%these were coded with yx coordinates = top left

                %recode gazepoints in image coords
                eyeMouthGazeX((eyeMouthGazeX)< 0) = NaN;
                eyeMouthGazeY((eyeMouthGazeY)< 0) = NaN;
                
                if analCenter == 1
                    eyeMouthGazeX = eyeMouthGazeX*screenRes(1) - (pic_locs(2) - pic_width/2);
                    eyeMouthGazeY = eyeMouthGazeY*screenRes(2) - (screenRes(2)/2 - pic_width/2);
                    lRectXL = left_rectxl*screenRes(1) - (pic_locs(2) - pic_width/2);
                    lRectXR = left_rectxl*screenRes(1) - (pic_locs(2) - pic_width/2);
                    cRectXL = center_rectxl*screenRes(1) - (pic_locs(2) - pic_width/2);
                    cRectXR = center_rectxr*screenRes(1) - (pic_locs(2) - pic_width/2);
                    rRectXL = right_rectxl*screenRes(1) - (pic_locs(2) - pic_width/2);
                    rRectXR = right_rectxr*screenRes(1) - (pic_locs(2) - pic_width/2);
                elseif periph_rect(1) > 0.5
                    eyeMouthGazeX = eyeMouthGazeX*screenRes(1) - (pic_locs(3) - pic_width/2);
                    eyeMouthGazeY = eyeMouthGazeY*screenRes(2) - (screenRes(2)/2 - pic_width/2);
                    lRectXL = left_rectxl*screenRes(1)  - (pic_locs(3) - pic_width/2);
                    lRectXR = left_rectxl*screenRes(1)  - (pic_locs(3) - pic_width/2);
                    cRectXL = center_rectxl*screenRes(1)  - (pic_locs(3) - pic_width/2);
                    cRectXR = center_rectxr*screenRes(1)  - (pic_locs(3) - pic_width/2);
                    rRectXL = right_rectxl*screenRes(1)  - (pic_locs(3) - pic_width/2);
                    rRectXR = right_rectxr*screenRes(1)  - (pic_locs(3) - pic_width/2);
                    xyLims = [-1000 300 -screenRes(2)/2 screenRes(2)/2+pic_width];
                elseif periph_rect(1) < 0.5
                    eyeMouthGazeX = eyeMouthGazeX*screenRes(1) - (pic_locs(1) - pic_width/2);
                    eyeMouthGazeY = eyeMouthGazeY*screenRes(2) - (screenRes(2)/2 - pic_width/2);
                    lRectXL = left_rectxl*screenRes(1) - (pic_locs(1) - pic_width/2);
                    lRectXR = left_rectxl*screenRes(1)- (pic_locs(1) - pic_width/2);
                    cRectXL = center_rectxl*screenRes(1)- (pic_locs(1) - pic_width/2);
                    cRectXR = center_rectxr*screenRes(1)  - (pic_locs(1) - pic_width/2);
                    rRectXL = right_rectxl*screenRes(1)  - (pic_locs(1) - pic_width/2);
                    rRectXR = right_rectxr*screenRes(1)  - (pic_locs(1) - pic_width/2);
                    xyLims = [-200 1100 -screenRes(2)/2 screenRes(2)/2+pic_width];
                end
                sum(eyeMouthGazeX>0);
                
                
                %circleRadius = [0.04 0.015].*screenRes;
                circleRadius = [0.05 0.02].*screenRes;
                plotGaze = 0;
                if plotGaze == 1
                    
                    colorVec = linspace(1,0, size(eyeMouthGazeX,1));
                    colorVec = transpose(colorVec);
                    colorVec = repmat(colorVec,[1 3]);

                    figure
                    scatter(eyeMouthGazeX(1),eyeMouthGazeY(1),150,'b','filled'); hold on; %first saccade
                    scatter(eyeMouthGazeX,eyeMouthGazeY,'CData', colorVec); hold on;
                    rectangle('Position',[0 0 200 200],'LineWidth',2)
                    [xMouth,yMouth] = circle(mouthCenter(1),mouthCenter(2),circleRadius(1),circleRadius(2));
                    [xEyes,yEyes] = circle(eyesCenter(1),eyesCenter(2),circleRadius(1),circleRadius(2));
                    rectangle('Position',[lRectXL 0 200 200])
                    rectangle('Position',[cRectXL 0 200 200])
                    rectangle('Position',[rRectXL 0 200 200])
                    axis(xyLims);
                    
                else
                    figure(999);
                    [xMouth,yMouth] = circle(mouthCenter(1),mouthCenter(2),circleRadius(1),circleRadius(2));
                    [xEyes,yEyes] = circle(eyesCenter(1),eyesCenter(2),circleRadius(1),circleRadius(2));
                    close(999);
                end
                
                onMouth = sum(inpolygon(eyeMouthGazeX, eyeMouthGazeY, xMouth, yMouth));
                onEyes = sum(inpolygon(eyeMouthGazeX, eyeMouthGazeY, xEyes, yEyes));
                onStim = sum(onStim);
                
                a = min(find((inpolygon(eyeMouthGazeX, eyeMouthGazeY, xMouth, yMouth))));
                b = min(find(inpolygon(eyeMouthGazeX, eyeMouthGazeY, xEyes, yEyes)));
                onFirst = NaN;
                if a < b
                    onFirst = -1;
                elseif a > b
                    onFirst = 1;
                end
                
                [onEyes onMouth onStim];
                %pause(1)
                plotFace = 0;  
                if randi(40) == 5
                    plotFace = 1;
                end
                if plotFace == 1
                    figure
                    if analCenter == 1
                        imFile = ['~/Dropbox/Projects/Dynamic-Disengagement/Bkup/Jasons-Scripts/' centralStim];
                    else
                        imFile = ['~/Dropbox/Projects/Dynamic-Disengagement/Bkup/Jasons-Scripts/' periphStim];
                    end
                    axis ij
                    imshow(imFile) %pic_width x pic_width x 3
                    axis on
                    set(gca, 'Ydir', 'reverse');
                    hold on
                    %scatter(1,1,'filled')
                    scatter(eyeMouthGazeX,pic_width-eyeMouthGazeY) %have to flip y axis once more
                    hold on
                    
                    circle(mouthCenter(1),pic_width-mouthCenter(2),circleRadius(1),circleRadius(2));
                    circle(eyesCenter(1),pic_width-eyesCenter(2),circleRadius(1),circleRadius(2));
                    
                    hold off
                end

                
                if onMouth == 0
                    onMouth = 0.000001;
                end
                if onEyes == 0
                    onEyes = 0.000001;
                end
                
                onEyes = onEyes/onStim; %make a percentage of stim time
                onMouth = onMouth/onStim; %make a percentage of stim time
                
                EyesOverMouth = (onEyes)/(onMouth);

            end
        end
        
        [firstlookcenterTime lastlookcenterTime firstlookperiphTime];

        numReturnSaccades = NaN;
        
        out((trial+1)/2,:) = [durations(trial) gap(trial) condition(trial) condition(trial+1) firstlookperiphTime lastlookcenterTime sample_quality location(trial+1) numReturnSaccades onEyes onMouth EyesOverMouth onFirst];
    
    clear *Time *look* periph_rect A  on* EyesOverMouth 
    
    end %end trial loop
    

end %end main function


        
