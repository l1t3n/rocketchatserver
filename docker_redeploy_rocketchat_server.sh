#!/bin/bash
# Script to full redeploy docker containers

### block define_vars ###
{
    dotenv_file=.env
    compose_file=compose.yml

    source $dotenv_file  # import variables from dotenv file
    docker_prefix=$COMPOSE_PROJECT_NAME

    docker_network_name=${docker_prefix}_net
    docker_network_subnet=${DOCKER_NETWORK_SUBNET}
    docker_network_gateway=${DOCKER_NETWORK_GATEWAY}
}
### endblock define_vars ###

### block decorative_echo ###
{
    RED='\033[0;31m';GREEN='\033[0;32m';CYAN='\033[0;36m';NC='\033[0m'  # define colors
    function decor_echo () {
        local color=$1; local input_text=$2
        local row_len=90
        local decorate_len
        let decorate_len=($row_len-${#input_text})/2

        function repeat(){
            local repeat_symbol='=';local repeat_result=''
            for (( i=1; i<=$1; i++ ));do repeat_result+=${repeat_symbol};done
            echo "$repeat_result"
        }

        echo -e "${!color}$(repeat $row_len)"
        echo -e "$(repeat $decorate_len )${NC}${input_text}${!color}$(repeat $decorate_len )"
        echo -e "${!color}$(repeat $row_len)${NC}"
    }

    function decor_green_echo () { local input_text=$@; decor_echo GREEN "$input_text"; }
    function decor_red_echo () { local input_text=$@; decor_echo RED "$input_text"; }
    function cyan_echo () { echo -e "${CYAN}${@}${NC}"; }
    function red_echo () { echo -e "${RED}${@}${NC}"; }
}
### endblock decorative_echo ###

### block check_var_definition
{
    # check files exist
    for filename in compose_file dotenv_file
    do
        echo ${!filename}
        if [ ! -f ${!filename} ]; then
        decor_red_echo File ${!filename} not found!; cyan_echo Exit!; exit 1
    fi
    done

    # check var defined
    if [ -z "$docker_prefix" ]; then decor_red_echo "No containers prefix"; cyan_echo Exit!; exit 1; fi
    if [ -z "$docker_network_subnet" ]; then decor_red_echo "No containers network subnet"; cyan_echo Exit!; exit 1; fi
    if [ -z "$docker_network_gateway" ]; then decor_red_echo "No containers network gateway"; cyan_echo Exit!; exit 1; fi
}
### endblock check_var_definition


### block functions ###
function drop_containers () {
    containers_id=`sudo docker ps --filter name=$docker_prefix -aq`
    if [ -z "$containers_id" ]
    then
        echo "No containers found"
    else
        cyan_echo Stop containers:
        sudo docker stop $containers_id
        cyan_echo Remove containers:
        sudo docker rm $containers_id
    fi

}

function create_network () {
    if sudo docker network ls | grep $docker_network_name
    then
        cyan_echo Network already exist, skip creation
    else
        cyan_echo Network with name $docker_network_name not found
        if sudo docker network inspect $(sudo docker network ls -q) | grep $docker_network_subnet
        then
            decor_red_echo "Docker network with subnet $docker_network_subnet already exist"; cyan_echo Exit!; exit 1
        else
            cyan_echo Create network
            sudo docker network create --subnet $docker_network_subnet --gateway $docker_network_gateway $docker_network_name
        fi
    fi
}

# function fix_dir_permission () {
#     cyan_echo Set permision to prometheus datafolder
#     sudo chown 65534:65534 volumes/prometheus/
# }
### endblock functions ###



### block main ###
function main () {
    decor_green_echo STARTING REBUILD PROCESS
    cyan_echo Stop and drop all containers with prefix $docker_prefix
    drop_containers

    create_network

    cyan_echo Start dockers
    sudo docker-compose --env-file $dotenv_file -f $compose_file up --build -d
    cyan_echo Docker status:
    sudo docker ps -a | grep $docker_prefix

    decor_green_echo REBUILD FINISHED
}
### endblock main ###

main