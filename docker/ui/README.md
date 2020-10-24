Dockerfile from project with custom library in dependencies, requiring repository SSH keys to be added in ssh-agent 

sample build command:
docker build --ssh default --build-arg ENV=$STAGE -t $IMAGE .
