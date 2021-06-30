import httpclient, json

var client = newHttpClient()

proc searchPkg*(query: string): void =
    # TODO: https://nim-lang.org/docs/httpclient.html
    #       https://nim-lang.org/docs/json.html
    # Simple AURweb client
    var res = client.getContent("https://aur.archlinux.org/rpc/?v=5&type=search&arg=" & query)
    var jsonnode = parseJson(res)
    echo jsonnode
    

searchPkg("github")