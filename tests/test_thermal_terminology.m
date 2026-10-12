function tests=test_thermal_terminology
tests=functiontests(localfunctions);
end

function testLegacyKeysShareNames(testCase)
keys={'rfTemperatureSpanK','orbitalPhaseDelayS','forcingToRfLagS','codeBiasSpanM'};
aliases={'rf_temperature_span_k','orbital_phase_delay_s','forcing_to_rf_lag_s','code_bias_span_m'};
for language={'en','zh'}
    for k=1:numel(keys)
        verifyEqual(testCase,leotherm.thermalMetricLabel(keys{k},language{1}), ...
            leotherm.thermalMetricLabel(aliases{k},language{1}));
    end
end
end

function testPercentileAndRangeAreDistinct(testCase)
[en,definition]=leotherm.thermalMetricLabel('rfTemperatureSpanK','en');
zh=leotherm.thermalMetricLabel('rfTemperatureSpanK','zh');
verifyTrue(testCase,contains(en,'P95-P5') && contains(zh,'P95-P5'));
verifyTrue(testCase,contains(definition,'not maximum minus minimum'));
end

function testTimeIsNotPhaseAngle(testCase)
en=leotherm.thermalMetricLabel('signedPeakPhaseMedianS','en');
verifyTrue(testCase,contains(en,'time difference (s)'));
verifyFalse(testCase,contains(en,'phase (s)'));
end

function testPhaseReferenceIsExplicit(testCase)
[label,definition]=leotherm.thermalMetricLabel('orbitalPhaseDelayS','en');
verifyTrue(testCase,contains(label,'Orbital-frequency phase delay'));
verifyTrue(testCase,contains(definition,'total-absorbed-power'));
verifyTrue(testCase,contains(definition,'not a thermal time constant'));
end

function testUnknownNamesDoNotInventDefinitions(testCase)
[label,definition]=leotherm.thermalMetricLabel('customMetric','en');
verifyEmpty(testCase,label); verifyEmpty(testCase,definition);
end

function testReportDoesNotMutateRawResults(testCase)
s=leotherm.defaultScenario; s.durationS=120; s.timeStepS=60;
s.warmupOrbits=0; s.convergence.enabled=false;
r=leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork); original=r;
d=leotherm.buildThermalReportDetails(struct('scenario',r));
verifyEqual(testCase,r,original);
opt=d(strcmp({d.stage},'heat_inputs'));
verifyTrue(testCase,contains(opt.titleZh,'吸收功率'));
temperature=d(strcmp({d.stage},'temperatures'));
verifyTrue(testCase,contains(strjoin(temperature.linesZh),'温度极差'));
end

function testCenteredRmsIsNamed(testCase)
verifyTrue(testCase,contains(leotherm.thermalMetricLabel('codeBiasRmsM','en'),'Centered'));
end
