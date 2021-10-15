using PackageCompiler
using TOML
using Logging

Logging.disable_logging(Logging.Info)

mkpath("build")

printstyled("Generating precompilation statements...\n", color = :light_green)
run(`julia --project=. --trace-compile=build/precompile.jl $ARGS`)

printstyled("Finding dependencies...\n", color = :light_green)
project = TOML.parsefile("Project.toml")
manifest = TOML.parsefile("Manifest.toml")
deps = Symbol[]
for dep in keys(project["deps"])
    if "path" in keys(manifest[dep][1])
        printstyled("    skip $(dep)\n", color = :light_black)
    else
        println("     add $(dep)")
        push!(deps, Symbol(dep))
    end
end

printstyled("Building system image...\n", color = :light_green)
create_sysimage(
    deps,
    precompile_statements_file = "build/precompile.jl",
    sysimage_path = "build/sysimage.so",
)
