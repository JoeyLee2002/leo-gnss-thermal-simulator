# Thermal model contract v1

`leotherm.model.normalize` converts the existing lumped `network`, optional
surface `geometry`, and optional Gmsh `volumeMesh` into one canonical MATLAB
structure.  The contract is deliberately SI-only so an engineering thermal
model can be attached without hidden scale factors.

```matlab
model = leotherm.model.normalize(network, geometry, volumeMesh);
leotherm.model.validate(model);
```

The top-level schema is `leotherm.thermal_model.v1` and contains:

* `network`: the fields accepted by `leotherm.validateNetwork`, normalized to
  column vectors and an `N`-node conductance graph;
* `geometry`: a validated surface mesh (or an empty structure);
* `volumeMesh`: a validated linear-tetrahedron mesh (or an empty structure);
* `material`: optional positive finite conductivity/density/specific-heat
  values, either scalar/per-tetrahedron or a fully tagged `regionProperties`
  array;
* `units`: explicit canonical units (`m`, `m^2`, `m^3`, `K`, `s`, `W`, `J/K`,
  `W/K`, `W/(m*K)`, `kg/m^3`, and `J/(kg*K)`);
* `connectivity`: network and volume connected-component checks;
* `provenance`: deterministic source/status records for each model component;
* `uncertainty`: a disabled-by-default stratified-uniform uncertainty block.

Inputs with explicit units are accepted only when they declare the canonical
SI unit.  Values are not automatically converted from millimetres, Celsius,
hours, or other unit systems.  Missing units on legacy structures are treated
as inferred SI because the existing field names (`capacityJK`, `nodesM`, etc.)
already encode their units; the inference is recorded in `provenance`.

Validation rejects non-finite values, invalid ranges, repeated mesh nodes,
degenerate tetrahedra/triangles, duplicate facets, asymmetric or negative
conductances, disconnected thermal-network nodes, and disconnected volume
components.  A disconnected geometry is not silently repaired or
interpolated.

For reproducible parameter ensembles:

```matlab
[samples, factors] = leotherm.model.sampleUncertainty(model, 32, 42);
```

`factors` has columns `[capacity conductance power absorptivity emissivity]`;
each is sampled within its declared fractional half-range.  Every sample is a
fully validated model carrying `uncertainty.seed`, `sampleCount`, and a
`stratified_uniform_uncertainty` provenance source.
