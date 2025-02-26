# args: 1 = ProseMirror JSON to transform.
function transform_prosemirror {
    echo $1 | jq -j '
def proc:
    if .type == "paragraph" then
        "<p>", (.content[] | proc), "</p>"
    elif .type == "text" then
        .text
    elif .content != null then
        .content[] | proc
    else
        null
    end
;

proc'
}

# args: 1 = The text to generate the abstract from.
function generate_abstract {
    abstract=$(echo "$1" | sed 's|<[^>]*>||g')
    [ "${#abstract}" -gt 120 ] && abstract="${abstract:0:120}..."
    echo "$abstract"
}