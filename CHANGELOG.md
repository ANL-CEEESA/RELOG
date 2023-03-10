# Changelog

All notable changes to this project will be documented in this file.

- The format is based on [Keep a Changelog][changelog].
- This project adheres to [Semantic Versioning][semver].
- For versions before 1.0, we follow the [Pkg.jl convention][pkjjl]
  that `0.a.b` is compatible with `0.a.c`.

[changelog]: https://keepachangelog.com/en/1.0.0/
[semver]: https://semver.org/spec/v2.0.0.html
[pkjjl]: https://pkgdocs.julialang.org/v1/compatibility/#compat-pre-1.0

## [0.7.2] -- 2023-03-10

### Fixed

- Core: Fixed modeling issue with collection disposal
- Core: Fix column names in products CSV file

## [0.7.1] -- 2023-03-08

### Added

- Core: Add `write_reports` function

### Changed

- Web UI: Disable usage of heuristic method

### Fixed

- Core: Prevent plants from sending products to themselves
- Core: Enforce constraint that, if plant is closed, storage cannot be used
- Web UI: Fix parsing bug in disposal limit

## [0.7.0] -- 2023-02-23

### Added

- Core: Allow disposal at collection centers
- Core: Allow products to have acquisition costs
- Core: Allow modeling of existing plants
- Web UI: Allow CSV variables and expressions
- Web UI: Allow specifying distance metric

### Changed

- Switch from Cbc/Clp to HiGHS

## [0.6.0] -- 2022-12-15

### Added

- Allow RELOG to calculate approximate driving distances, instead of just straight-line distances between points.

### Fixed

- Fix bug that caused building period parameter to be ignored

## [0.5.2] -- 2022-08-26

### Changed

- Update to JuMP 1.x

## [0.5.1] -- 2021-07-23

### Added

- Allow user to specify locations as unique identifiers, instead of latitude and longitude (e.g. `us-state:IL` or `2018-us-county:17043`)
- Add what-if scenarios.
- Add products report.

## [0.5.0] -- 2021-01-06

### Added

- Allow plants to store input material for processing in later years

## [0.4.0] -- 2020-09-18

### Added

- Generate simplified solution reports (CSV)

## [0.3.3] -- 2020-10-13

### Added

- Add option to write solution to JSON file in RELOG.solve
- Improve error message when instance is infeasible
- Make output file more readable

## [0.3.2] -- 2020-10-07

### Added

- Add "building period" parameter

## [0.3.1] -- 2020-07-17

### Fixed

- Fix expansion cost breakdown

## [0.3.0] -- 2020-06-25

### Added

- Track emissions and energy (transportation and plants)

### Changed

- Minor changes to input file format:
  - Make all dictionary keys lowercase
  - Rename "outputs (tonne)" to "outputs (tonne/tonne)"
