#!/bin/bash

# 设置版本号
current_version=20240828008

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

function install_env {

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

    cd $HOME || exit

    # 克隆代码库
    git clone https://github.com/Titannet-dao/titan-chain.git
    cd titan-chain || exit
    go build ./cmd/titand || { echo "Building titand failed"; exit 1; }
    sudo cp titand /usr/local/bin

}

function create_wallet(){
    read -p "钱包名称: " WALLET_NAME
    titand keys add "$WALLET_NAME" || { echo "Wallet creation failed"; exit 1; }
    echo "请记录如上钱包的信息，使用钱包地址到DC领水，领水成功后再部署合约。"
}

function recover_wallet(){
    read -p "钱包名称: " WALLET_NAME
    echo "请输入钱包助记词"
    titand keys add "$WALLET_NAME" --recover || { echo "Wallet creation failed"; exit 1; }
    echo "请确保钱包里有水，再部署合约。"
}

# 部署合约
function install_contract(){

    read -p "钱包地址: " WALLET_ADDR
    read -p "合约名称: " CON_NAME

    # 使用 titand 查询合约
    /usr/local/bin/titand query wasm code 1 --node https://rpc.titannet.io $HOME/cw-contracts/contracts/nameservice/target/wasm32-unknown-unknown/release/download_1.wasm
    # 安装合约
    /usr/local/bin/titand tx wasm store $HOME/cw-contracts/contracts/nameservice/target/wasm32-unknown-unknown/release/download_1.wasm --from $WALLET_ADDR --gas 10000000 --gas-prices 0.0025uttnt --node https://rpc.titannet.io --chain-id titan-test-3
    # 需要获取code_id
    /usr/local/bin/titand query wasm list-code --node https://rpc.titannet.io

    INIT='{"count":100}'
    
    # 返回hash
    CODE_ID=$(/usr/local/bin/titand query wasm list-code --node https://rpc.titannet.io | yq e ".code_infos[] | select(.creator == \"$WALLET_ADDR\") | .code_id" - | sort -n | tail -n 1)
    TXHASH=$(/usr/local/bin/titand tx wasm instantiate $CODE_ID "$INIT" --no-admin --from $WALLET_ADDR --gas 100000000 --gas-prices 0.0025uttnt --label $CON_NAME --node https://rpc.titannet.io --chain-id titan-test-3 | grep 'txhash:' | awk '{print $2}')
    key_contract_address=$(/usr/local/bin/titand query tx $TXHASH --node https://rpc.titannet.io | yq e '.events[] | select(.type == "instantiate") | .attributes[] | select(.key == "_contract_address").value' -)

    # 调用合约
    REGISTER='{"reset":{"count":100}}'
    /usr/local/bin/titand tx wasm execute $key_contract_address "$REGISTER" --fees 500uttnt --from $WALLET_ADDR --node https://rpc.titannet.io --chain-id titan-test-3
    
    echo "合约部署完成，用上面的txhash值可以到官方浏览器中查询。"

}

# 主菜单
function main_menu() {
	while true; do
	    clear
	    echo "===================TitanNetwork 合约一键部署脚本==================="
		echo "当前版本：$current_version"
		echo "沟通电报群：https://t.me/lumaogogogo"
	    echo "请选择要执行的操作:"
        
	    echo "1. 部署环境 install_env"
        echo "2. 创建钱包 create_wallet"
        echo "3. 导入钱包 recover_wallet"
	    echo "4. 部署合约 install_contract"
	    echo "0. 退出脚本 exit"
	    read -p "请输入选项: " OPTION
	
	    case $OPTION in
	    1) install_env ;;
        2) create_wallet ;;
        3) recover_wallet ;;
	    4) install_contract ;;
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
