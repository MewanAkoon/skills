#!/usr/bin/env bash
# A repo with one committed script to change.
set -euo pipefail
git init -q
git config user.name eval
git config user.email eval@example.com
printf '#!/usr/bin/env bash\necho "Hi"\n' > greet.sh
chmod +x greet.sh
git add -A
git commit -qm "add greet.sh"
