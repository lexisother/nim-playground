import httpclient, json, strutils

var client = newHttpClient()

type
    Package = object
        Name: string
        Description: string

type
    Results = object
        results: seq[Package]

proc searchPkg*(query: string): void =
    var i = 0
    var res = client.getContent("https://aur.archlinux.org/rpc/?v=5&type=search&arg=" & query)
    var packages = to(parseJson(res), Results)
    for pkg in packages.results:
        if i < 5:
            echo pkg.Name
            echo pkg.Description
            echo "\n"
            inc i
        else:
            return
    

searchPkg("github")