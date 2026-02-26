## this is the dockerfile for every container except datebase
- ![](img/df1.png)
## Part 1
## and this is init.sql file we need it to initiate the datebase 
- ![](01/img/db1.png)
## and this is the Docker Compose file:
- ![](01/img/000.png)
- ![](01/img/001.png)
- ![](01/img/002.png)
- ![](01/img/003.png)
- ![](01/img/004.png)
## and after do the the next two command `DOCKER_BUILDKIT=0 docker compose build` then `docker compose up -d` everything works well.
- ![](01/img/10.png)
- ![](01/img/11.png)


## Part 2
- I setup a machine using vagrant file 
- ![](02/img/20.png)

- beside that I create some script files and they will run while creating the vm machine, first one is to install docker
- ![](02/img/21.png)


- and the second one is to run docker composer
- ![](02/img/22.png)

- and now to run this project we need to use these two command first one `vagrant up` and then `vagrant provision`

-  after everything build we can ssh to the machine `vagrant ssh` and then do a test to check if everything is up and running
- ![](02/img/23.png)


## Part 3
- I register and login to docker website 
- ![](03/img/00.png)
- and I upload the images
- ![](03/img/03.png)

- to build the containers, change the directory to dcompose and run 'docker stack deploy -c docker-compose.yml myapp'
- and then to list we can do 'docker stack ps myapp'
- to run the Postman test we will use the command line version of it and called newman, first we need to install it via npm package manager.
- then run 'newman run application_tests_updated.json'
- ![](03/img/xx.png)
- ![](03/img/01.png)
- To use portainer I needed to create file in '/etc/docker/daemon.json' with contant 
'{
  "min-api-version": "1.24"
}' in each machine, then 'sudo systemctl restart docker' finally run 'docker stack deploy -c portainer-stack.yml portainer'
- ![](03/img/02.png)
