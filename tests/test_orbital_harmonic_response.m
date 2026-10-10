function tests=test_orbital_harmonic_response
tests=functiontests(localfunctions);
end

function testKnownDelayWithMultiplePeaksAndTrend(testCase)
p=100; t=(0:0.7:820)'; w=2*pi/p;
x=50+0.01*t+3*cos(w*t)+8*cos(2*w*t)+2*sin(3*w*t);
y=300-0.002*t+2*cos(w*(t-23))+0.6*cos(2*w*(t-7));
h=leotherm.orbitalHarmonicResponse(t,x,y,p);
verifyTrue(testCase,h.available);
verifyEqual(testCase,h.phaseDelayS,23,'AbsTol',1e-9);
verifyEqual(testCase,h.forcingAmplitudeW,3,'AbsTol',1e-10);
verifyLessThan(testCase,h.halfWindowDifferenceS,1e-8);
end

function testAdvanceAndTimeOriginArePreserved(testCase)
t=(0:800)'; x=cos(2*pi*t/100); y=300+cos(2*pi*(t+12)/100);
a=leotherm.orbitalHarmonicResponse(t,x,y,100);
b=leotherm.orbitalHarmonicResponse(t+1e7,x,y,100);
verifyEqual(testCase,a.phaseDelayS,-12,'AbsTol',1e-9);
verifyEqual(testCase,a.phaseDelayS,b.phaseDelayS,'AbsTol',1e-9);
end

function testNoFabricatedDelayForConstantOrMissingFundamental(testCase)
t=(0:800)';
h=leotherm.orbitalHarmonicResponse(t,ones(size(t)),300+cos(2*pi*t/100),100);
verifyFalse(testCase,h.available); verifyTrue(testCase,isnan(h.phaseDelayS));
h=leotherm.orbitalHarmonicResponse(t,cos(4*pi*t/100),300+cos(2*pi*t/100),100);
verifyFalse(testCase,h.available);
end

function testGapsAndShortWindowsDoNotGetFilled(testCase)
t=[(0:100)';(200:800)'];
h=leotherm.orbitalHarmonicResponse(t,cos(t),sin(t),100);
verifyFalse(testCase,h.available);
verifyEqual(testCase,h.status,'sampling_gap_or_low_resolution');
t=(0:50)'; h=leotherm.orbitalHarmonicResponse(t,cos(t),sin(t),100);
verifyFalse(testCase,h.available);
end

function testInvalidDataRaiseSpecificError(testCase)
t=(0:800)'; x=cos(t); x(50)=NaN;
verifyError(testCase,@()leotherm.orbitalHarmonicResponse(t,x,sin(t),100),'leotherm:InvalidPhaseInput');
end

function testSolverAndPhaseMatchAnalyticRCResponse(testCase)
s=leotherm.defaultScenario; n=leotherm.defaultReceiverNetwork;
n.capacityJK(:)=100; n.conductanceWK(:)=0; n.internalPowerW(:)=0;
n.radiatingAreaM2(:)=0; n.initialTemperatureK(:)=300;
p=200; w=2*pi/p; tau=50; delay=atan(w*tau)/w;
amplitude=2.5/sqrt(1+(w*tau)^2);
n.initialTemperatureK(9)=310+amplitude*cos(w*delay);
t=(0:0.5:1600)'; q=zeros(numel(t),11); q(:,9)=20+5*cos(w*t);
f=struct('boundaryTemperatureK',300*ones(numel(t),11), ...
    'boundaryConductanceWK',zeros(numel(t),11));
f.boundaryConductanceWK(:,9)=2;
[T,d]=leotherm.solveThermalNetwork(t,q,n,s.environment,s.integration,f);
exact=310+amplitude*cos(w*(t-delay));
verifyLessThan(testCase,max(abs(T(:,9)-exact)),1e-4);
h=leotherm.orbitalHarmonicResponse(t,q(:,9),T(:,9),p);
verifyTrue(testCase,h.available);
verifyEqual(testCase,h.phaseDelayS,delay,'AbsTol',0.005);
verifyLessThan(testCase,d.maximumEnergyClosureJ,1e-7);
end

function testEngineUsesExplicitHarmonicMetric(testCase)
s=leotherm.defaultScenario; s.durationS=24000; s.timeStepS=120;
s.convergence.enabled=false; s.warmupOrbits=0;
r=leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
h=leotherm.reportHarmonicResponse(r);
verifyEqual(testCase,r.metrics.orbitalPhaseDelayS,h.phaseDelayS,'AbsTol',1e-10);
verifyEqual(testCase,r.metrics.forcingToRfLagS,r.metrics.forcingPeakToResponsePeakLagS);
end
