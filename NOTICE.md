# Attribution and scope

The architecture and validation cases in this repository are informed by:

1. A. Chipps, *SATMO: a Multi-Planet Thermal Analysis Tool for CubeSat
   Missions*, open-source MATLAB software, MIT License,
   https://github.com/alexchipps/SATMO.
2. S. Corpino, M. Caldera, F. Nichele, M. C. Masoero, and N. Viola,
   "Thermal design and analysis of a nanosatellite in low earth orbit,"
   *Acta Astronautica*, vol. 115, pp. 247-261, 2015,
   https://doi.org/10.1016/j.actaastro.2015.05.012.
3. The open-source Basilisk spacecraft simulation framework,
   https://github.com/AVSLab/basilisk, ISC License, for definitions and
   conventions used when checking orbit, attitude, and eclipse geometry.
4. OpenFOAM's documented view-factor radiation model and surface-radiation
   conventions,
   https://www.openfoam.com/documentation/guides/latest/doc/guide-applications-solvers-heat-transfer-cht-radiation-view-factor.html.
5. MOOSE's documented surface-to-surface radiation model and gray-body
   radiosity formulation,
   https://mooseframework.inl.gov/modules/heat_conduction/radiation.html.
6. Gmsh's documented ASCII MSH 2.x node and element format,
   https://gmsh.info/doc/texinfo/gmsh.html#MSH-ASCII-file-format.
7. MOOSE's documented heat-conduction module,
   https://github.com/idaholab/moose/tree/next/modules/heat_conduction.

No SATMO, Basilisk, OpenFOAM or MOOSE source file is redistributed in this
repository. The v0.9.0 face-radiation module is an independent MATLAB
implementation of the documented differential-area/view-factor, reciprocity
and gray-body radiosity ideas. It is intended for reproducible research on
thermal lag in LEO GNSS receiver hardware, not as a replacement for a
certified engineering radiation preprocessor.

The reference receiver network is a physically plausible reduced model, not a
calibrated representation of any specific flight spacecraft. Publication-grade
mission claims require parameter correlation against thermal-vacuum or flight
telemetry data.

The MinXSS deployed-panel study is additionally informed by J. P. Mason,
B. Lamprecht, T. N. Woods and C. Downs, "CubeSat On-Orbit Temperature
Comparison to Thermal-Balance-Tuned-Model Predictions," Journal of
Thermophysics and Heat Transfer (2018), https://doi.org/10.2514/1.T5169,
and the mission-design author manuscript https://arxiv.org/abs/1508.05354.
MinXSS-1 Level 0C telemetry is obtained from NASA SPDF and interpreted using
https://lasp.colorado.edu/minxss/data/level-0c/.

No third-party thermal-model source code or spacecraft CAD model is copied.
The volume module is an independent MATLAB implementation of the standard
linear-tetrahedron Galerkin conduction form and documented Gmsh ASCII MSH 2.x
interchange format, including explicit Physical-Tag material regions; no Gmsh
or MOOSE source code is redistributed.
The v0.10.0 surface-volume coupling, contact-interface and external-task
adapters are likewise independent implementations of the documented
conservative FEM, heat-transfer and input-schema conventions; they do not
redistribute third-party source code.
Approximate areas/capacities and fitted effective parameters in this reduced
network must not be mistaken for a reproduction of the authors' full model.
Downloaded telemetry and papers retain their original providers' terms and
are stored outside the distributable source, under the ignored results tree.
