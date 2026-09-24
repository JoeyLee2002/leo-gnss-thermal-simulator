# Scoped same-input validation against SATMO

## Purpose

This validation checks whether the nonlinear thermal-network core reproduces
an independent public implementation when both programs receive the same
thermal inputs. It is deliberately narrower than a spacecraft-level thermal
model validation.

## External reference

- Software: SATMO v1.5.0
- Public source: <https://github.com/alexchipps/SATMO>
- Download date: 2026-09-02
- Downloaded ZIP SHA-256:
  `F8FE156112AFDEA91A32F2A1F697AF992E4C2BD2A557CC4C26D1F36C5DC127A5`
- Archived source provenance and comparison settings:
  `studies/softwarex/reference/satmo_same_input_metadata.csv`

SATMO source code is not redistributed. The stored CSV contains only numerical
outputs from the matched case.

## Matched case

Both programs simulate six radiating faces and one isolated internal node for
6000 s with a 1 s step. Every surface node has a heat capacity of 224 J/K, a
radiating/projected area of 0.01 m2, unit solar absorptivity and emissivity,
and 0.5 W internal power. Non-opposite face pairs are connected by 0.12 W/K;
opposite faces are not directly connected. Initial temperature is 293.15 K.

The orbit normal is aligned with the Sun so that beta is 90 deg and eclipse is
absent. Only direct solar heating, conductive coupling, internal power, and
radiation to deep space are compared. Albedo, planetary infrared heating,
eclipse, heaters, and solar panels are disabled.

## Reproduce the comparison

From the repository root in MATLAB R2021b or newer:

```matlab
startup
addpath(fullfile(pwd, 'studies', 'softwarex'))
summary = validate_satmo_reference;
```

The script reads the archived SATMO trace, recomputes the matched trajectory
with this release, and writes results below `results/softwarex_external_validation`.
It does not interpolate either time series.

## Interpretation boundary

The release result is 0--0.003376 K node-wise RMSE and at most 0.008827 K
absolute difference. This verifies the shared thermal core under the matched
case. It does not establish mission-calibrated temperature accuracy or validate
the two programs' different eclipse, albedo, or planetary-infrared models.
