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

# args: 1 = Total number of pages.
function substitute_pagers {
    for i in $(seq $1);
    do
        mh_pager=""
        for j in $(seq $1);
        do
            if [ $i -eq $j ]; then
                mh_pager="${mh_pager}<li>${j}</li>"
            else
                filename=$(filename_for_index "$j")
                mh_pager="${mh_pager}<li><a href="${filename}">${j}</a></li>"
            fi
        done

        mh_pager="<ul>${mh_pager}</ul>"
        filename=$(filename_for_index "$i")
        html=$(substitute_placeholders $outDir/${filename})
        echo "${html}" > $outDir/${filename}
    done
}
