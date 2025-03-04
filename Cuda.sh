#!/bin/bash

# Function to log messages
log_message() {
    echo -e "\n[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Function to handle errors
handle_error() {
    log_message "❌ Error: $1"
    exit 1
}

# Function to check and install essential packages
install_essential_packages() {
    log_message "🔍 Checking and installing essential packages..."
    local packages=(
        "nvtop" "gnupg2" "gnupg1" "htop" "screen" "curl" "sudo" "wget" "fonts-noto" "fonts-noto-color-emoji"
        "fonts-dejavu" "fonts-freefont-ttf" "fonts-ubuntu" "fonts-roboto" "fonts-liberation"
    )

    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            log_message "📦 Installing $pkg..."
            sudo apt-get install -y "$pkg" || handle_error "Failed to install $pkg"
        else
            log_message "✅ $pkg is already installed."
        fi
    done

    log_message "✅ All essential packages are installed."
}

# Function to update and upgrade the system
update_system() {
    log_message "🔄 Updating and upgrading the system..."
    sudo apt-get update || handle_error "Failed to update package lists."
    sudo apt-get upgrade -y || handle_error "Failed to upgrade packages."
    sudo apt-get autoremove -y || handle_error "Failed to remove unused packages."
    log_message "✅ System updated and upgraded."
}

# Function to check NVIDIA GPU
check_nvidia_gpu() {
    log_message "🔍 Checking for NVIDIA GPU..."
    if ! command -v nvidia-smi &> /dev/null; then
        handle_error "NVIDIA GPU not detected! Install NVIDIA drivers first."
    fi
    log_message "✅ NVIDIA GPU detected!"
}

# Function to check if CUDA is installed and matches the required version
is_cuda_installed() {
    if command -v nvcc &> /dev/null; then
        CUDA_VERSION=$(nvcc --version | grep -oP 'release \K[0-9]+\.[0-9]+')
        REQUIRED_CUDA_VERSION="12.8"
        if [[ "$CUDA_VERSION" == "$REQUIRED_CUDA_VERSION" ]]; then
            log_message "✅ CUDA $REQUIRED_CUDA_VERSION is already installed!"
            return 0
        else
            log_message "⚠️ CUDA is installed, but the version ($CUDA_VERSION) does not match the required version ($REQUIRED_CUDA_VERSION)."
            return 1
        fi
    else
        log_message "❌ CUDA is not installed."
        return 1
    fi
}

# Function to set up CUDA environment variables
setup_cuda_env() {
    log_message "🔧 Setting up CUDA environment variables..."
    echo 'export PATH=/usr/local/cuda-12.8/bin${PATH:+:${PATH}}' | sudo tee /etc/profile.d/cuda.sh
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' | sudo tee -a /etc/profile.d/cuda.sh
    source /etc/profile.d/cuda.sh
    log_message "✅ CUDA environment variables set up successfully."
}

# Function to install CUDA Toolkit 12.8 in WSL or Ubuntu
install_cuda() {
    if is_cuda_installed; then
        log_message "⏩ CUDA is already installed. Skipping installation."
        return
    fi

    log_message "🔧 Setting up CUDA environment before installation..."
    setup_cuda_env

    if [[ -n "$WSL_DISTRO_NAME" ]]; then
        log_message "🖥️ Installing CUDA for WSL 2..."
        # Define file names and URLs for WSL
        PIN_FILE="cuda-wsl-ubuntu.pin"
        PIN_URL="https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin"
        DEB_FILE="cuda-repo-wsl-ubuntu-12-8-local_12.8.0-1_amd64.deb"
        DEB_URL="https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda-repo-wsl-ubuntu-12-8-local_12.8.0-1_amd64.deb"
    else
        log_message "🖥️ Installing CUDA for Ubuntu..."
        # Define file names and URLs for Ubuntu
        PIN_FILE="cuda-ubuntu2404.pin"
        PIN_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-ubuntu2404.pin"
        DEB_FILE="cuda-repo-ubuntu2404-12-8-local_12.8.0-570.86.10-1_amd64.deb"
        DEB_URL="https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda-repo-ubuntu2404-12-8-local_12.8.0-570.86.10-1_amd64.deb"
    fi

    # Download and install CUDA
    log_message "📥 Downloading CUDA installation files..."
    wget -O "/tmp/$PIN_FILE" "$PIN_URL" || handle_error "Failed to download $PIN_FILE."
    wget -O "/tmp/$DEB_FILE" "$DEB_URL" || handle_error "Failed to download $DEB_FILE."

    log_message "📦 Installing CUDA..."
    sudo dpkg -i "/tmp/$DEB_FILE" || handle_error "Failed to install CUDA."

    # Add the missing GPG key
    log_message "🔑 Adding missing GPG key..."
    sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/3bf863cc.pub || handle_error "Failed to add GPG key."

    # Update package lists
    log_message "🔄 Updating package lists..."
    sudo apt-get update || handle_error "Failed to update package lists."

    # Install CUDA
    log_message "📦 Installing CUDA package..."
    sudo apt-get install -y cuda || handle_error "Failed to install CUDA."

    log_message "✅ CUDA installed successfully."
}

# Main script execution
log_message "🚀 Starting system setup..."

# Check and install essential packages
install_essential_packages

# Update and upgrade the system
update_system

# Check for NVIDIA GPU
check_nvidia_gpu

# Install CUDA if not already installed
setup_cuda_env
install_cuda
setup_cuda_env

log_message "🎉 Cuda setup completed successfully!"
