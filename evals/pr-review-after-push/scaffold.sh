#!/usr/bin/env bash
# A repo on a pushed feature branch cut from main, with a reviewed change to
# commit and push. The remote is a bare repo outside the working tree.
set -euo pipefail
remote="$(mktemp -d)/remote.git"
git init -q --bare "$remote"
git init -q
git symbolic-ref HEAD refs/heads/main
git config user.name eval
git config user.email eval@example.com
printf '#!/usr/bin/env bash\necho "Hi"\n' > greet.sh
chmod +x greet.sh
git add -A
git commit -qm "add greet.sh"
git remote add origin "$remote"
git push -q -u origin main
git remote set-head origin main
git checkout -q -b feature/greeting
printf 'A greeting script.\n' > README.md
git add README.md
git commit -qm "add README"
git push -q -u origin feature/greeting
printf '#!/usr/bin/env bash\necho "Hello, world"\n' > greet.sh
