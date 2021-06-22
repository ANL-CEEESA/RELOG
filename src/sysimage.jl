using PackageCompiler

using Cbc
using Clp
using Geodesy
using JSON
using JSONSchema
using JuMP
using MathOptInterface
using ProgressBars

pkg = [:Cbc, :Clp, :Geodesy, :JSON, :JSONSchema, :JuMP, :MathOptInterface, :ProgressBars]

@info "Building system image..."
create_sysimage(pkg, sysimage_path = "build/sysimage.so")
