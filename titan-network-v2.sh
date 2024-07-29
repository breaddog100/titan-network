#!/bin/bash

# 节点部署
function l1_install_node() {
	read -p "请输入code id:" code_id
	read -p "请输入身份码:" UUID
	sudo apt update && sudo apt upgrade -y
	wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19-b/titan-l1-guardian
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
    
    ./titan-l1-guardian bind --hash=$UUID https://api-test1.container1.titannet.io/api/v2/device/binding
    
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
    #wget =====
	docker load -i titan-edge.tar
    mkdir ~/.titanedge
    sudo docker run --network=host -d -v ~/.titanedge:/root/.titanedge nezha123/titan-edge
    sudo docker run --rm -it -v ~/.titanedge:/root/.titanedge nezha123/titan-edge bind --hash=$UUID https://api-test1.container1.titannet.io/api/v2/device/binding
  	
	echo "部署完成"
}

# L1节点日志
function l1_node_log(){
	sudo journalctl -u titan-candidate-daemond -f -o cat
}

# L2节点日志
function l2_node_log(){
	sudo docker logs -f -t priceless_brattain
}

# 停止l1节点
function l1_stop_node(){
	sudo systemctl stop titan-candidate-daemond
	sudo pkill -9 titan-l1-guardian
	echo "L1 节点已停止"
}

# 启动l1节点
function l1_start_node(){
	read -p "请输入身份码:" UUID
	sudo systemctl start titan-candidate-daemond
	./titan-l1-guardian bind --hash=$UUID https://api-test1.container1.titannet.io/api/v2/device/binding
	echo "L1 节点已停止"
}

# 停止l2节点
function l2_stop_node(){
	sudo docker stop priceless_brattain
	echo "L2 节点已停止"
}

# 更新l1节点
function l1_update_node(){
	cd $HOME
	l1_stop_node
	wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.19-b/titan-l1-guardian
	chmod 0755 titan-l1-guardian
	./titan-l1-guardian -v
	l1_start_node
}

# 检查Go环境
function check_go_installation() {
    if command -v go > /dev/null 2>&1; then
        echo "Go 环境已安装"
        return 0 
    else
        echo "Go 环境未安装，正在安装..."
        return 1 
    fi
}

# 部署验证节点
function validator_install(){

	read -p "请输入节点名称: " MONIKER
	
	# 更新和安装必要的软件
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 snapd

    # 安装 Go
    if ! check_go_installation; then
        # 安装GO
        sudo rm -rf /usr/local/go
        wget https://go.dev/dl/go1.22.1.linux-amd64.tar.gz -P /tmp/
        sudo tar -C /usr/local -xzf /tmp/go1.22.1.linux-amd64.tar.gz
        echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
        go version
    fi

    # 克隆代码库
    cd $HOME
    git clone https://github.com/nezha90/titan.git
    cd titan
    go build ./cmd/titand
    sudo cp titand /usr/local/bin

    # 初始化
    titand init $MONIKER --chain-id titan-test-1

    # 获取初始文件和地址簿
    wget https://raw.githubusercontent.com/nezha90/titan/main/genesis/genesis.json
    mv genesis.json ~/.titan/config/genesis.json

    # 配置节点
    SEEDS="bb075c8cc4b7032d506008b68d4192298a09aeea@47.76.107.159:26656"
    sed -i 's|^seed *=.*|seed = "'$SEEDS'"|' $HOME/.titan/config/config.toml

    wget https://raw.githubusercontent.com/nezha90/titan/main/addrbook/addrbook.json
    mv addrbook.json ~/.titan/config/addrbook.json

    # 修改参数
    sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"0\"/" $HOME/.titan/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.titan/config/app.toml
    sed -i -e 's/max_num_inbound_peers = 40/max_num_inbound_peers = 100/' -e 's/max_num_outbound_peers = 10/max_num_outbound_peers = 100/' $HOME/.titan/config/config.toml
    sed -i.bak -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0025uttnt\"/;" ~/.titan/config/app.toml

    # 创建服务
    sudo tee /etc/systemd/system/titand.service > /dev/null << EOF
[Unit]
Description=Titan Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=/usr/local/bin/titand start
Restart=always
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

	sudo systemctl daemon-reload
    sudo systemctl enable titand
    sudo systemctl start titand
    
    echo "部署完成"
}

# 停止验证者
function validator_stop(){
	sudo systemctl stop titand
	echo "验证节点已停止"
}

# 启动验证者
function validator_start(){
	sudo systemctl start titand
	echo "验证节点已启动"
}

# 验证者日志
function validator_logs(){
	journalctl -u titand.service -f -o cat
}

