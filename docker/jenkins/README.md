Commands for building and running Jenkins on private VPS. Allowing *jenkins* user to be added to a different group, if exists, inside container with the same ID as *docker* group on the host. It avoids changing permissions of mounted files.

#### Build command
docker build --pull --build-arg DOCKER_GROUP_ID=`getent group docker | awk -F: '{printf $3}'` -t jenkins .

#### Run command
docker run -d --name jenkins -v /home/wojtek/jenkins/jenkins_home:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock -p 8080:8080 -p 50000:50000 --restart=unless-stopped jenkins

