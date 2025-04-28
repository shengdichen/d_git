$DIR_CONF = "$HOME\.config\git"

function CopyConfig
{
    New-Item $DIR_CONF -ItemType Directory -ErrorAction SilentlyContinue
    Copy-Item ".\conf\*" "$DIR_CONF\." -Recurse -Force
}
CopyConfig
