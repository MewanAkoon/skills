# Reading every review thread

Read this at pr-feedback's step 1.

`--paginate` reads past 100 threads:

```bash
gh api graphql --paginate -f owner=<owner> -f repo=<repo> -F n=<n> -f query='
query($owner:String!,$repo:String!,$n:Int!,$endCursor:String){repository(owner:$owner,name:$repo){
pullRequest(number:$n){reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor}
nodes{isResolved isOutdated path line
comments(first:100){totalCount nodes{databaseId author{login} body url}}}}}}}'
```

A `totalCount` over 100 means that thread came back cut at 100 comments: say
so in the report.
