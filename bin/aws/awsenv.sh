#!/bin/bash

for i in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN; do
    echo $i=${!i}
done

[ "$AWS_SESSION_TOKEN" != "$AWS_SECURITY_TOKEN" ] && \
echo -e \
'################################################\n'\
'WARNING: AWS_SECURITY_TOKEN != AWS_SESSION_TOKEN\n'\
'################################################\n'\
"AWS_SECURITY_TOKEN=$AWS_SECURITY_TOKEN"
