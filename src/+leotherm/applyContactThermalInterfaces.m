function [model, contact] = applyContactThermalInterfaces(model, interfaces)
%APPLYCONTACTTHERMALINTERFACES Add conservative contact stiffness to a FEM model.
if ~isstruct(model) || ~isscalar(model) || ~isfield(model,'nodeCount') || ~isfield(model,'stiffnessWK')
    error('leotherm:InvalidContactInterface','model must be an assembled volume thermal model.');
end
if ~isequal(size(model.stiffnessWK),[model.nodeCount model.nodeCount])
    error('leotherm:InvalidContactInterface','model stiffness dimensions do not match nodeCount.');
end
contact = leotherm.assembleContactThermalInterfaces(model.nodeCount, interfaces);
model.stiffnessWK = model.stiffnessWK + contact.stiffnessWK;
model.contactInterfaces = contact.interfaces;
model.contactPairCount = contact.pairCount;
model.contactFormulation = contact.formulation;
end
