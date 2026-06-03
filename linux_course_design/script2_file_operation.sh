#!/bin/bash

# ============================================================
# 题目2：文件操作系统
# 功能：实现文件夹和文件的创建、修改、删除等操作
# 作者：[你的姓名]
# 学号：[你的学号]
# ============================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 操作日志文件
OPERATION_LOG="/workspace/linux_course_design/file_operation.log"

# 初始化日志文件
init_file_log() {
    if [ ! -f "$OPERATION_LOG" ]; then
        touch "$OPERATION_LOG"
        echo "文件操作日志 - 创建时间: $(date)" > "$OPERATION_LOG"
    fi
}

# 记录操作日志
log_operation() {
    local operation="$1"
    local target="$2"
    local status="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $operation | 目标: $target | 状态: $status" >> "$OPERATION_LOG"
}

# ============================================
# 功能1：创建文件夹（目录）
# 逻辑说明：
#   1. 接收用户输入的目标路径
#   2. 检查目录是否已存在，避免覆盖
#   3. 使用mkdir命令创建目录，支持递归创建父目录(-p)
#   4. 设置默认权限为755（rwxr-xr-x）
# 参数：无参数，交互式获取路径
# ============================================
create_folder() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}           创建文件夹${NC}"
    echo -e "${BLUE}============================================${NC}"

    # 获取当前工作目录作为参考
    current_dir=$(pwd)
    echo -e "${YELLOW}当前工作目录: $current_dir${NC}"
    echo ""

    # 输入要创建的目录路径（支持相对路径和绝对路径）
    read -p "请输入要创建的文件夹路径: " folder_path

    # 检查输入是否为空
    if [ -z "$folder_path" ]; then
        echo -e "${RED}[错误] 文件夹路径不能为空！${NC}"
        return 1
    fi

    # 检查目录是否已存在（核心逻辑）
    # -d操作符用于判断路径是否为已存在的目录
    if [ -d "$folder_path" ]; then
        echo -e "${RED}[错误] 文件夹 '$folder_path' 已存在！${NC}"
        log_operation "创建文件夹" "$folder_path" "失败-已存在"
        return 1
    fi

    # 询问是否需要创建多级目录
    read -p "是否需要自动创建不存在的父目录？(y/n): " create_parent

    echo -e "${YELLOW}[正在创建文件夹]...${NC}"

    if [ "$create_parent" = "y" ] || [ "$create_parent" = "Y" ]; then
        # -p 参数：递归创建所有不存在的父目录
        mkdir -p "$folder_path"
        parent_info="（含父目录）"
    else
        # 仅创建最后一级目录
        mkdir "$folder_path"
        parent_info=""
    fi

    # 检查创建结果
    if [ $? -eq 0 ]; then
        # 设置目录权限为755（所有者读写执行，组和其他用户读执行）
        chmod 755 "$folder_path"

        echo -e "${GREEN}[成功] 文件夹 '$folder_path' 创建成功！$parent_info${NC}"

        # 显示文件夹详细信息
        echo -e "\n${YELLOW}--- 文件夹信息 ---${NC}"
        ls -ld "$folder_path"

        log_operation "创建文件夹" "$folder_path" "成功"
    else
        echo -e "${RED}[错误] 文件夹创建失败！请检查权限或路径格式。${NC}"
        log_operation "创建文件夹" "$folder_path" "失败-权限不足"
        return 1
    fi
}

