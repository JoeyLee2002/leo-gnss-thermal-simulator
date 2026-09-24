function tests = test_external_task
tests = functiontests(localfunctions);
end

function testQuaternionIdentityAndQuarterTurn(testCase)
q = [1 0 0 0; cos(pi/4) 0 0 sin(pi/4)];
f = leotherm.quaternionToBodyAxes(q,'ECI_TO_BODY_WXYZ');
verifyEqual(testCase,squeeze(f(1,:,:)),eye(3),'AbsTol',1e-12);
% Passive ECI-to-body +90 deg yaw maps ECI +X to body -Y.
verifyEqual(testCase,squeeze(f(2,:,:)),[0 1 0;-1 0 0;0 0 1],'AbsTol',1e-12);
end

function testExternalTaskStructureAndAudit(testCase)
s = taskFixture;
[task,report] = leotherm.importExternalTask(s);
verifyEqual(testCase,task.schema,'leotherm.external_task.v1');
verifyEqual(testCase,size(task.trajectory.frameBodyAxesECI),[2 3 3]);
verifyFalse(testCase,report.interpolation);
verifyEqual(testCase,report.synchronization,'exact_epoch_match');
end

function testUnsortedEpochRejected(testCase)
s=taskFixture; s.time.epoch_utc=fliplr(s.time.epoch_utc);
verifyError(testCase,@()leotherm.importExternalTask(s),'leotherm:ExternalTaskTime');
end

function testQuaternionConventionRequired(testCase)
s=taskFixture; s.attitude=rmfield(s.attitude,'convention');
verifyError(testCase,@()leotherm.importExternalTask(s),'leotherm:ExternalTaskAttitude');
end

function s=taskFixture
s.schema='leotherm.external_task.v1';
s.time=struct('system','UTC','elapsed_unit','s','epoch_utc',{{'2024-01-01T00:00:00Z','2024-01-01T00:00:10Z'}},'elapsed_s',[0;10]);
s.orbit=struct('position_m',[7000e3 0 0;6999e3 100e3 0],'velocity_mps',[0 7500 0;-100 7499 0],'sun_position_m',[1.496e11 0 0;1.496e11 0 0]);
s.attitude=struct('representation','quaternion','convention','ECI_TO_BODY_WXYZ','values',[1 0 0 0;1 0 0 0]);
s.telemetry=struct('epoch_utc',{{'2024-01-01T00:00:00Z','2024-01-01T00:00:10Z'}},'temperature_K',[300;301]);
end
