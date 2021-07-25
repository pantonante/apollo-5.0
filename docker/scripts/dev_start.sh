#!/usr/bin/env bash

###############################################################################
# Copyright 2017 The Apollo Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

APOLLO_ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
CACHE_ROOT_DIR="${APOLLO_ROOT_DIR}/.cache"

INCHINA="no"
LOCAL_IMAGE="no"
FAST_BUILD_MODE="no"
FAST_TEST_MODE="no"
VERSION=""
ARCH=$(uname -m)
VERSION_X86_64="dev-x86_64-20190617_1100"
VERSION_AARCH64="dev-aarch64-20170927_1111"
# LGSVL:
VERSION_OPT="latest"

ulimit -c 0

# Check whether user has agreed license agreement
function check_agreement() {
  agreement_record="${HOME}/.apollo_agreement.txt"
  if [ -e "$agreement_record" ]; then
    return
  fi

  AGREEMENT_FILE="$APOLLO_ROOT_DIR/scripts/AGREEMENT.txt"
  if [ ! -e "$AGREEMENT_FILE" ]; then
    error "AGREEMENT $AGREEMENT_FILE does not exist."
    exit 1
  fi

  cat $AGREEMENT_FILE
  tip="Type 'y' or 'Y' to agree to the license agreement above, or type any other key to exit"
  echo $tip
  read -n 1 user_agreed
  if [ "$user_agreed" == "y" ] || [ "$user_agreed" == "Y" ]; then
    cp $AGREEMENT_FILE $agreement_record
    echo "$tip" >> $agreement_record
    echo "$user_agreed" >> $agreement_record
  else
    exit 1
  fi
}

function show_usage()
{
cat <<EOF
Usage: $(basename $0) [options] ...
OPTIONS:
    -C                     Pull docker image from China mirror.
    -b, --fast-build       Light mode for building without pulling all the map volumes
    -f, --fast-test        Light mode for testing without pulling limited set of map volumes
    -h, --help             Display this help and exit.
    -t, --tag <version>    Specify which version of a docker image to pull.
    -l, --local            Use local docker image.
    stop                   Stop all running Apollo containers.
EOF
exit 0
}

function stop_containers()
{
running_containers=$(docker ps --format "{{.Names}}")

for i in ${running_containers[*]}
do
  if [[ "$i" =~ apollo_* ]];then
    printf %-*s 70 "stopping container: $i ..."
    docker stop $i > /dev/null
    if [ $? -eq 0 ];then
      printf "\033[32m[DONE]\033[0m\n"
    else
      printf "\033[31m[FAILED]\033[0m\n"
    fi
  fi
done
}

if [ "$DEV_START__BUILD_ONLY__LGSVL" != "1" ];then
  if [ "$(readlink -f /apollo)" != "${APOLLO_ROOT_DIR}" ]; then
      sudo ln -snf ${APOLLO_ROOT_DIR} /apollo
  fi

  if [ -e /proc/sys/kernel ]; then
      echo "/apollo/data/core/core_%e.%p" | sudo tee /proc/sys/kernel/core_pattern > /dev/null
  fi
fi

source ${APOLLO_ROOT_DIR}/scripts/apollo_base.sh
if [ "$DEV_START__BUILD_ONLY__LGSVL" != "1" ];then
  check_agreement
fi

VOLUME_VERSION="latest"
DEFAULT_MAPS=(
#  LGSVL:
#  sunnyvale_big_loop
#  sunnyvale_loop
#  sunnyvale_with_two_offices
#  san_mateo
)
DEFAULT_TEST_MAPS=(
  sunnyvale_big_loop
  sunnyvale_loop
)
MAP_VOLUME_CONF=""
OTHER_VOLUME_CONF=""