# ============================================
# 功能2：删除文件夹
# 逻辑说明：
#   1. 验证目标目录是否存在
#   2. 安全检查：防止误删系统关键目录
#   3. 二次确认机制
#   4. 可选递归删除内容或仅删除空目录
# ============================================
delete_folder() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}           删除文件夹${NC}"
    echo -e "${BLUE}============================================${NC}"

    read -p "请输入要删除的文件夹路径: " folder_path

    # 检查目录是否存在
    if [ ! -d "$folder_path" ]; then
        echo -e "${RED}[错误] 文件夹 '$folder_path' 不存在！${NC}"
        return 1
    fi

    # 安全检查：禁止删除系统关键目录
    local protected_dirs=("/" "/home" "/usr" "/var" "/etc" "/root")
    for protected in "${protected_dirs[@]}"; do
        if [ "$(realpath "$folder_path")" = "$protected" ]; then
            echo -e "${RED}[错误] 不允许删除系统关键目录 '$protected'！${NC}"
            return 1
        fi
    done

    # 显示将要删除的内容
    echo -e "${YELLOW}--- 将要删除的文件夹内容 ---${NC}"
    ls -la "$folder_path" 2>/dev/null || echo "(空目录)"

    # 二次确认
    echo -e "${RED}[警告] 此操作不可恢复！${NC}"
    read -p "确定要删除文件夹 '$folder_path' 及其所有内容吗？(输入 yes 确认): " confirm

    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}已取消删除操作。${NC}"
        return 0
    fi

    echo -e "${YELLOW}[正在删除文件夹]...${NC}"

    # -rf 参数：强制递归删除（不提示确认）
    rm -rf "$folder_path"

    if [ $? -eq 0 ] && [ ! -d "$folder_path" ]; then
        echo -e "${GREEN}[成功] 文件夹 '$folder_path' 已成功删除！${NC}"
        log_operation "删除文件夹" "$folder_path" "成功"
    else
        echo -e "${RED}[错误] 文件夹删除失败！${NC}"
        log_operation "删除文件夹" "$folder_path" "失败"
        return 1
    fi
}

# ============================================
# 功能3：创建文件
# 逻辑说明：
#   1. 指定目标文件夹和文件名
#   2. 检查文件是否已存在
#   3. 使用touch命令创建空文件
#   4. 可选立即写入初始内容
# ============================================
create_file() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}            创建文件${NC}"
    echo -e "${BLUE}============================================${NC}"

    # 步骤1：选择或指定目标文件夹
    echo -e "${YELLOW}--- 选择目标位置 ---${NC}"
    read -p "请输入文件所在文件夹路径 (回车使用当前目录): " target_dir

    if [ -z "$target_dir" ]; then
        target_dir=$(pwd)
    fi

    # 检查目标目录是否存在
    if [ ! -d "$target_dir" ]; then
        echo -e "${RED}[错误] 目录 '$target_dir' 不存在！${NC}"
        return 1
    fi

    # 步骤2：输入文件名
    read -p "请输入要创建的文件名: " filename

    # 检查文件名是否为空
    if [ -z "$filename" ]; then
        echo -e "${RED}[错误] 文件名不能为空！${NC}"
        return 1
    fi

    # 构建完整文件路径
    file_path="$target_dir/$filename"

    # 检查文件是否已存在
    if [ -f "$file_path" ]; then
        echo -e "${YELLOW}[警告] 文件 '$file_path' 已存在！${NC}"
        read -p "是否覆盖现有文件？(y/n): " overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            echo -e "${YELLOW}已取消操作。${NC}"
            return 0
        fi
    fi

    # 创建文件
    echo -e "${YELLOW}[正在创建文件]...${NC}"
    touch "$file_path"

    if [ $? -eq 0 ]; then
        # 设置默认权限为644（rw-r--r--）
        chmod 644 "$file_path"

        echo -e "${GREEN}[成功] 文件 '$file_path' 创建成功！${NC}"

        # 询问是否写入初始内容
        read -p "是否立即向文件写入内容？(y/n): " write_content

        if [ "$write_content" = "y" ] || [ "$write_content" = "Y" ]; then
            echo -e "${YELLOW}请输入文件内容（输入 :wq 结束）：${NC}"
            echo "--- 文件内容开始 ---"

            # 循环读取多行输入
            > "$file_path"  # 清空文件
            while IFS= read -r line; do
                if [ "$line" = ":wq" ]; then
                    break
                fi
                echo "$line" >> "$file_path"
            done

            echo "--- 文件内容结束 ---"
            echo -e "${GREEN}内容写入完成！${NC}"
        fi

        # 显示文件信息
        echo -e "\n${YELLOW}--- 文件信息 ---${NC}"
        ls -lh "$file_path"
        echo "文件大小: $(stat -c%s "$file_path") 字节"
        echo "创建时间: $(stat -c%y "$file_path")"

        log_operation "创建文件" "$file_path" "成功"
    else
        echo -e "${RED}[错误] 文件创建失败！${NC}"
        log_operation "创建文件" "$file_path" "失败"
        return 1
    fi
}

