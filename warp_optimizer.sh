#!/bin/bash
export LANG=en_US.UTF-8

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

# 定义颜色显示函数
red() {
    printf "\033[31m\033[01m%s\033[0m\n" "$1"
}

green() {
    printf "\033[32m\033[01m%s\033[0m\n" "$1"
}

yellow() {
    printf "\033[33m\033[01m%s\033[0m\n" "$1"
}

# 获取客户端 CPU 架构
getCPUArch(){
    case "$(uname -m)" in
        x86_64 | amd64 ) echo 'amd64' ;;
        armv8 | arm64 | aarch64 ) echo 'arm64' ;;
        * ) red "不支持的CPU架构!" >&2; return 1 ;;
    esac
}

# 获取操作系统类型
getOSType(){
    case "$(uname)" in
        Linux ) echo 'linux' ;;
        Darwin ) echo 'darwin' ;;
        * ) red "不支持的操作系统!" >&2; return 1 ;;
    esac
}

# 优化 WARP Endpoint IP
optimizeWARPIP(){
    local result_file="result.csv"
    local warp_tool="warp"

    # 删除之前的优选结果文件，以避免出错
    rm -f "$result_file"

    # 获取 CPU 架构和操作系统类型
    local arch; arch=$(getCPUArch)
    local os_type; os_type=$(getOSType)

    # 检查是否成功获取架构和操作系统类型
    if [[ $? -ne 0 ]]; then
        red "获取系统信息失败！"
        exit 1
    fi

    # 下载 WARP 优选工具
    wget "https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-${os_type}-${arch}" -O "$warp_tool"

    # 设置文件权限并取消 Linux 自带的线程限制
    chmod +x "$warp_tool"
    ulimit -n 102400

    # 调试信息：确认 warp 工具的路径和权限
    ls -l "$warp_tool"

    # 启动 WARP Endpoint IP 优选工具
    if [[ $1 == 6 ]]; then
        "./$warp_tool" -ipv6
    else
        "./$warp_tool"
    fi

    # 确认 result.csv 是否生成
    if [[ -f "$result_file" ]]; then
        green "当前最优 Endpoint IP 结果如下，并已保存至 $result_file 中："
        awk -F, '$3!="timeout ms" {print} ' "$result_file" | sort -t, -nk2 -nk3 | uniq | head -11 | awk -F, '{print "端点 "$1" 丢包率 "$2" 平均延迟 "$3}'
        echo ""
        yellow "优选 IP 使用方法如下："
        yellow "1. 将 WARP 的 WireGuard 节点的默认的 Endpoint IP：engage.cloudflareclient.com:2408 替换成本地网络最优的 Endpoint IP"
        echo "设置方法命令行执行: warp-cli tunnel endpoint set 优选IP+端口"

        # 自动设置第一个最优 IP 并检查是否能访问openai.com
        local best_ip
        for best_ip in $(awk -F, 'NR>1{print $1}' "$result_file"); do
            if curl --connect-timeout 5 -s https://chatgpt.com > /dev/null; then
                if warp-cli settings | grep -q "Organization"; then
                    sudo warp-cli tunnel endpoint set "$best_ip"
                else
                    warp-cli tunnel endpoint set "$best_ip"
                fi
                echo "已经成功自动设置为第一个能够访问openai.com的最优IP: $best_ip"
                break
            else
                red "IP: $best_ip 无法访问 openai.com，尝试下一个。"
            fi
        done

        if [[ -z "$best_ip" ]]; then
            red "没有找到能够访问openai.com的最优IP，请手动检查。"
        fi
    else
        red "未生成 result.csv 文件，请检查 warp 工具是否正确运行。"
    fi

    # 删除 WARP 优选工具
    rm -f "$warp_tool"
}

# 显示菜单并处理用户输入
displayMenu(){
    echo "#############################################################"
    echo -e "#               ${RED}WARP Endpoint IP 一键优选脚本${PLAIN}               #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP IPv4 Endpoint IP 优选 ${YELLOW}(默认)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} WARP IPv6 Endpoint IP 优选"
    echo " -------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp "请输入选项 [0-2]: " menuInput
    case $menuInput in
        2 ) optimizeWARPIP 6 ;;
        0 ) exit 0 ;;
        * ) optimizeWARPIP ;;
    esac
}

displayMenu