while [ $# -gt 0 ]
do
    case "$1" in
    -C|--docker-cn-mirror)
        INCHINA="yes"
        ;;
    -image)
        echo -e "\033[093mWarning\033[0m: This option has been replaced by \"-t\" and \"--tag\", please use the new one.\n"
        show_usage
        ;;
    -t|--tag)
        VAR=$1
        [ -z $VERSION_OPT ] || echo -e "\033[093mWarning\033[0m: mixed option $VAR with $VERSION_OPT, only the last one will take effect.\n"
        shift
        VERSION_OPT=$1
        [ -z ${VERSION_OPT// /} ] && echo -e "Missing parameter for $VAR" && exit 2
        [[ $VERSION_OPT =~ ^-.* ]] && echo -e "Missing parameter for $VAR" && exit 2
        ;;
    dev-*) # keep backward compatibility, should be removed from further version.
        [ -z $VERSION_OPT ] || echo -e "\033[093mWarning\033[0m: mixed option $1 with -t/--tag, only the last one will take effect.\n"
        VERSION_OPT=$1
        echo -e "\033[93mWarning\033[0m: You are using an old style command line option which may be removed from"
        echo -e "further versoin, please use -t <version> instead.\n"
        ;;
    -b|--fast-build)
        FAST_BUILD_MODE="yes"
        ;;
    -f|--fast-test)
        FAST_TEST_MODE="yes"
        ;;
    -h|--help)
        show_usage
        ;;
    -l|--local)
        LOCAL_IMAGE="yes"
        ;;
    --map)
        map_name=$2
        shift
        source ${APOLLO_ROOT_DIR}/docker/scripts/restart_map_volume.sh \
            "${map_name}" "${VOLUME_VERSION}"
        ;;
    stop)
	stop_containers
	exit 0
	;;
    *)
        echo -e "\033[93mWarning\033[0m: Unknown option: $1"
        exit 2
        ;;
    esac
    shift
done

if [ ! -z "$VERSION_OPT" ]; then
    VERSION=$VERSION_OPT
elif [ ${ARCH} == "x86_64" ]; then
    VERSION=${VERSION_X86_64}
elif [ ${ARCH} == "aarch64" ]; then
    VERSION=${VERSION_AARCH64}
else
    echo "Unknown architecture: ${ARCH}"
    exit 0
fi

# LGSVL:
if [ -z "${DOCKER_REPO_VOLUME}" ]; then
    DOCKER_REPO_VOLUME=apolloauto/apollo
fi
if [ -z "${DOCKER_REPO}" ]; then
    DOCKER_REPO=lgsvl/apollo-5.0
fi

if [ "$INCHINA" == "yes" ]; then
    DOCKER_REPO_VOLUME=registry.docker-cn.com/apolloauto/apollo
    DOCKER_REPO=registry.docker-cn.com/apolloauto/apollo
fi

if [ "$LOCAL_IMAGE" == "yes" ] && [ -z "$VERSION_OPT" ]; then
    VERSION="local_dev"
fi

IMG=${DOCKER_REPO}:$VERSION

function local_volumes() {
    # Apollo root dir is required.
    volumes="-v $APOLLO_ROOT_DIR:/apollo"
    case "$(uname -s)" in
        Linux)
            volumes="${volumes} -v /dev:/dev \
                                -v /media:/media \
                                -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
                                -v /etc/localtime:/etc/localtime:ro \
                                -v /usr/src:/usr/src \
                                -v /lib/modules:/lib/modules"
            ;;
    esac
    echo "${volumes}"
}

