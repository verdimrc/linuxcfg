# Steps to merge from another_repo/branch_x

# A new repo, with some commits.
cd <project_dir>
git init
...
git add
git commit
git remote add origin <url-to-origin>
git push --set-upstream origin master

# Add the other repo as a new remote.
git checkout -b <my-branch>
git remote add <the-other-repo-name> <url-of-the-other-repo>
git remote update

# Now it's time to merge commits from another_repo/branch_x
# See also: https://stackoverflow.com/a/49095833
#
# If you are sure you want to accept all remote changes and
# avoid conflicts (overwrite yours) then you can specify
# -X theirs as option for git merge.
git merge --allow-unrelated-histories <the-other-repo-name>/<their-branch>

# Push merged to my origin.
git push --set-upstream origin <my-branch>

# Optional (which I actually did): remove the-other-repo-name remote
git remote rm <the-other-repo-name>
