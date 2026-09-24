function tests = test_material_component_library
tests = functiontests(localfunctions);
end

function testBuiltInMaterialsAreReferenceOnly(testCase)
materials = leotherm.materialLibrary();
verifyGreaterThan(testCase, numel(materials), 0);
for k = 1:numel(materials)
    verifyTrue(testCase, materials(k).isReferenceValue);
    verifyEqual(testCase, materials(k).provenance, 'reference_only');
    verifyNotEmpty(testCase, materials(k).source);
    leotherm.materialLibrary('register', materials(k));
end
end

function testTemperatureDependentMaterialEvaluation(testCase)
material = struct('id','test_curve','name','Test curve','kind','temperature_dependent', ...
    'conductivityWmKFcn', @(T) 2 + 0*T, 'densityKgM3Fcn', @(T) 1000 + 0*T, ...
    'specificHeatJkgKFcn', @(T) 900 + 0*T, 'temperatureRangeK',[200 400], ...
    'source','Synthetic test fixture','confidence','low','uncertainty',struct('relative',0.1));
value = leotherm.materialLibrary('evaluate', material, [250; 300]);
verifyEqual(testCase, value.conductivityWmK, [2; 2]);
verifyEqual(testCase, value.specificHeatJkgK, [900; 900]);
end

function testMaterialRejectsMissingSourceAndNegativeParameter(testCase)
bad = struct('id','bad','name','bad','kind','constant','conductivityWmK',1, ...
    'densityKgM3',1,'specificHeatJkgK',-1,'confidence','low','uncertainty',struct);
verifyError(testCase, @() leotherm.materialLibrary('register', bad), 'leotherm:InvalidMaterial');
end

function testComponentMapsByNodeName(testCase)
network = leotherm.defaultReceiverNetwork;
component = struct('id','payload','name','Payload','nodeName','gnss_rf_frontend', ...
    'material','aluminum_6061','massKg',2,'projectedAreaM2',0.1, ...
    'radiatingAreaM2',0.1,'source','Test fixture source','confidence','medium', ...
    'uncertainty',struct('massKg',0.05));
mapped = leotherm.componentModel(component, network);
verifyEqual(testCase, mapped.nodeIndex, network.roles.response);
verifyEqual(testCase, mapped.nodeName, 'gnss_rf_frontend');
verifyGreaterThan(testCase, mapped.capacityJK, 0);
verifyEqual(testCase, mapped.solarAbsorptivity, 0.15, 'AbsTol', 1e-12);
end

function testComponentRejectsIllegalOpticalRange(testCase)
component = struct('id','x','name','x','nodeIndex',1,'capacityJK',1, ...
    'projectedAreaM2',0,'radiatingAreaM2',0,'internalPowerW',0, ...
    'contactConductanceWK',0,'solarAbsorptivity',1.2,'irEmissivity',0.8, ...
    'source','fixture','confidence','low','uncertainty',struct);
verifyError(testCase, @() leotherm.componentModel(component), 'leotherm:InvalidComponent');
end
