#!/bin/bash

# 节点安装功能
function install_node() {

    # 检查 Docker 是否已安装
    if ! command -v docker &> /dev/null
    then
        echo "安装Docker..."
        # 添加 Docker 官方 GPG 密钥
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        # 设置 Docker 仓库
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
    else
        echo "Docker 已安装。"
    fi
    
    sudo apt update
    sudo apt upgrade -y
   
	# 身份码
	read -p "身份码: " uid	
	# 拉取Docker镜像
	docker pull nezha123/titan-edge:1.5
	
	# 创建币启动容器
	port=40000
	for ((i=1; i<=5; i++))
	do
	    current_port=$((port + i - 1))
	    # 创建存储目录
	    mkdir -p "$HOME/titan_storage_$i"
	
	    # 启动节点
	    container_id=$(docker run -d --restart always -v "$HOME/titan_storage_$i:$HOME/.titanedge/storage" --name "titan$i" --net=host  nezha123/titan-edge:1.5)
	
	    echo "节点 titan$i 已经启动 容器ID $container_id"
	
	    sleep 30
	
	    # 配置存储和端口
	    docker exec $container_id bash -c "\
	        sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = 50/' $HOME/.titanedge/config.toml && \
	        sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' $HOME/.titanedge/config.toml && \
	        echo '容器 titan'$i' 的存储空间设置为 50 GB，端口为 $current_port'"
	
	    docker restart $container_id
	
	    # 启动docker
	    docker exec $container_id bash -c "\
	        titan-edge bind --hash=$uid https://api-test1.container1.titannet.io/api/v2/device/binding"
	    echo "节点 titan$i 已绑定."
	
	done
	
	echo "==============================部署完成==================================="

}

# 查看节点状态
function check_service_status() {
    cd simple-taiko-node
    sudo docker compose logs -f --tail 30
}

# 启动节点
function start_node() {
    cd simple-taiko-node
    sudo docker compose up -d
}

# 停止节点
function stop_node() {
    cd simple-taiko-node
    sudo docker compose down
}

# 修改秘钥
function update_private_key() {
	cd simple-taiko-node
	read -p "请输入EVM钱包私钥: " l1_proposer_private_key
	sed -i "s|L1_PROPOSER_PRIVATE_KEY=.*|L1_PROPOSER_PRIVATE_KEY=${l1_proposer_private_key}|" .env
	# 修改端口
	ip_address=$(hostname -I | awk '{print $1}')
	port_grafana=$(echo $ip_address | cut -d '.' -f 3,4 | tr -d '.')
	sed -i "s|PORT_GRAFANA=.*|PORT_GRAFANA=${port_grafana}|" .env
	sudo docker compose down
	sudo docker compose up -d
}

# MENU
function main_menu() {
    clear
    echo "===============Titan Network 一键部署脚本==============="
    echo "沟通电报群：https://t.me/lumaogogogo"
    echo "最低配置：1C2G64G；推荐配置：6C12G300G"
    echo "1. 安装节点install node"
    echo "2. 查看节点状态cosmovisor status"
    echo "3. 启动节点start node"
    echo "4. 停止节点stop node"
    echo "5. 修改秘钥update private key"
    echo "0. 退出脚本exit"
    read -r -p "请输入选项: " OPTION

    case $OPTION in
    1) install_node ;;
    2) check_service_status ;;
    3) start_node ;;
    4) stop_node ;;
    5) update_private_key ;;
    0) echo "退出脚本。"; exit 0 ;;
    *) echo "无效选项，请重新输入。"; sleep 3 ;;
    esac
}

# SHOW MENU
main_menu