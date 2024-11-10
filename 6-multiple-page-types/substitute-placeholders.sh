# args: 1 = Template file to perform substitution over.
function substitute_placeholders {
    local content=$(cat $1)

    for name in ${!mh_*}
    do
        local field_name=${name//mh_/}
        content="${content//"[[$field_name]]"/"${!name}"}"
    done

    echo "$content"
}