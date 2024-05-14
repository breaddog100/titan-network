Here is the translation of the Bash script to English:

```bash
#!/bin/bash

# Node installation function
function install_node() {
    # Update the package list
    sudo apt update
    sudo apt upgrade -y

    # Check if Docker is installed
    if ! command -v docker &> /dev/null
    then
        echo "Installing Docker..."
        sudo apt install -y ca-certificates curl gnupg lsb-release docker.io
    else
        echo "Docker is already installed."
    fi

    # Read the UID
    read -p "UID: " uid
    # Read the number of nodes
    read -p "Number of nodes: " docker_count
    # Pull the Docker image
    sudo docker pull nezha123/titan-edge:1.5

    # Create and start the nodes
    titan_port=40000
    for ((i=1; i<=docker_count; i++))
    do
        current_port=$((titan_port + i - 1))
        # Create the storage directory
        mkdir -p "$HOME/titan_storage_$i"

        # Start the node
        container_id=$(sudo docker run -d --restart always -v "$HOME/titan_storage_$i:/root/.titanedge/storage" --name "titan$i" --net=host  nezha123/titan-edge:1.5)
        echo "Node titan$i has started with container ID $container_id"
        sleep 30

        # Configure the storage and port
        sudo docker exec $container_id bash -c "\
            sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = 50/' /root/.titanedge/config.toml && \
            sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_port\"/' /root/.titanedge/config.toml && \
            echo 'Container titan'$i' storage space set to 50 GB, port $current_port'"
        sudo docker restart $container_id

        # Start the node
        sudo docker exec $container_id bash -c "\
            titan-edge bind --hash=$uid https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node titan$i has started."
    done

    echo "============================== Deployment complete ============================="
}

# Check node status
function check_service_status() {
    sudo docker ps
}

# Check node tasks
function check_node_cache() {
    for container in $(sudo docker ps -q); do
        echo "Checking node: $container tasks:"
        sudo docker exec -it "$container" titan-edge cache
    done
}

# Stop node
function stop_node() {
    for container in $(sudo docker ps -q); do
        echo "Stopping node: $container"
        sudo docker exec -it "$container" titan-edge daemon stop
    done
}

# Start node
function start_node() {
    for container in $(sudo docker ps -q); do
        echo "Starting node: $container"
        sudo docker exec -it "$container" titan-edge daemon start
    done
}

# Update UID
function update_uid() {
    # Read the UID
    read -p "UID: " uid
    for container in $(sudo docker ps -q); do
        echo "Starting node: $container"
        sudo docker exec -it "$container" bash -c "\
            titan-edge bind --hash=$uid https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "Node $container has started."
    done
}

# Main menu
function main_menu() {
    while true; do
        clear
        echo "=============== Titan Network One-Key Deployment Script ================"
        echo "Telegram group: https://t.me/lumaogogogo"
        echo "Minimum configuration: 1C2G64G; recommended configuration: 6C12G300G"
        echo "1. Install node"
        echo "2. Check node status"
        echo "3. Check node tasks"
        echo "4. Stop node"
        echo "5. Start node"
        echo "6. Update UID"
        echo "0. Exit script"
        read -r -p "Enter option: " OPTION

        case $OPTION in
        1) install_node ;;
        2) check_service_status ;;
        3) check_node_cache ;;
        4) stop_node ;;
        5) start_node ;;
        6) update_uid ;;
        0) echo "Exiting script"; exit 0 ;;
        *) echo "Invalid option, please try again."; sleep 3 ;;
        esac
        echo "Press any key to return to the main menu..."
        read -n 1
    done
}

# Show menu
main_menu
```