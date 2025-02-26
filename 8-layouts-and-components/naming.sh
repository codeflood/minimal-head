# args: 1 = The index number
function filename_for_index {
    filename=index
    [ $1 -gt 1 ] && filename="${filename}${1}"
    echo "${filename}.html"
}

# args: 1 = The name to format
function url_for_name {
    name=$(echo "$1" | tr [:upper:] [:lower:])
    name=${name//[^a-z0-9_\-]/-}
    echo $name
}
