# Changelog

All notable changes to this project will be documented in this file.

- The format is based on [Keep a Changelog][changelog].
- This project adheres to [Semantic Versioning][semver].
- For versions before 1.0, we follow the [Pkg.jl convention][pkjjl]
  that `0.a.b` is compatible with `0.a.c`.

[changelog]: https://keepachangelog.com/en/1.0.0/
[semver]: https://semver.org/spec/v2.0.0.html
[pkjjl]: https://pkgdocs.julialang.org/v1/compatibility/#compat-pre-1.0

## [0.5.1] -- 2021-07-21
## Added
- Allow user to specify locations as unique identifiers, instead of latitude and longitude (e.g. `us-state:IL` or `2018-us-county:17043`)
- Add products report.

## [0.5.0] -- 2021-01-06
## Added
- Allow plants to store input material for processing in later years

## [0.4.0] -- 2020-09-18
## Added
- Generate simplified solution reports (CSV)

## [0.3.3] -- 2020-10-13
## Added
- Add option to write solution to JSON file in RELOG.solve
- Improve error message when instance is infeasible
- Make output file more readable

## [0.3.2] -- 2020-10-07
## Added
- Add "building period" parameter

## [0.3.1] -- 2020-07-17
## Fixed
- Fix expansion cost breakdown

## [0.3.0] -- 2020-06-25
## Added
- Track emissions and energy (transportation and plants)

## Changed
- Minor changes to input file format:
    - Make all dictionary keys lowercase
    - Rename "outputs (tonne)" to "outputs (tonne/tonne)"
