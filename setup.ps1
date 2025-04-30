$DIR_CONF = "$HOME\.config\git"

function CopyConfig
{
    New-Item $DIR_CONF -ItemType Directory -ErrorAction SilentlyContinue
    Copy-Item ".\conf\*" "$DIR_CONF\." -Recurse -Force
}

function MakeId
{
    $id = "id.conf"
    if (Test-Path "$DIR_CONF/$id")
    {
        return
    }
    Copy-Item "./id/default.conf" "$DIR_CONF/$id"
}

CopyConfig
MakeId