# 创建钱包
function validator_create_wallet() {
	read -p "请输入钱包名称: " wallet_name
    titand keys add $wallet_name
}

# 导入钱包
function validator_import_wallet() {
	read -p "请输入钱包名称: " wallet_name
    titand keys add $wallet_name --recover
}

# 查询余额
function validator_balances() {
    read -p "请输入钱包地址: " wallet_address
    titand query bank balances "$wallet_address"
}

# 同步状态
function validator_sync_status() {
    titand status | jq .SyncInfo
}

# 创建验证者
function validator_create_validator() {
    read -p "请输入钱包名称: " wallet_name
    read -p "请输入验证者名称: " validator_name
    
	titand tx staking create-validator \
	--amount="1000000uttnt" \
	--pubkey=$(titand tendermint show-validator) \
	--moniker="$validator_name" \
	--commission-max-change-rate=0.01 \
	--commission-max-rate=1.0 \
	--commission-rate=0.07 \
	--min-self-delegation=1 \
	--fees 500uttnt \
	--from="$wallet_name" \
	--chain-id=titan-test-1
}

# 给自己质押
function validator_delegate() {
	read -p "质押数量(单位:uttnt，1ttnt=1000000uttnt): " math
	read -p "请输入钱包名称: " wallet_name
	titand tx staking delegate $(titand keys show $wallet_name --bech val -a)  ${math}uttnt --from $wallet_name --fees 500uttnt
}

# 备份验证者文件
function validator_backup_key() {
    cp $HOME/.titan/config/priv_validator_key.json $HOME/priv_validator_key.json.bak
    echo "已将验证者文件复制到$HOME/priv_validator_key.json.bak，请备份。"
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
            validator_stop
            
            sudo docker rm -f priceless_brattain
            rm -rf $HOME/titan_storage titan-l1-guardian
            rm -rf $HOME/.titanedge
            rm -rf $HOME/titan $HOME/.titan 

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
	    echo "=================Titan-network 一键部署脚本==================="
		echo "沟通电报群：https://t.me/lumaogogogo"
		echo "L1配置:16C16G10T;L2节点配置:1C1G50G;验证节点:16C16G2T"
		echo "请选择要执行的操作:"
		echo "---------------------------L1节点----------------------------"
	    echo "10. 部署L1节点 l1_install_node"
	    echo "11. 停止L1节点 l1_stop_node"
	    echo "12. 查看L1日志 l1_node_log"
	    echo "13. 启动L1节点 l1_start_node"
	    echo "14. 更新v0.1.19-b l1_update_node"
	    echo "---------------------------L2节点----------------------------"
	    echo "20. 部署L2节点 l2_install_node"
	    echo "21. 停止L2节点 l2_stop_node"
	    echo "22. L2节点日志 l2_node_log"
	    #echo "23. 国内机器部署 l2_install_node_for_cn"
	    echo "--------------------------验证节点---------------------------"
	    echo "30. 部署验证节点 validator_install"
	    echo "31. 停止验证节点 validator_stop"
	    echo "32. 启动验证节点 validator_start"
	    echo "33. 验证节点日志 validator_logs"
	    echo "34. 创建钱包 validator_create_wallet"
	    echo "35. 导入钱包 validator_import_wallet"
	    echo "36. 查询余额 validator_balances"
	    echo "37. 同步状态 validator_sync_status"
	    echo "38. 创建验证者 validator_create_validator"
	    echo "39. 质押代币 validator_delegate"
	    echo "40. 备份验证者 validator_backup_key"
	    echo "1618. 卸载节点（L1&L2） uninstall_node"
	    echo "0. 退出脚本 exit"
	    read -p "请输入选项: " OPTION
	
	    case $OPTION in
	    10) l1_install_node ;;
	    11) l1_stop_node ;;
	    12) l1_node_log ;;
	    13) l1_start_node ;;
	    14) l1_update_node ;;
	    
	    20) l2_install_node ;;
	    21) l2_stop_node ;;
	    22) l2_node_log ;;
	    23) l2_install_node_for_cn ;;
	    
	    30) validator_install ;;
	    31) validator_stop ;;
	    32) validator_start ;;
	    33) validator_logs ;;
	    34) validator_create_wallet ;;
	    35) validator_import_wallet ;;
	    36) validator_balances ;;
	    37) validator_sync_status ;;
	    38) validator_create_validator ;;
	    39) validator_delegate ;;
	    40) validator_backup_key ;;
	    
	    1618) uninstall_node ;;
	    0) echo "退出脚本。"; exit 0 ;;
	    *) echo "无效选项，请重新输入。"; sleep 3 ;;
	    esac
	    echo "按任意键返回主菜单..."
        read -n 1
    done
}

main_menu