# ============================================
# 功能4：修改/编辑文件内容
# 逻辑说明：
#   1. 定位目标文件并验证存在性
#   2. 提供多种编辑方式选择
#   3. 支持追加、覆盖、行插入等模式
#   4. 自动备份原文件（安全措施）
# ============================================
modify_file() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}          修改文件内容${NC}"
    echo -e "${BLUE}============================================${NC}"

    # 输入文件路径
    read -p "请输入要修改的文件完整路径: " file_path

    # 检查文件是否存在
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}[错误] 文件 '$file_path' 不存在！${NC}"
        return 1
    fi

    # 显示当前文件内容预览
    echo -e "\n${YELLOW}--- 当前文件内容 (前10行) ---${NC}"
    head -n 10 "$file_path"
    echo "..."
    echo -e "${YELLOW}文件大小: $(wc -l < "$file_path") 行, $(stat -c%s "$file_path") 字节${NC}"
    echo ""

    # 备份原文件（安全措施）
    backup_path="${file_path}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$file_path" "$backup_path"
    echo -e "${GREEN}[备份] 原文件已备份至: $backup_path${NC}"

    # 选择修改模式
    echo -e "${YELLOW}--- 请选择修改模式 ---${NC}"
    echo "1. 追加内容（在文件末尾添加）"
    echo "2. 覆盖内容（替换全部内容）"
    echo "3. 在指定行前插入内容"
    echo "4. 替换指定字符串"
    read -p "请选择 (1-4): " mode

    case $mode in
        1)
            # 追加模式：使用 >> 重定向符
            echo -e "${YELLOW}请输入要追加的内容（输入 :wq 结束）：${NC}"
            while IFS= read -r line; do
                if [ "$line" = ":wq" ]; then
                    break
                fi
                echo "$line" >> "$file_path"
            done
            echo -e "${GREEN}[成功] 内容已追加到文件末尾${NC}"
            ;;

        2)
            # 覆盖模式：使用 > 重定向符
            echo -e "${YELLOW}请输入新的文件内容（输入 :wq 结束）：${NC}"
            > "$file_path"  # 先清空文件
            while IFS= read -r line; do
                if [ "$line" = ":wq" ]; then
                    break
                fi
                echo "$line" >> "$file_path"
            done
            echo -e "${GREEN}[成功] 文件内容已被完全替换${NC}"
            ;;

        3)
            # 行插入模式
            read -p "请在第几行前插入内容: " line_num
            echo -e "${YELLOW}请输入要插入的内容（输入 :wq 结束）：${NC}"
            temp_file=$(mktemp)

            line_count=1
            inserted=0

            while IFS= read -r line || [ -n "$line" ]; do
                if [ "$line_count" = "$line_num" ] && [ "$inserted" -eq 0 ]; then
                    while IFS= read -r new_line; do
                        if [ "$new_line" = ":wq" ]; then
                            inserted=1
                            break
                        fi
                        echo "$new_line" >> "$temp_file"
                    done
                fi
                echo "$line" >> "$temp_file"
                line_count=$((line_count + 1))
            done < "$file_path"

            mv "$temp_file" "$file_path"
            echo -e "${GREEN}[成功] 内容已插入到第 ${line_num} 行之前${NC}"
            ;;

        4)
            # 字符串替换模式：使用sed命令
            read -p "请输入要被替换的原始字符串: " old_str
            read -p "请输入新的替换字符串: " new_str

            # sed -i 直接修改文件，s/old/new/g 全局替换
            sed -i "s/$old_str/$new_str/g" "$file_path"
            echo -e "${GREEN}[成功] 所有 '$old_str' 已被替换为 '$new_str'${NC}"
            ;;

        *)
            echo -e "${RED}[错误] 无效的选择！${NC}"
            ;;
    esac

    log_operation "修改文件" "$file_path" "成功"
}

