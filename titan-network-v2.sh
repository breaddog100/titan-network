#!/bin/bash

# 节点部署
function l1_install_node() {
	read -p "请输入code id:" code_id
	read -p "请输入身份码:" UUID
	sudo apt update && sudo apt upgrade -y
	wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19/titan-l1-guardian
	chmod 0755 titan-l1-guardian
	mkdir -p $HOME/titan_storage
	export TITAN_METADATAPATH=$HOME/titan_storage
	export TITAN_ASSETSPATHS=$HOME/titan_storage
	
	sudo sysctl -w net.core.rmem_max=2500000
	sudo sysctl -w net.core.wmem_max=2500000
	
	#nohup ./titan-l1-guardian daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 --code $code_id > $HOME/guardian.log 2>&1 &
	#./titan-l1-guardian bind --hash=$UUID https://api-test1.container1.titannet.io/api/v2/device/binding


	sudo tee /etc/systemd/system/titan-candidate-daemond.service > /dev/null <<EOF
[Unit]
Description=Titan candidate Service
After=network.target
[Service]
ExecStart=$HOME/titan-l1-guardian daemon start --init --url https://cassini-locator.titannet.io:5000/rpc/v0 --code $code_id
Restart=always
RestartSec=3
User=$USER
Environment=$HOME/
[Install]
WantedBy=multi-user.target
EOF

	sudo systemctl daemon-reload
    sudo systemctl enable titan-candidate-daemond
    sudo systemctl start titan-candidate-daemond

	sudo tee /etc/systemd/system/titan-candidate-bind.service > /dev/null <<EOF
[Unit]
Description=Titan candidate Service
After=network.target
[Service]
ExecStart=$HOME/titan-l1-guardian bind --hash=$UUID https://api-test1.container1.titannet.io/api/v2/device/binding
Restart=always
RestartSec=3
User=$USER
Environment=$HOME/
[Install]
WantedBy=multi-user.target
EOF

	sudo systemctl daemon-reload
    sudo systemctl enable titan-candidate-bind
    sudo systemctl start titan-candidate-bind
    
	echo "部署完成"
}

function l2_install_node() {
	read -p "请输入身份码:" UUID
	sudo apt update && sudo apt upgrade -y
	# 检查 Docker 是否已安装
    if ! command -v docker &> /dev/null
    then
        echo "安装Docker..."
        sudo apt install  -y ca-certificates curl gnupg lsb-release docker.io
    else
        echo "Docker 已安装。"
    fi
    sudo docker pull nezha123/titan-edge
    mkdir ~/.titanedge
    sudo docker run --network=host -d -v ~/.titanedge:/root/.titanedge nezha123/titan-edge
    sudo docker run --rm -it -v ~/.titanedge:/root/.titanedge nezha123/titan-edge bind --hash=$UUID https://api-test1.container1.titannet.io/api/v2/device/binding
  	
	echo "部署完成"
}

function l2_install_node_for_cn() {
	read -p "请输入身份码:" UUID
	sudo apt update && sudo apt upgrade -y
	# 检查 Docker 是否已安装
    if ! command -v docker &> /dev/null
    then
        echo "安装Docker..."
        sudo apt install  -y ca-certificates curl gnupg lsb-release docker.io
    else
        echo "Docker 已安装。"
    fi
    wget =====
	docker load -i titan-edge.tar
    mkdir ~/.titanedge
    sudo docker run --network=host -d -v ~/.titanedge:/root/.titanedge nezha123/titan-edge
    sudo docker run --rm -it -v ~/.titanedge:/root/.titanedge nezha123/titan-edge bind --hash=$UUID https://api-test1.container1.titannet.io/api/v2/device/binding
  	
	echo "部署完成"
}

# L1节点日志
function l1_node_log(){
	sudo journalctl -u titan-candidate-bind -f -o cat
}

# L2节点日志
function l2_node_log(){
	sudo docker logs -f -t priceless_brattain
}

# 停止l1节点
function l2_stop_node(){
	./titan-l1-guardian daemon stop
	echo "L1 节点已停止"
}

# 停止l2节点
function l2_stop_node(){
	sudo docker stop priceless_brattain
	echo "L2 节点已停止"
}

# 卸载节点
function uninstall_node(){
    echo "你确定要卸载节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "开始卸载节点程序..."
            l1_stop_node
            l2_stop_node
            sudo docker rm -f priceless_brattain
            
            rm -rf $HOME/titan_storage titan-l1-guardian
            rm -rf $HOME/.titanedge

            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

# 主菜单
function main_menu() {
	while true; do
	    clear
	    echo "===================Titan-network 一键部署脚本==================="
		echo "沟通电报群：https://t.me/lumaogogogo"
		echo "L1配置：16C16G10T；L2节点配置：1C1G50G"
		echo "请选择要执行的操作:"
		echo "---------------------------L1节点----------------------------"
	    echo "10. 部署L1节点 l1_install_node"
	    echo "11. 停止L1节点 l1_stop_node"
	    echo "12. 查看L1日志 l1_node_log"
	    echo "---------------------------L2节点----------------------------"
	    echo "20. 部署L2节点 l2_install_node"
	    echo "21. 停止L2节点 l2_stop_node"
	    echo "22. L2节点日志 l2_node_log"
	    #echo "23. 国内机器部署 l2_install_node_for_cn"
	    echo "1618. 卸载节点（L1&L2） uninstall_node"
	    echo "0. 退出脚本 exit"
	    read -p "请输入选项: " OPTION
	
	    case $OPTION in
	    10) l1_install_node ;;
	    11) l1_stop_node ;;
	    12) l1_node_log ;;
	    
	    20) l2_install_node ;;
	    21) l2_stop_node ;;
	    22) l2_node_log ;;
	    23) l2_install_node_for_cn ;;
	    1618) uninstall_node ;;
	    0) echo "退出脚本。"; exit 0 ;;
	    *) echo "无效选项，请重新输入。"; sleep 3 ;;
	    esac
	    echo "按任意键返回主菜单..."
        read -n 1
    done
}

main_menu