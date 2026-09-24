function tests = test_contact_interfaces
tests = functiontests(localfunctions);
end

function testPairwiseAssemblyIsSymmetricAndConservative(testCase)
I = struct('leftNodes',[1 2],'rightNodes',[3 4],'conductanceWK',8,'name','panel_joint');
c = leotherm.assembleContactThermalInterfaces(4,I);
verifyEqual(testCase,full(c.stiffnessWK),full(c.stiffnessWK'),'AbsTol',1e-12);
verifyEqual(testCase,full(sum(c.stiffnessWK,2)),zeros(4,1),'AbsTol',1e-12);
verifyEqual(testCase,full(c.conductanceWK),full(c.conductanceWK'),'AbsTol',1e-12);
verifyEqual(testCase,nnz(c.stiffnessWK),12);
L = leotherm.contactHeatLedger(c,[300;300;280;280]);
verifyEqual(testCase,L.interfaces(1).heatFlowW,160,'AbsTol',1e-12);
verifyEqual(testCase,L.totalInternalPowerW,0,'AbsTol',1e-12);
end

function testMatrixConductanceAndDuplicateGuards(testCase)
I = struct('leftNodes',[1 2],'rightNodes',[3 4],'conductanceWK',[1 2;3 4]);
c = leotherm.assembleContactThermalInterfaces(4,I);
verifyEqual(testCase,sum(c.interfaces(1).conductanceWK,'all'),10);
J = [I I];
verifyError(testCase,@() leotherm.assembleContactThermalInterfaces(4,J),'leotherm:DuplicateContactInterface');
I.conductanceWK = -1;
verifyError(testCase,@() leotherm.assembleContactThermalInterfaces(4,I),'leotherm:InvalidContactInterface');
I.conductanceWK = 1; I.leftNodes = [1 1];
verifyError(testCase,@() leotherm.assembleContactThermalInterfaces(4,I),'leotherm:InvalidContactInterface');
end

function testApplyToVolumeModelAndBoundaryExtension(testCase)
model = struct('nodeCount',3,'stiffnessWK',sparse(3,3));
[updated,~] = leotherm.applyContactThermalInterfaces(model,struct('leftNodes',1,'rightNodes',2,'conductanceWK',2));
verifyEqual(testCase,full(updated.stiffnessWK),[2 -2 0;-2 2 0;0 0 0]);
verifyEqual(testCase,updated.contactPairCount,1);
b(1) = struct('type','convection','nodes',[1 2],'conductanceWK',2,'ambientTemperatureK',300,'heatFluxW',[],'temperatureK',[]);
b(2) = struct('type','heatFlux','nodes',3,'conductanceWK',[],'ambientTemperatureK',[],'heatFluxW',5,'temperatureK',[]);
b(3) = struct('type','fixedTemperature','nodes',1,'conductanceWK',[],'ambientTemperatureK',[],'heatFluxW',[],'temperatureK',290);
b = leotherm.assembleThermalBoundaryConditions(3,b);
verifyEqual(testCase,full(b.stiffnessWK),diag([2 2 0]));
verifyEqual(testCase,b.loadW,[600;600;5]);
verifyEqual(testCase,b.fixedTemperature(1).temperatureK,290);
verifyError(testCase,@() leotherm.assembleThermalBoundaryConditions(3,struct('type','radiation','nodes',1)),'leotherm:UnsupportedThermalBoundary');
end
