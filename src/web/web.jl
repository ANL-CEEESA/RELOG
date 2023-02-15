import HTTP
import JSON
using Random

const ROUTER = HTTP.Router()
const PROJECT_DIR = joinpath(dirname(@__FILE__), "..", "..")
const STATIC_DIR = joinpath(PROJECT_DIR, "relog-web", "build", "static")
const JOBS_DIR = joinpath(PROJECT_DIR, "jobs")

function serve_file(req::HTTP.Request, filename)
    if isfile(filename)
        open(filename) do file
            return HTTP.Response(200, read(file))
        end
    else
        return HTTP.Response(404)
    end
end

function submit(req::HTTP.Request)
    # Generate random job id
    job_id = lowercase(randstring(12))

    # Create job folder
    job_path = joinpath(JOBS_DIR, job_id)
    mkpath(job_path)

    # Write JSON file
    case = JSON.parse(String(req.body))
    open(joinpath(job_path, "case.json"), "w") do file
        JSON.print(file, case)
    end

    # Run job
    run(
        `bash -c "(julia --project=$PROJECT_DIR $PROJECT_DIR/src/web/run.jl $job_path 2>&1 | tee $job_path/solve.log) >/dev/null 2>&1 &"`,
    )

    response = Dict("job_id" => job_id)
    return HTTP.Response(200, body = JSON.json(response))
end

function get_index(req::HTTP.Request)
    return serve_file(req, joinpath(STATIC_DIR, "..", "index.html"))
end

function get_static(req::HTTP.Request)
    return serve_file(req, joinpath(STATIC_DIR, req.target[9:end]))
end

function get_jobs(req::HTTP.Request)
    return serve_file(req, joinpath(JOBS_DIR, req.target[7:end]))
end

HTTP.@register(ROUTER, "GET", "/static", get_static)
HTTP.@register(ROUTER, "GET", "/jobs", get_jobs)
HTTP.@register(ROUTER, "POST", "/submit", submit)
HTTP.@register(ROUTER, "GET", "/", get_index)

function web(host = "127.0.0.1", port = 8080)
    @info "Launching web interface: http://$(host):$(port)/"
    Base.exit_on_sigint(false)
    HTTP.serve(ROUTER, host, port)
    Base.exit_on_sigint(true)
end
