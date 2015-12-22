function results = test(obj)
% Test function
%
% - Does a single processing of an epoch for testing
% - Uses the nnOpts.testFn function for the testing
% - Automatically changes softmaxloss to softmax. Other losses are not yet supported
% TODO: Undo automatic change to softmax

numGpus = numel(obj.nnOpts.gpus);

% % Load correct network (Latest if targetEpoch is not given)
% if nargin == 2
%     modelPath = @(ep) fullfile(obj.nnOpts.expDir, sprintf('net-epoch-%d.mat', ep));
%     if targetEpoch == -1
%         targetEpoch = CalvinNN.findLastCheckpoint(obj.nnOpts.expDir);
%     end
%     [obj.net, obj.stats] = CalvinNN.loadState(modelPath(targetEpoch));    
% end

% Replace softmaxloss layer with softmax layer
softMaxLossIdx = obj.net.getLayerIndex('softmaxloss');
if ~isnan(softMaxLossIdx)
    softmaxlossInput = obj.net.layers(softMaxLossIdx).inputs{1};
    obj.net.removeLayer('softmaxloss');
    obj.net.addLayer('softmax', dagnn.SoftMax(), softmaxlossInput, 'scores', {});
    softmaxIdx = obj.net.layers(obj.net.getLayerIndex('softmax')).outputIndexes;
    assert(numel(softmaxIdx) == 1);
end

% Remove hinge loss layer
hingeLossIdx = obj.net.getLayerIndex('hingeloss');
if ~isnan(hingeLossIdx)
    obj.net.removeLayer('hingeloss');
end

% Set datasetMode in imdb
datasetMode = 'test';
obj.net.mode = datasetMode;            % Disable dropout
obj.imdb.setDatasetMode(datasetMode);
state.epoch = 1;
state.allBatchInds = obj.imdb.getAllBatchInds();

% Process the epoch
if numGpus <= 1
    obj.stats.(datasetMode) = obj.process_epoch(obj.net, state);
else
    % Jasper: Probably the multi-gpu mode does not work because of accumulateStats
    % savedNet = obj.net.saveobj();
    spmd
        net_ = obj.net; % dagnn.DagNN.loadobj(savedNet);
        stats_.(datasetMode) = obj.process_epoch(net_, state);
        % if labindex == 1, savedNet_ = net_.saveobj(); end
    end
    % obj.net = dagnn.DagNN.loadobj(savedNet_{1});
    stats__ = obj.accumulateStats(stats_);
    obj.stats.(datasetMode) = stats__.(datasetMode);
end

% The stats are the desired results 
results = obj.stats.(datasetMode);

end