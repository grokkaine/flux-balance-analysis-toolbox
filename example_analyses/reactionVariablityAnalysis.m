format long

addpath('helpers');setup;
model = yeastModel();

exchanges       = {'EX_nh4(e)','EX_glc(e)','EX_so4(e)'};

biomassFix      = 0.3;
biomassReaction = 'biomass_SC4_bal';

reactions = singleGeneReactions(model);

% Determine the use of each reaction in each environment
results = struct;
row = 0;
for e = 1:length(exchanges)
  exchange = exchanges(e);

  setups = struct;

  setups(1).model    = fixGrowthOptimiseUptake(model,biomassReaction,exchange,biomassFix);
  setups(1).solution = optimizeCbModel(setups(1).model);
  setups(1).name     = {'optimal'};

  % Increase nutrient uptake by 5% to create suboptimal solution
  setups(2).model    =  changeRxnBounds(setups(1).model,exchange,setups(1).solution.f * 1.05,'b');
  setups(2).solution = optimizeCbModel(setups(2).model);
  setups(2).name     = {'suboptimal'};

  for s = 1:length(setups)
    setup = setups(s);

    for r = 1:length(reactions)

    reaction      = reactions(r);
    reaction_name = model.rxns(reaction);

    row = row + 1;
    results(row).gene        = model.genes(find(model.rxnGeneMat(reaction,:)));
    results(row).reaction    = reaction;
    results(row).environment = exchange;
    results(row).flux        = setup.solution.x(reaction);
    results(row).setup       = setup.name;

    %Skip this reaction if not used
    if setup.solution.x(reaction) == 0
      results(row).type = {'zero flux'};
      continue;
    end

    if setup.solution.x(reaction)^2 == 1000^2
      results(row).type = {'at maximum'};
      continue;
    end

    % Determine variability of this reaction
    temp = changeObjective(setup.model,reaction_name);
    if setup.solution.x(reaction) < 0
      % Find maximum of reaction
      minimumSolution = optimizeCbModel(temp,'max');
    else
      % Find minimum of reaction
      minimumSolution = optimizeCbModel(temp,'min');
    end

    % Skip reaction if it cannot vary in solution space
    % accounting for binary imprecision
    if round(minimumSolution.x(reaction)*10^7) == round(setup.solution.x(reaction)*10^7)
      results(row).type = {'constrained'};
      continue;
    end

    results(row).type = {'variable'};

    end

  end
end

% Print out reaction data
file = 'results/gene_reaction_type.txt';
header = {'gene','environment','type','reaction'};
printLabeledData([[results.gene]',[results.environment]',[results.type]',[results.setup]'],[[results.reaction]',[results.flux]'],false,-1,file,header);
