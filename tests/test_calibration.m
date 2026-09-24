function tests = test_calibration
tests=functiontests(localfunctions);
end

function testInteriorMinimumBothSolvers(testCase)
b=box;
for solver=solverList
    fit=leotherm.fitThermalParameters(@(x)sum((x-[0.4 0.6]).^2),b,struct('starts',2,'solver',solver{1}));
    verifyEqual(testCase,fit.parameters,[0.4 0.6],'AbsTol',1e-4);
    verifyTrue(testCase,fit.converged);
    leotherm.requireCalibrationConvergence(fit);
    verifyFalse(testCase,fit.identifiabilityEstablished);
    verifyNotEmpty(testCase,jsonencode(fit));
end
end

function testBoundaryMinimumBothSolvers(testCase)
b=box;
for solver=solverList
    fit=leotherm.fitThermalParameters(@(x)(x(1)+1)^2+(x(2)-2)^2,b,struct('starts',2,'solver',solver{1}));
    verifyEqual(testCase,fit.parameters,[0 1],'AbsTol',1e-4);
    verifyTrue(testCase,all(fit.nearBound));
    verifyTrue(testCase,fit.converged);
end
end

function testBudgetExhaustionCannotFreeze(testCase)
fit=leotherm.fitThermalParameters(@(x)sum((x-0.9).^2),box, ...
    struct('starts',1,'solver','fminsearch','maximumIterations',1,'maximumEvaluations',3));
verifyFalse(testCase,fit.converged);
verifyError(testCase,@()leotherm.requireCalibrationConvergence(fit),'leotherm:CalibrationNotConverged');
end

function testParameterNonuniquenessIsNotSuccessClaim(testCase)
fit=leotherm.fitThermalParameters(@(x)(sum(x)-1)^2,box, ...
    struct('starts',2,'initialPoints',[0.2 0.8;0.8 0.2]));
verifyTrue(testCase,fit.parameterInstability);
verifyTrue(testCase,fit.parameterStabilityAssessed);
verifyFalse(testCase,fit.identifiabilityEstablished);
end

function testInvalidObjectiveIsNotSilentlyPenalized(testCase)
verifyError(testCase,@()leotherm.fitThermalParameters(@(~)NaN,box), ...
    'leotherm:CalibrationObjective');
end

function testInvalidBoundsAndOptions(testCase)
b=box; b.upper=[1 1 1];
verifyError(testCase,@()leotherm.fitThermalParameters(@sum,b),'leotherm:CalibrationOptions');
verifyError(testCase,@()leotherm.fitThermalParameters(@sum,box,struct('strats',2)), ...
    'leotherm:CalibrationOptions');
end

function testCheckpointRefusesOverwrite(testCase)
prefix=tempname;
cleanup=onCleanup(@()delete([prefix '_start1.mat']));
settings=struct('starts',1);
leotherm.fitThermalParameters(@(x)sum((x-0.5).^2),box,settings,prefix);
verifyError(testCase,@()leotherm.fitThermalParameters(@sum,box,settings,prefix), ...
    'leotherm:CalibrationCheckpoint');
end

function b=box
b.lower=[0 0]; b.upper=[1 1]; b.initial=[0.3 0.3];
end

function values=solverList
values={'fminsearch'};
if exist('fmincon','file')==2 && license('test','Optimization_Toolbox')
    values{end+1}='fmincon';
end
end