# ============================================
# 功能5：删除文件
# 逻辑说明：
#   1. 验证目标文件存在性
#   2. 安全检查：防止删除系统配置文件
#   3. 二次确认后执行删除
# ============================================
delete_file() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}            删除文件${NC}"
    echo -e "${BLUE}============================================${NC}"

    read -p "请输入要删除的文件完整路径: " file_path

    # 检查文件是否存在且是普通文件（不是目录）
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}[错误] 文件 '$file_path' 不存在或不是一个普通文件！${NC}"
        return 1
    fi

    # 显示文件信息
    echo -e "${YELLOW}--- 将要删除的文件信息 ---${NC}"
    ls -lh "$file_path"

    # 安全检查：警告系统文件
    system_dirs=("/etc/" "/usr/bin/" "/usr/sbin/")
    for sys_dir in "${system_dirs[@]}"; do
        if [[ "$file_path" == $sys_dir* ]]; then
            echo -e "${RED}[警告] 这可能是系统重要文件！${NC}"
            break
        fi
    done

    # 二次确认
    echo -e "${RED}[警告] 此操作不可恢复！${NC}"
    read -p "确定要删除文件 '$file_path' 吗？(输入 yes 确认): " confirm

    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}已取消删除操作。${NC}"
        return 0
    fi

    # 执行删除
    rm -f "$file_path"

    if [ $? -eq 0 ] && [ ! -f "$file_path" ]; then
        echo -e "${GREEN}[成功] 文件 '$file_path' 已成功删除！${NC}"
        log_operation "删除文件" "$file_path" "成功"
    else
        echo -e "${RED}[错误] 文件删除失败！${NC}"
        log_operation "删除文件" "$file_path" "失败"
        return 1
    fi
}

# ============================================
# 辅助功能：浏览目录内容
# ============================================
browse_directory() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}          浏览目录内容${NC}"
    echo -e "${BLUE}============================================${NC}"

    read -p "请输入要浏览的目录路径 (回车查看当前目录): " browse_path

    if [ -z "$browse_path" ]; then
        browse_path=$(pwd)
    fi

    if [ ! -d "$browse_path" ]; then
        echo -e "${RED}[错误] 目录不存在！${NC}"
        return 1
    fi

    echo -e "\n${YELLOW}目录: $browse_path${NC}"
    echo ""

    # 以列表形式显示内容
    echo "类型  权限       大小      修改时间              名称"
    echo "----  --------   ------    ------------------     ----"
    ls -lh "$browse_path" | tail -n +2 | while read -r line; do
        # 解析每行的第一个字符判断类型
        type_char=$(echo "$line" | cut -c1)
        case $type_char in
            d) type_name="目录" ;;
            -) type_name="文件" ;;
            l) type_name="链接" ;;
            *) type_name="其他" ;;
        esac
        name=$(echo "$line" | awk '{print $NF}')
        echo "$type_name  $line  $name"
    done

    # 统计信息
    file_count=$(find "$browse_path" -maxdepth 1 -type f | wc -l)
    dir_count=$(find "$browse_path" -maxdepth 1 -type d | wc -l)
    echo ""
    echo -e "${YELLOW}统计: $file_count 个文件, $((dir_count - 1)) 个子目录${NC}"
}

# ============================================
# 主菜单界面
# ============================================
main_menu() {
    init_file_log

    while true; do
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║       Linux 文件操作系统 v1.0            ║${NC}"
        echo -e "${GREEN}╠══════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║                                          ║${NC}"
        echo -e "${GREEN}║   1. 创建文件夹                          ║${NC}"
        echo -e "${GREEN}║   2. 删除文件夹                          ║${NC}"
        echo -e "${GREEN}║   3. 创建文件                            ║${NC}"
        echo -e "${GREEN}║   4. 修改/编辑文件                       ║${NC}"
        echo -e "${GREEN}║   5. 删除文件                            ║${NC}"
        echo -e "${GREEN}║   6. 浏览目录内容                        ║${NC}"
        echo -e "${GREEN}║   0. 退出系统                            ║${NC}"
        echo -e "${GREEN}║                                          ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
        echo ""

        read -p "请选择功能 (0-6): " choice

        case $choice in
            1)
                create_folder
                ;;
            2)
                delete_folder
                ;;
            3)
                create_file
                ;;
            4)
                modify_file
                ;;
            5)
                delete_file
                ;;
            6)
                browse_directory
                ;;
            0)
                echo -e "${YELLOW}感谢使用文件操作系统，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[错误] 无效的选择，请重新输入！${NC}"
                ;;
        esac

        echo ""
        read -p "按回车键继续..."
    done
}

# 程序入口
main_menu
