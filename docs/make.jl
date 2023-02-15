using Documenter, RELOG

function make()
    makedocs(
        sitename="RELOG",
        pages=[
            "Home" => "index.md",
            "usage.md",
            "format.md",
            "reports.md",
            "model.md",
        ],
        format = Documenter.HTML(
            assets=["assets/custom.css"],
        )
    )
end

make()