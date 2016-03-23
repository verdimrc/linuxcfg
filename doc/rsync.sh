REMOTE=user@1.2.3.4:/home/user/src/project
LOCAL=/home/person/src

cd /home/person/src

# local -> remote
rsync -av --delete project user@1.2.3.4:/home/user/src

# remote -> local
rsync -av --delete user@1.2.3.4:/home/user/src/project .

cd -
