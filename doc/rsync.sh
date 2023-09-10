REMOTE=user@1.2.3.4:/home/user/src/project
LOCAL=/home/person/src

cd /home/person/src

# local -> remote
rsync -av --delete project user@1.2.3.4:/home/user/src
# Add --no-perms --no-owner --no-group when remote is an smb mount, otherwise
# rsync won't sync the files with permission operation error.
#
# Only sync a specific file extension. Pay attention to the order.
# https://stackoverflow.com/a/51480550
# --include "*/" --exclude '*/.trashed*' --include '*.mp4' --exclude '*' 'Camera11' $REMOTE

# remote -> local
rsync -av --delete user@1.2.3.4:/home/user/src/project .

cd -

######
# Sync specific files.
# NOTE: rsync_include.txt is a list of files, preferrably sorted to improve performance

# remote -> local for specific files
rsync -av --files-from=rsync_include.txt "$REMOTE" .
