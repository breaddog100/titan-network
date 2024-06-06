#!/bin/bash

# 节点安装功能
function install_node() {

	sudo apt update
    sudo apt upgrade -y

    # 检查 Docker 是否已安装
    if ! command -v docker &> /dev/null
    then
        echo "安装Docker..."
        sudo apt install  -y ca-certificates curl gnupg lsb-release docker.io
    else
        echo "Docker 已安装。"
    fi
   
	# 身份码
	read -p "uid: " uid
	# 节点数量
	read -p "docker_count: " docker_count
	# 拉取Docker镜像
	sudo docker pull nezha123/titan-edge:1.5
	
	# 创建币启动容器
	titan_port=50000
	for ((i=1; i<=docker_count; i++))
	do
	    current_port=$((titan_port + i - 1))
	    # 创建存储目录
	    mkdir -p "$HOME/titan_storage_$i"
	
	    # 启动节点
	    container_id=$(sudo docker run -d --restart always -v "$HOME/titan_storage_$i:/root/.titanedge/storage" --name "titan$i" --net=host  nezha123/titan-edge:1.5)
	    echo "节点 titan$i 已经启动 容器ID $container_id"
	    sleep 30
	
	    # 配置存储和端口
	    sudo docker exec $container_id bash -c "\
	        sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = 20/' /root/.titanedge/config.toml && \
	        sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' /root/.titanedge/config.toml && \
	        echo '容器 titan'$i' 的存储空间设置为 20 GB，端口为 $current_port'"
	
	    sudo docker restart $container_id
	
	    # 开始挂机
	    sudo docker exec $container_id bash -c "\
	        titan-edge bind --hash=$uid https://api-test1.container1.titannet.io/api/v2/device/binding"
	    echo "节点 titan$i 开始挂机."
	
	done
	
	echo "==============================部署完成==================================="

}

# 查看节点状态
function check_service_status() {
    sudo docker ps
}

# 查看节点任务
function check_node_cache() {
	for container in $(sudo docker ps -q); do
		echo "查看节点：$container 任务："
		sudo docker exec -it "$container" titan-edge cache
	done
}

# 停止节点
function stop_node() {
	for container in $(sudo docker ps -q); do
		echo "停止节点：$container "
		sudo docker exec -it "$container" titan-edge daemon stop
	done
}

# 启动节点
function start_node() {
	for container in $(sudo docker ps -q); do
		echo "启动节点：$container "
		sudo docker exec -it "$container" titan-edge daemon start
	done
}

# 修改身份码
function update_uid() {
	# 身份码
	read -p "身份码: " uid
	for container in $(sudo docker ps -q); do
		echo "启动节点：$container "
		sudo docker exec -it "$container" bash -c "\
	        titan-edge bind --hash=$uid https://api-test1.container1.titannet.io/api/v2/device/binding"
	    echo "节点 $container 开始挂机."
	done
}

# MENU
function main_menu() {
	while true; do
	    clear
	    echo "===============Titan Network 一键部署脚本==============="
	    echo "沟通电报群：https://t.me/lumaogogogo"
	    echo "最低配置：1C2G64G；推荐配置：6C12G300G"
	    echo "1. 安装节点install node"
	    echo "2. 查看节点状态cosmovisor status"
	    echo "3. 查看节点任务check node cache"
	    echo "4. 停止挂机stop node"
	    echo "5. 开始挂机start node"
	    echo "6. 修改身份码update uid"
	    echo "0. 退出脚本exit"
	    read -r -p "OPTION: " OPTION
	
	    case $OPTION in
	    1) install_node ;;
	    2) check_service_status ;;
	    3) check_node_cache ;;
	    4) stop_node ;;
	    5) start_node ;;
	    6) update_uid ;;
	    0) echo "退出脚本。"; exit 0 ;;
	    *) echo "无效选项，请重新输入。"; sleep 3 ;;
	    esac
	    echo "按任意键返回主菜单..."
        read -n 1
    done
}

# SHOW MENU
main_menu
