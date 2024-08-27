#!/bin/bash

# 设置版本号
current_version=20240828003

update_script() {
    # 指定URL
    update_url="https://raw.githubusercontent.com/breaddog100/titan-network/main/titan-contract.sh"
    file_name=$(basename "$update_url")

    # 下载脚本文件
    tmp=$(date +%s)
    timeout 10s curl -s -o "$HOME/$tmp" -H "Cache-Control: no-cache" "$update_url?$tmp"
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        echo "命令超时"
        return 1
    elif [[ $exit_code -ne 0 ]]; then
        echo "下载失败"
        return 1
    fi

    # 检查是否有新版本可用
    latest_version=$(grep -oP 'current_version=([0-9]+)' $HOME/$tmp | sed -n 's/.*=//p')

    if [[ "$latest_version" -gt "$current_version" ]]; then
        clear
        echo ""
        # 提示需要更新脚本
        printf "\033[31m脚本有新版本可用！当前版本：%s，最新版本：%s\033[0m\n" "$current_version" "$latest_version"
        echo "正在更新..."
        sleep 3
        mv $HOME/$tmp $HOME/$file_name
        chmod +x $HOME/$file_name
        exec "$HOME/$file_name"
    else
        # 脚本是最新的
        rm -f $tmp
    fi

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

function create_wallet {

    # 合约参数
    read -p "钱包名称: " WALLET_NAME

    # 更新和安装必要的软件
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 snapd curl

    # 安装 Go
    if ! command -v go &> /dev/null; then
        echo "Installing Go..."
        sudo rm -rf /usr/local/go
        wget https://go.dev/dl/go1.22.1.linux-amd64.tar.gz -P /tmp/
        sudo tar -C /usr/local -xzf /tmp/go1.22.1.linux-amd64.tar.gz
        echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> ~/.bashrc
        export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
        source ~/.bashrc  # 使改动立即生效
        go version || { echo "Go installation failed"; exit 1; }
    fi

    # 安装 Rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source $HOME/.cargo/env  # 确保 Rust 的环境变量生效
    rustup default stable
    rustup update stable
    rustup target add wasm32-unknown-unknown

    # 安装 Wasmd
    git clone https://github.com/CosmWasm/wasmd.git
    cd wasmd || exit
    git fetch --tags
    git checkout v0.53.0
    make install
    wasmd version || { echo "Wasmd installation failed"; exit 1; }
    cd ..  # 返回上一级目录

    # 下载合约
    git clone https://github.com/deus-labs/cw-contracts.git
    cd cw-contracts || exit
    git checkout main
    cd contracts/nameservice || exit
    cargo wasm || { echo "WASM compilation failed"; exit 1; }

    # 使用 titand 查询合约
    titand query wasm code 1 --node https://rpc.titannet.io $HOME/cw-contracts/contracts/nameservice/target/wasm32-unknown-unknown/download_1.wasm
    cd $HOME || exit

    # 克隆代码库
    git clone https://github.com/Titannet-dao/titan-chain.git
    cd titan-chain || exit
    go build ./cmd/titand || { echo "Building titand failed"; exit 1; }
    sudo cp titand /usr/local/bin
    titand keys add "$WALLET_NAME" || { echo "Wallet creation failed"; exit 1; }
    echo "请记录如上钱包的信息，使用钱包地址到DC领水。"
}

# 部署合约
function install_contract(){

    read -p "钱包地址: " WALLET_ADDR
    read -p "合约名称: " CON_NAME

    # 安装合约
    titand tx wasm store $HOME/cw-contracts/contracts/nameservice/target/wasm32-unknown-unknown/release/download_1.wasm --from $WALLET_ADDR --gas 10000000 --gas-prices 0.0025uttnt --node https://rpc.titannet.io --chain-id titan-test-3
    # 需要获取code_id
    titand query wasm list-code --node https://rpc.titannet.io

    INIT='{"count":100}'
    #INIT='{"purchase_price":{"amount":"100","denom":"umlg"},"transfer_price":{"amount":"999","denom":"umlg"}}'
    #INIT='{"count":100,"name": "$CON_NAME","symbol": "$CON_NAME","decimals": 6,"initial_balances": {"amount": "100000000","address": "$WALLET_ADDR"}}'
    
    # 返回hash
    CODE_ID=$(titand query wasm list-code --node https://rpc.titannet.io | yq e '.code_infos[] | select(.creator == "$WALLET_ADDR") | .code_id' - | sort -n | tail -n 1)
    #titand tx wasm instantiate $CODE_ID "$INIT" --no-admin --from $WALLET_ADDR --gas 10000000 --gas-prices 0.0025uttnt --label  txqqeth  --node https://rpc.titannet.io --chain-id titan-test-3 
    TXHASH=$(titand tx wasm instantiate $CODE_ID "$INIT" --no-admin --from $WALLET_ADDR --gas 100000000 --gas-prices 0.0025uttnt --label txqqeth --node https://rpc.titannet.io --chain-id titan-test-3 | grep 'txhash:' | awk '{print $2}')

    titand query tx $TXHASH --node https://rpc.titannet.io

    # 调用合约
    REGISTER='{"reset":{"count":100}}'
    titand tx wasm execute titan1fv955ms20zwe60a2ck29h7g9xrwz99pklnlperhnsxtmxyu2m7yq4aaqva "$REGISTER" --fees 500uttnt --from titan1vcumlrq8tfhkc0rdy7qvl0zsfwne4ua8em45jg --node https://rpc.titannet.io --chain-id titan-test-3
}

# 主菜单
function main_menu() {
	while true; do
	    clear
	    echo "===================TitanNetwork 合约一键部署脚本==================="
		echo "当前版本：$current_version"
		echo "沟通电报群：https://t.me/lumaogogogo"
	    echo "请选择要执行的操作:"
	    echo "1. 创建钱包 create_wallet"
	    echo "2. 部署合约 install_contract"
	    echo "1618. 卸载节点 uninstall_node"
	    echo "0. 退出脚本 exit"
	    read -p "请输入选项: " OPTION
	
	    case $OPTION in
	    1) create_wallet ;;
	    2) install_contract ;;
	    1618) uninstall_node ;;
	    0) echo "退出脚本。"; exit 0 ;;
	    *) echo "无效选项，请重新输入。"; sleep 3 ;;
	    esac
	    echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 检查更新
update_script

# 显示主菜单
main_menu
