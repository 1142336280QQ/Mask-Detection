gTruth.imageFilename = fullfile(pwd, gTruth.imageFilename);
% Read one of the images.
I = imread(gTruth.imageFilename{10});
% Insert the ROI labels.
I = insertShape(I, 'Rectangle', gTruth.Mask{10});
% Resize and display image.
I = imresize(I,3);
figure
imshow(I)
% 将数据集分成两部分：一个是用于训练检测器的训练集，一个是用于评估检测器的测试集。
% 选择 60% 的数据进行训练。其余数据用于评估。
% Set random seed to ensure example training reproducibility.
rng(0);
% Randomly split data into a training and test set.
shuffledIndices = randperm(height(gTruth));
idx = floor(0.9 * length(shuffledIndices) );
trainingData = gTruth(shuffledIndices(1:idx),:);
testData = gTruth(shuffledIndices(idx+1:end),:);

%% Define the image input size.
imageSize = [448 448 3];
% Define the number of object classes to detect.
numClasses = width(gTruth)-1;
anchorBoxes = [
    43 59
    18 22
    23 29
    84 109
];
% Load a pretrained ResNet-50.
baseNetwork = resnet50();
% Specify the feature extraction layer.
featureLayer = 'activation_40_relu';
% Create the YOLO v2 object detection network. 
lgraph = yolov2Layers(imageSize,numClasses,anchorBoxes,baseNetwork,featureLayer);

options = trainingOptions('sgdm', ...
        'MiniBatchSize', 8, ....
        'InitialLearnRate',1e-3, ...
        'MaxEpochs',10,...
        'CheckpointPath', tempdir, ...
        'Shuffle','every-epoch',...
        'Plots','training-progress');      
% Train YOLO v2 detector.
 [detector, info] = trainYOLOv2ObjectDetector(gTruth,lgraph,options);    
% 单幅图像检测
% Read a test image
tic;
I = imread(testData.imageFilename{end});
% Run the detector.
I = imread('F:\dataset\258.png');
[bboxes, scores] = detect(detector, I);
% Annotate detections in the image.
I = insertObjectAnnotation(I, 'rectangle', bboxes, scores);
toc;
figure
imshow(I)
%% 使用测试集评估检测器
% Create a table to hold the bounding boxes, scores, and labels output by
% the detector. 
numImages = height(testData);
results = table('Size',[numImages 3],...
    'VariableTypes',{'cell','cell','cell'},...
    'VariableNames',{'Boxes','Scores','Labels'});
% Run detector on each image in the test set and collect results.
for i = 1:numImages
    % Read the image.
    I = imread(testData.imageFilename{i});
    % Run the detector.
    [bboxes, scores, labels] = detect(detector, I);
    % Collect the results.
    results.Boxes{i} = bboxes;
    results.Scores{i} = scores;
    results.Labels{i} = labels;
end
% Extract expected bounding box locations from test data.
expectedResults = testData(:, 2:end);
% Evaluate the object detector using average precision metric.
[ap, recall, precision] = evaluateDetectionPrecision(results, expectedResults);
% Plot precision/recall curve
figure
plot(recall, precision)
xlabel('Recall')
ylabel('Precision')
grid on
title(sprintf('Average Precision = %.2f', ap))
% Display first few rows of the data set.
MaskDataset(1:4,:)


