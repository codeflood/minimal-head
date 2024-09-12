# args: 1 = ProseMirror JSON to transform.
function transform_prosemirror {
    local type=$(echo $1 | jq .type -r)

    case $type in
        
        paragraph)
            echo "<p>"
            process_content "$1"
            echo "</p>"
            ;;
        
        text)
            echo $(echo "$1" | jq .text -r)
            ;;

        *)
            process_content "$1"
            ;;
    esac
}

function process_content {
    echo "$1" | jq .content[] -c | while read -r item
    do
        transform_prosemirror "$item"
    done
}
