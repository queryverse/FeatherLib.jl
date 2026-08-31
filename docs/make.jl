using Documenter, FeatherLib

makedocs(
	modules = [FeatherLib],
	sitename = "FeatherLib.jl",
	format = Documenter.HTML(analytics = "UA-132838790-1"),
	warnonly = [:missing_docs],
	pages = [
        "Introduction" => "index.md"
    ]
)

deploydocs(
    repo = "github.com/queryverse/FeatherLib.jl.git"
)