function main(){

    if [ "$LOCAL_IMAGE" = "yes" ];then
        info "Start docker container based on local image : $IMG"
    else
        info "Start pulling docker image $IMG ..."
        docker pull $IMG
        if [ $? -ne 0 ];then
            error "Failed to pull docker image."
            exit 1
        fi
    fi

    # LGSVL:
    APOLLO_DEV="apollo_5.0_dev_${USER}"
    docker ps -a --format "{{.Names}}" | grep "$APOLLO_DEV" 1>/dev/null
    if [ $? == 0 ]; then
        # if [[ "$(docker inspect --format='{{.Config.Image}}' $APOLLO_DEV 2> /dev/null)" != "$APOLLO_DEV_IMAGE" ]]; then
        #     rm -rf $APOLLO_ROOT_DIR/bazel-*
        #     rm -rf ${CACHE_ROOT_DIR}/bazel/*
        # fi
        docker stop $APOLLO_DEV 1>/dev/null
        docker rm -v -f $APOLLO_DEV 1>/dev/null
    fi

    if [ "$FAST_BUILD_MODE" == "no" ]; then
        if [ "$FAST_TEST_MODE" == "no" ]; then
            # Included default maps.
            for map_name in ${DEFAULT_MAPS[@]}; do
              source ${APOLLO_ROOT_DIR}/docker/scripts/restart_map_volume.sh ${map_name} "${VOLUME_VERSION}"
            done
            YOLO3D_VOLUME=apollo_yolo3d_volume_$USER
            YOLO3D_VOLUME1=apollo_yolo3d_lane13d_volume_$USER
            YOLO3D_VOLUME2=apollo_yolo3d_lane2d_volume_$USER
            YOLO3D_VOLUME3=apollo_yolo3d_yolo3d_volume_$USER
            YOLO3D_VOLUME1_PATH=/apollo/modules/perception/model/yolo_camera_detector/lane13d_0716
            YOLO3D_VOLUME2_PATH=/apollo/modules/perception/model/yolo_camera_detector/lane2d_0627
            YOLO3D_VOLUME3_PATH=/apollo/modules/perception/model/yolo_camera_detector/yolo3d_1128
            docker stop ${YOLO3D_VOLUME} > /dev/null 2>&1

            YOLO3D_VOLUME_IMAGE=${DOCKER_REPO_VOLUME}:yolo3d_volume-${ARCH}-latest
            docker pull ${YOLO3D_VOLUME_IMAGE}
            docker run -it -d --rm --name ${YOLO3D_VOLUME} -v ${YOLO3D_VOLUME1}:${YOLO3D_VOLUME1_PATH} -v ${YOLO3D_VOLUME2}:${YOLO3D_VOLUME2_PATH} -v ${YOLO3D_VOLUME3}:${YOLO3D_VOLUME3_PATH} ${YOLO3D_VOLUME_IMAGE} true

            OTHER_VOLUME_CONF="${OTHER_VOLUME_CONF} -v ${YOLO3D_VOLUME1}:${YOLO3D_VOLUME1_PATH} -v ${YOLO3D_VOLUME2}:${YOLO3D_VOLUME2_PATH} -v ${YOLO3D_VOLUME3}:${YOLO3D_VOLUME3_PATH}"
        else
            # Included default maps.
            for map_name in ${DEFAULT_TEST_MAPS[@]}; do
              source ${APOLLO_ROOT_DIR}/docker/scripts/restart_map_volume.sh ${map_name} "${VOLUME_VERSION}"
            done
        fi
    fi

    LOCALIZATION_VOLUME=apollo_localization_volume_$USER
    LOCALIZATION_VOLUME_PATH=/usr/local/apollo/local_integ
    docker stop ${LOCALIZATION_VOLUME} > /dev/null 2>&1

    LOCALIZATION_VOLUME_IMAGE=${DOCKER_REPO_VOLUME}:localization_volume-${ARCH}-latest
    docker pull ${LOCALIZATION_VOLUME_IMAGE}
    docker run -it -d --rm --name ${LOCALIZATION_VOLUME} -v ${LOCALIZATION_VOLUME}:${LOCALIZATION_VOLUME_PATH} ${LOCALIZATION_VOLUME_IMAGE} true
    OTHER_VOLUME_CONF="${OTHER_VOLUME_CONF} -v ${LOCALIZATION_VOLUME}:${LOCALIZATION_VOLUME_PATH}"

    PADDLE_VOLUME=apollo_paddlepaddle_volume_$USER
    PADDLE_VOLUME1=apollo_paddlepaddle_volume_$USER
    PADDLE_VOLUME2=apollo_paddlepaddle_dep_volume_$USER
    PADDLE_VOLUME1_PATH=/usr/local/apollo/paddlepaddle
    PADDLE_VOLUME2_PATH=/usr/local/apollo/paddlepaddle_dep
    docker stop ${PADDLE_VOLUME} > /dev/null 2>&1

    PADDLE_VOLUME_IMAGE=${DOCKER_REPO_VOLUME}:paddlepaddle_volume-${ARCH}-latest
    docker pull ${PADDLE_VOLUME_IMAGE}
    docker run -it -d --rm --name ${PADDLE_VOLUME} -v ${PADDLE_VOLUME1}:${PADDLE_VOLUME1_PATH} -v ${PADDLE_VOLUME2}:${PADDLE_VOLUME2_PATH} ${PADDLE_VOLUME_IMAGE} true
    OTHER_VOLUME_CONF="${OTHER_VOLUME_CONF} -v ${PADDLE_VOLUME1}:${PADDLE_VOLUME1_PATH} -v ${PADDLE_VOLUME2}:${PADDLE_VOLUME2_PATH}"

    LOCAL_THIRD_PARTY_VOLUME=apollo_local_third_party_volume_$USER
    LOCAL_THIRD_PARTY_VOLUME_PATH=/usr/local/apollo/local_third_party
    docker stop ${LOCAL_THIRD_PARTY_VOLUME} > /dev/null 2>&1

    LOCAL_THIRD_PARTY_VOLUME_IMAGE=${DOCKER_REPO_VOLUME}:local_third_party_volume-${ARCH}-latest
    docker pull ${LOCAL_THIRD_PARTY_VOLUME_IMAGE}
    docker run -it -d --rm --name ${LOCAL_THIRD_PARTY_VOLUME} -v ${LOCAL_THIRD_PARTY_VOLUME}:${LOCAL_THIRD_PARTY_VOLUME_PATH} ${LOCAL_THIRD_PARTY_VOLUME_IMAGE} true
    OTHER_VOLUME_CONF="${OTHER_VOLUME_CONF} -v ${LOCAL_THIRD_PARTY_VOLUME}:${LOCAL_THIRD_PARTY_VOLUME_PATH}"

    local display=""
    if [[ -z ${DISPLAY} ]];then
        display=":0"
    else
        display="${DISPLAY}"
    fi

    if [ "$DEV_START__BUILD_ONLY__LGSVL" != "1" ];then
        setup_device
    fi

    USER_ID=$(id -u)
    GRP=apollo
    GRP_ID=$(id -g)
    LOCAL_HOST=`hostname`
    DOCKER_HOME="/home/$USER"
    if [ "$USER" == "root" ];then
        DOCKER_HOME="/root"
    fi
    if [ ! -d "${CACHE_ROOT_DIR}" ]; then
        mkdir "${CACHE_ROOT_DIR}"
    fi

    info "Starting docker container \"${APOLLO_DEV}\" ..."

    DOCKER_VERSION=$(docker version --format '{{.Client.Version}}' | cut -d'.' -f1)

    if [[ -z "${APOLLO_GPU_DEVICE}" ]]; then
        GPU_DEVICE="all"
    fi
    DOCKER_GPU_DEVICE="device=$APOLLO_GPU_DEVICE"


    if [[ $DOCKER_VERSION -ge "19" ]] && ! type nvidia-docker; then
        DOCKER_CMD="docker"
        USE_GPU=1
        GPUS="--gpus \"$DOCKER_GPU_DEVICE\""
    else
        DOCKER_CMD="nvidia-docker"
        USE_GPU=1
        GPUS=""
    fi

    set -x

    ${DOCKER_CMD} run -it \
        -d \
        --cap-add ALL \
        ${GPUS} \
        --name $APOLLO_DEV \
        ${MAP_VOLUME_CONF} \
        ${OTHER_VOLUME_CONF} \
        -e DISPLAY=$display \
        -e DOCKER_USER=$USER \
        -e USER=$USER \
        -e DOCKER_USER_ID=$USER_ID \
        -e DOCKER_GRP="$GRP" \
        -e DOCKER_GRP_ID=$GRP_ID \
        -e DOCKER_IMG=$IMG \
        -e USE_GPU=$USE_GPU \
        -e NVIDIA_VISIBLE_DEVICES=${APOLLO_GPU_DEVICE} \
        -e NVIDIA_DRIVER_CAPABILITIES=compute,video,graphics,utility \
        $(local_volumes) \
        --net host \
        -w /apollo \
        --add-host in_5_0_dev_docker:127.0.0.1 \
        --add-host ${LOCAL_HOST}:127.0.0.1 \
        --hostname in_5_0_dev_docker \
        --shm-size 2G \
        --pid=host \
        -v /dev/null:/dev/raw1394 \
        $IMG \
        /bin/bash
    set +x
    if [ $? -ne 0 ];then
        error "Failed to start docker container \"${APOLLO_DEV}\" based on image: $IMG"
        exit 1
    fi

    if [ "${USER}" != "root" ]; then
        docker exec $APOLLO_DEV bash -c '/apollo/scripts/docker_adduser.sh'
    fi

    ok "Finished setting up Apollo docker environment. Now you can enter with: \nbash docker/scripts/dev_into.sh"
    ok "Enjoy!"
}

main
