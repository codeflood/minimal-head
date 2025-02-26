# args:
#   1 = GraphQL query
#   2 = End cursor
function execute_graphql {
    page_data=$(\
        curl -X POST https://edge.sitecorecloud.io/api/graphql/v1 \
            -H "Content-Type: application/json" \
            -H "X-GQL-Token: ${API_TOKEN}" \
            -d "{\"query\":\"$1\",\"variables\":{\"cursor\":\"$2\"}}" \
            --fail-with-body
    )

    echo "${page_data}"
}
