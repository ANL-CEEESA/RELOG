# AGENTS.md

## Project

RELOG is a Julia package for supply-chain optimization (forward, reverse, circular manufacturing). It builds and solves mixed-integer linear programs using JuMP.

## Repository layout

- `src/` — Julia package source (module `RELOG`)
  - `instance/` — data structures (`structs.jl`) and JSON parsing (`parse.jl`)
  - `model/` — JuMP model construction (`build.jl`), distance calculations (`dist.jl`), JuMP extensions (`jumpext.jl`)
  - `model/data/` — bundled data files (e.g. `dist_driving.csv`)
  - `reports/` — post-solve report generation (plants, transportation, centers)
  - `transform/` — instance transformations (`reduce.jl`)
- `test/` — separate Julia project (`RELOGT`) with its own `Project.toml` / `Manifest.toml`
  - `test/fixtures/` — JSON test instances and expected-output fixtures
- `docs/` — Documenter.jl documentation

## Julia

- **Julia version**: Manifest targets 1.12.5; CI tests 1.6–1.8.
- **Root environment** (`Project.toml`): the RELOG package itself. No solver — the solver is a test-only dependency.
- **Test environment** (`test/Project.toml`): separate project named `RELOGT` that depends on RELOG, HiGHS (solver), JuliaFormatter, and Test.

### Running tests

Tests use the separate `test/` project. CI runs them with `--project=test`:

```julia
# From repo root in Julia REPL:
julia --project=test

# Then:
using Pkg; Pkg.develop(path=".")
using RELOGT
runtests()
```

The test module `RELOGT` exposes `runtests()` — it does **not** use the standard `test/runtests.jl` convention. Individual test functions (e.g. `model_build_test()`, `model_dist_test()`) can be called directly for focused runs.

### Formatting

- **JuliaFormatter v1** with default settings (no `.JuliaFormatter.toml`).
- CI checks `src/` and `test/src/` — both directories must be formatted.
- To format locally:
  ```julia
  using RELOGT; RELOGT.format()
  ```
  Or directly:
  ```julia
  using JuliaFormatter; format("src"); format("test/src")
  ```

### Architecture notes

- The core pipeline: parse JSON instance → `RELOG.parsefile()` → `RELOG.build_model(instance; optimizer)` → solve via JuMP → generate reports.
- `build_model` returns a JuMP `Model` with named variables/constraints (`y`, `x`, `z_disp`, `z_input`, `z_process`, `z_storage`, `z_exp`, `z_prod`, etc.). Tests assert against exact constraint string representations (`repr()`), so variable/constraint naming matters.
- The RELOG module does **not** depend on any solver; solvers are injected via the `optimizer` kwarg.

## CI

- **test.yml**: runs Julia tests on Ubuntu (Julia 1.6, 1.7, 1.8).
- **lint.yml**: runs JuliaFormatter check on `src/` and `test/src/`.

