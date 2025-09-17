using Documenter
using RELOG
using BetterFileWatching

function make()
    makedocs(
        sitename="RELOG",
        pages=[
            "Home" => "index.md",
            "User guide" => [
                "problem.md",
                "format.md",
            ]
        ],
        format = Documenter.HTML(
            assets=["assets/custom.css"],
        )
    )
end

function watch()
    make()
    watch_folder("src") do event
        make()
    end
end