import httpclient, json, strformat

var client = newHttpClient()

type
    Package = object
        Name: string
        Description: string
        Version: string
        URL: string
        Maintainer: string

type
    Results = object
        results: seq[Package]

proc searchPkg*(query: string): void =
    var i = 0
    var res = client.getContent("https://aur.archlinux.org/rpc/?v=5&type=search&arg=" & query)
    var packages = to(parseJson(res), Results)
    for pkg in packages.results:
        if i < 5:
            echo &"{pkg.Name} ({pkg.Version})"
            echo pkg.Description
            echo &"Maintained by: {pkg.Maintainer}"
            echo pkg.URL
            echo "\n"
            inc i
        else:
            return
    

when isMainModule:
    import docopt
    
    let doc = """
AURWeb Client

Usage:
    aur search [<query>]
    aur (-h | --help)
    aur (-v | --version)

Options:
    -h --help:      Show this screen.
    -v --version:   Show program version.
    """

    let args = docopt(doc, version = "aur 0.1.0")

    if args["search"]:
        let query = $args["<query>"]

        if query == "nil":
            echo "No query."
        else:
            searchPkg(query)