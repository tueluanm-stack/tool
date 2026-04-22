#!/data/data/com.termux/files/usr/bin/env bash
# =====================================================================
#  TERMUX SUPER TOOLKIT  -  by v0
#  Chạy trực tiếp:  bash <(curl -s https://your.url/termux-toolkit.sh)
# =====================================================================
#  - Menu CLI có màu
#  - Tự cài phụ thuộc còn thiếu (pkg)
#  - Tự động phát hiện & tận dụng quyền ROOT (su)
#  - Xem thông tin máy siêu chi tiết
#  - Quản lý ứng dụng (kể cả hệ thống), gỡ/xoá
#  - File manager kiểu ZArchiver (cd, ls, rename, cp, mv, rm, paste)
#  - Ép xung CPU / GPU / I/O (yêu cầu root)
# =====================================================================

# ---------- Shebang fallback cho môi trường không phải Termux -------
if [ ! -x "/data/data/com.termux/files/usr/bin/env" ]; then
    :  # vẫn cho chạy bằng /bin/bash nếu không phải Termux
fi

set -u
LC_ALL=C.UTF-8 2>/dev/null || true
export LANG="${LANG:-en_US.UTF-8}"

# ============================= MÀU SẮC ==============================
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    C_RESET="$(tput sgr0)"
    C_BOLD="$(tput bold)"
    C_DIM="$(tput dim)"
    C_RED="$(tput setaf 1)"
    C_GREEN="$(tput setaf 2)"
    C_YELLOW="$(tput setaf 3)"
    C_BLUE="$(tput setaf 4)"
    C_MAGENTA="$(tput setaf 5)"
    C_CYAN="$(tput setaf 6)"
    C_WHITE="$(tput setaf 7)"
else
    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
    C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
    C_BLUE=$'\e[34m'; C_MAGENTA=$'\e[35m'; C_CYAN=$'\e[36m'; C_WHITE=$'\e[37m'
fi

# ============================ BIẾN TOÀN CỤC ==========================
IS_TERMUX=0
IS_ROOT=0
ROOT_GRANTED=0          # 1 nếu user đã đồng ý dùng su
SU_CMD=""               # lệnh su thực tế (vd: "su -c")
CLIPBOARD_PATH=""       # cho file manager
CLIPBOARD_MODE=""       # "copy" | "cut"
SCRIPT_NAME="Termux Super Toolkit"
SCRIPT_VER="1.0.0"

# ======================= TIỆN ÍCH IN ẤN ==============================
msg()    { printf "%s\n" "$*"; }
info()   { printf "${C_CYAN}[i]${C_RESET} %s\n" "$*"; }
ok()     { printf "${C_GREEN}[✓]${C_RESET} %s\n" "$*"; }
warn()   { printf "${C_YELLOW}[!]${C_RESET} %s\n" "$*"; }
err()    { printf "${C_RED}[✗]${C_RESET} %s\n" "$*" >&2; }
hr()     { printf "${C_DIM}%s${C_RESET}\n" "────────────────────────────────────────────────────────"; }

press_enter() {
    printf "\n${C_DIM}Nhấn Enter để tiếp tục...${C_RESET}"
    read -r _ || true
}

ask_yn() {
    # ask_yn "Câu hỏi" [default Y|N]
    local q="$1" def="${2:-N}" ans hint
    if [ "$def" = "Y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
    printf "${C_YELLOW}?${C_RESET} %s %s " "$q" "$hint"
    read -r ans || ans=""
    ans="${ans:-$def}"
    case "$ans" in
        y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

# ===================== PHÁT HIỆN MÔI TRƯỜNG ==========================
detect_env() {
    if [ -d "/data/data/com.termux" ] || [ -n "${PREFIX:-}" ] && echo "${PREFIX:-}" | grep -q "com.termux"; then
        IS_TERMUX=1
    fi

    if [ "$(id -u)" = "0" ]; then
        IS_ROOT=1
        ROOT_GRANTED=1
        SU_CMD=""
    elif command -v su >/dev/null 2>&1; then
        # thử su -c id (không blocking lâu)
        if timeout 3 su -c "id" >/dev/null 2>&1; then
            IS_ROOT=1
            SU_CMD="su -c"
        fi
    fi
}

# chạy 1 lệnh, tự bọc su nếu đã được cấp root
runx() {
    if [ "$ROOT_GRANTED" = "1" ] && [ -n "$SU_CMD" ]; then
        su -c "$*"
    else
        eval "$@"
    fi
}

# ========================= CÀI PHỤ THUỘC =============================
ensure_pkg() {
    # ensure_pkg <command> <package-name>
    local cmd="$1" pkg="$2"
    if command -v "$cmd" >/dev/null 2>&1; then return 0; fi
    if [ "$IS_TERMUX" = "1" ] && command -v pkg >/dev/null 2>&1; then
        info "Đang cài gói còn thiếu: ${C_BOLD}${pkg}${C_RESET}"
        yes | pkg install -y "$pkg" >/dev/null 2>&1 || {
            warn "Không thể tự cài '$pkg'. Hãy chạy: pkg install $pkg"
            return 1
        }
        ok "Đã cài $pkg"
    else
        warn "Thiếu lệnh '$cmd' (gói: $pkg). Không phải Termux nên bỏ qua."
        return 1
    fi
}

bootstrap_deps() {
    # các gói nhỏ, hữu ích
    ensure_pkg awk  gawk       || true
    ensure_pkg grep grep       || true
    ensure_pkg sed  sed        || true
    ensure_pkg stat coreutils  || true
    ensure_pkg getprop termux-tools || true
    ensure_pkg termux-info termux-tools || true
}

# ========================= XIN ROOT ==================================
ask_for_root() {
    if [ "$IS_ROOT" = "0" ]; then
        warn "Không phát hiện quyền root (su) trên máy."
        return 1
    fi
    if [ "$ROOT_GRANTED" = "1" ] && [ -z "$SU_CMD" ]; then
        ok "Đang chạy với UID 0 (đã là root)."
        return 0
    fi
    printf "\n${C_MAGENTA}${C_BOLD}⚡ MÁY CÓ QUYỀN ROOT ⚡${C_RESET}\n"
    msg "Script có thể dùng ${C_BOLD}su${C_RESET} để khai thác toàn bộ quyền:"
    msg "  - Đọc/ghi mọi vùng /data, /system"
    msg "  - Gỡ cả ứng dụng hệ thống"
    msg "  - Ép xung CPU/GPU, chỉnh governor, I/O scheduler"
    msg "  - Xem log kernel, thao tác trực tiếp sysfs"
    if ask_yn "Bạn đồng ý cấp TOÀN QUYỀN root cho script này không?" "N"; then
        # test lại su
        if timeout 5 su -c "id" >/dev/null 2>&1; then
            ROOT_GRANTED=1
            SU_CMD="su -c"
            ok "Đã cấp quyền root. Các chức năng nâng cao đã mở khóa."
        else
            err "Không thể lấy quyền su (bị từ chối?)."
            ROOT_GRANTED=0
        fi
    else
        ROOT_GRANTED=0
        info "Chạy ở chế độ thường (không root)."
    fi
}

# ========================= BANNER ====================================
banner() {
    clear
    printf "${C_CYAN}${C_BOLD}"
    cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║      ████████╗███████╗██████╗ ███╗   ███╗██╗   ██╗██╗    ║
║      ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║   ██║╚██╗   ║
║         ██║   █████╗  ██████╔╝██╔████╔██║██║   ██║ ╚██╗  ║
║         ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║ ██╔╝  ║
║         ██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╔╝██╔╝   ║
║         ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝    ║
║                                                          ║
║              S U P E R   T O O L K I T                   ║
╚══════════════════════════════════════════════════════════╝
EOF
    printf "${C_RESET}"
    local root_tag env_tag
    if [ "$ROOT_GRANTED" = "1" ]; then
        root_tag="${C_GREEN}${C_BOLD}ROOT ✓${C_RESET}"
    elif [ "$IS_ROOT" = "1" ]; then
        root_tag="${C_YELLOW}root (chưa cấp)${C_RESET}"
    else
        root_tag="${C_DIM}no-root${C_RESET}"
    fi
    if [ "$IS_TERMUX" = "1" ]; then
        env_tag="${C_GREEN}Termux${C_RESET}"
    else
        env_tag="${C_YELLOW}Non-Termux${C_RESET}"
    fi
    printf "  ${C_DIM}v%s${C_RESET}    Env: %s    Quyền: %s\n" "$SCRIPT_VER" "$env_tag" "$root_tag"
    hr
}

# ========================= THÔNG TIN MÁY =============================
kv() { printf "  ${C_CYAN}%-22s${C_RESET} %s\n" "$1" "$2"; }

get_prop() {
    if command -v getprop >/dev/null 2>&1; then
        getprop "$1" 2>/dev/null
    else
        echo ""
    fi
}

show_device_info() {
    banner
    printf "${C_BOLD}${C_MAGENTA}»»» THÔNG TIN MÁY SIÊU CHI TIẾT «««${C_RESET}\n\n"

    printf "${C_BOLD}${C_YELLOW}[ ĐỊNH DANH THIẾT BỊ ]${C_RESET}\n"
    kv "Nhà sản xuất"   "$(get_prop ro.product.manufacturer)"
    kv "Thương hiệu"    "$(get_prop ro.product.brand)"
    kv "Model"          "$(get_prop ro.product.model)"
    kv "Tên thiết bị"   "$(get_prop ro.product.device)"
    kv "Codename"       "$(get_prop ro.product.name)"
    kv "Board"          "$(get_prop ro.product.board)"
    kv "Hardware"       "$(get_prop ro.hardware)"
    kv "Serial"         "$(get_prop ro.serialno)"
    kv "Bootloader"     "$(get_prop ro.bootloader)"
    echo

    printf "${C_BOLD}${C_YELLOW}[ HỆ ĐIỀU HÀNH ]${C_RESET}\n"
    kv "Android"        "$(get_prop ro.build.version.release)"
    kv "SDK"            "$(get_prop ro.build.version.sdk)"
    kv "Security patch" "$(get_prop ro.build.version.security_patch)"
    kv "Build ID"       "$(get_prop ro.build.id)"
    kv "Build tags"     "$(get_prop ro.build.tags)"
    kv "Build type"     "$(get_prop ro.build.type)"
    kv "Fingerprint"    "$(get_prop ro.build.fingerprint)"
    kv "Kernel"         "$(uname -srm 2>/dev/null)"
    kv "ABI"            "$(get_prop ro.product.cpu.abi)"
    kv "ABI list"       "$(get_prop ro.product.cpu.abilist)"
    echo

    printf "${C_BOLD}${C_YELLOW}[ CPU ]${C_RESET}\n"
    local cpu_model cpu_cores cpu_freq_max
    cpu_model="$(awk -F: '/Hardware|model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null | sed 's/^ *//')"
    cpu_cores="$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "?")"
    cpu_freq_max="$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)"
    [ -n "$cpu_freq_max" ] && cpu_freq_max="$(( cpu_freq_max / 1000 )) MHz"
    kv "CPU"            "${cpu_model:-(không rõ)}"
    kv "Số core"        "$cpu_cores"
    kv "Xung tối đa"    "${cpu_freq_max:-N/A}"
    if [ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        kv "Governor"   "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
    fi
    echo

    printf "${C_BOLD}${C_YELLOW}[ RAM ]${C_RESET}\n"
    if [ -r /proc/meminfo ]; then
        local mt ma mf
        mt=$(awk '/MemTotal/ {printf "%.2f GB", $2/1024/1024}' /proc/meminfo)
        ma=$(awk '/MemAvailable/ {printf "%.2f GB", $2/1024/1024}' /proc/meminfo)
        mf=$(awk '/MemFree/ {printf "%.2f GB", $2/1024/1024}' /proc/meminfo)
        kv "Tổng"       "$mt"
        kv "Khả dụng"   "$ma"
        kv "Còn trống"  "$mf"
    fi
    echo

    printf "${C_BOLD}${C_YELLOW}[ STORAGE ]${C_RESET}\n"
    df -h 2>/dev/null | awk 'NR==1 || /\/data|\/sdcard|\/storage|\/system/' | head -n 10
    echo

    printf "${C_BOLD}${C_YELLOW}[ PIN ]${C_RESET}\n"
    if [ "$IS_TERMUX" = "1" ] && command -v termux-battery-status >/dev/null 2>&1; then
        termux-battery-status 2>/dev/null | sed 's/^/  /'
    elif [ -r /sys/class/power_supply/battery/capacity ]; then
        kv "Dung lượng" "$(cat /sys/class/power_supply/battery/capacity)%"
        [ -r /sys/class/power_supply/battery/status ] && \
            kv "Trạng thái" "$(cat /sys/class/power_supply/battery/status)"
        [ -r /sys/class/power_supply/battery/temp ] && \
            kv "Nhiệt độ" "$(awk '{printf "%.1f °C", $1/10}' /sys/class/power_supply/battery/temp)"
    else
        info "Không đọc được thông tin pin."
    fi
    echo

    printf "${C_BOLD}${C_YELLOW}[ MẠNG ]${C_RESET}\n"
    if command -v ip >/dev/null 2>&1; then
        ip -brief addr 2>/dev/null | sed 's/^/  /'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>/dev/null | awk '/^[a-z]/ {iface=$1} /inet / {print "  " iface ": " $2}'
    fi
    echo

    if [ "$ROOT_GRANTED" = "1" ]; then
        printf "${C_BOLD}${C_YELLOW}[ ROOT-ONLY ]${C_RESET}\n"
        kv "Uptime"  "$(uptime -p 2>/dev/null || uptime)"
        kv "SELinux" "$(runx getenforce 2>/dev/null)"
    fi

    press_enter
}

# ========================= DUYỆT APP ================================
list_apps() {
    banner
    printf "${C_BOLD}${C_MAGENTA}»»» DANH SÁCH ỨNG DỤNG «««${C_RESET}\n\n"

    if ! command -v pm >/dev/null 2>&1; then
        err "Không tìm thấy lệnh 'pm'. Có thể bạn không ở Termux/Android."
        press_enter; return
    fi

    local inc_sys=0
    if ask_yn "Bao gồm ứng dụng hệ thống?" "N"; then inc_sys=1; fi

    local flag
    if [ "$inc_sys" = "1" ]; then flag="-f"; else flag="-f -3"; fi

    info "Đang tải danh sách..."
    local out
    if [ "$ROOT_GRANTED" = "1" ]; then
        out="$(su -c "pm list packages $flag" 2>/dev/null)"
    else
        out="$(pm list packages $flag 2>/dev/null)"
    fi
    if [ -z "$out" ]; then
        err "Không lấy được danh sách gói."
        press_enter; return
    fi

    # format: package:/path/base.apk=com.xxx
    local total
    total="$(printf "%s\n" "$out" | wc -l | tr -d ' ')"
    ok "Tìm thấy ${C_BOLD}$total${C_RESET} gói."
    hr

    local i=0
    printf "%s\n" "$out" | awk -F'=' '{print $NF" | "$1}' | \
      sed 's|^package:||' | \
      awk -F' \\| ' '{printf "%4d) %-50s  %s\n", NR, $1, $2}' | \
      head -n 500
    hr
    info "Hiển thị tối đa 500 dòng đầu. Gõ 'f <từ khoá>' để lọc, 'u <pkg>' để gỡ, hoặc Enter để quay lại."

    while true; do
        printf "${C_YELLOW}apps>${C_RESET} "
        read -r cmd arg rest || break
        case "$cmd" in
            "") return ;;
            f|filter)
                [ -z "$arg" ] && { warn "Dùng: f <từ khoá>"; continue; }
                printf "%s\n" "$out" | grep -i "$arg" | awk -F'=' '{print $NF" | "$1}' | \
                    sed 's|^package:||' | awk -F' \\| ' '{printf "%4d) %-50s  %s\n", NR, $1, $2}'
                ;;
            u|uninstall)
                [ -z "$arg" ] && { warn "Dùng: u <com.package>"; continue; }
                uninstall_app "$arg"
                ;;
            i|info)
                [ -z "$arg" ] && { warn "Dùng: i <com.package>"; continue; }
                if [ "$ROOT_GRANTED" = "1" ]; then
                    su -c "dumpsys package $arg" 2>/dev/null | head -n 60
                else
                    dumpsys package "$arg" 2>/dev/null | head -n 60 || \
                      warn "dumpsys cần root."
                fi
                ;;
            q|quit|exit) return ;;
            *) warn "Lệnh không hiểu. (f/u/i/q)" ;;
        esac
    done
}

uninstall_app() {
    local pkg="$1"
    printf "${C_YELLOW}Xác nhận gỡ:${C_RESET} %s\n" "$pkg"
    ask_yn "Bạn chắc chắn?" "N" || { info "Đã huỷ."; return; }

    # Thử gỡ thường trước
    if pm uninstall "$pkg" >/dev/null 2>&1; then
        ok "Đã gỡ $pkg"; return
    fi

    # User 0 (disable cho system app)
    if pm uninstall --user 0 "$pkg" >/dev/null 2>&1; then
        ok "Đã gỡ $pkg cho user hiện tại (system app bị vô hiệu)."
        return
    fi

    if [ "$ROOT_GRANTED" = "1" ]; then
        warn "App hệ thống — thử xoá bằng root..."
        if su -c "pm uninstall --user 0 $pkg" 2>/dev/null | grep -q Success; then
            ok "Đã gỡ (root, user 0): $pkg"; return
        fi
        # Xoá thẳng APK hệ thống (nguy hiểm)
        if ask_yn "Xoá APK khỏi /system? (NGUY HIỂM, có thể làm hỏng máy)" "N"; then
            local apk
            apk="$(su -c "pm path $pkg" 2>/dev/null | sed 's|^package:||')"
            if [ -n "$apk" ]; then
                su -c "mount -o remount,rw / 2>/dev/null; mount -o remount,rw /system 2>/dev/null; rm -f '$apk'"
                ok "Đã xoá APK: $apk"
                warn "Khuyến nghị khởi động lại máy."
            else
                err "Không xác định được đường dẫn APK."
            fi
        fi
    else
        err "Gỡ thất bại. Cần cấp quyền root để gỡ app hệ thống."
    fi
}

# ========================= FILE MANAGER ==============================
fm_header() {
    banner
    printf "${C_BOLD}${C_MAGENTA}»»» FILE MANAGER «««${C_RESET}\n"
    printf "  ${C_CYAN}CWD:${C_RESET} %s\n" "$PWD"
    if [ -n "$CLIPBOARD_PATH" ]; then
        printf "  ${C_CYAN}Clipboard (%s):${C_RESET} %s\n" "$CLIPBOARD_MODE" "$CLIPBOARD_PATH"
    fi
    hr
}

fm_list() {
    local use_root=""
    [ "$ROOT_GRANTED" = "1" ] && use_root="su -c"
    local listing
    if [ -n "$use_root" ] && [ ! -r "$PWD" ]; then
        listing="$(su -c "ls -lahF --color=never '$PWD'" 2>/dev/null)"
    else
        listing="$(ls -lahF --color=never "$PWD" 2>/dev/null)"
    fi
    if [ -z "$listing" ]; then
        warn "Không liệt kê được thư mục (có thể cần root)."
        return
    fi
    # Đánh số từng dòng (bỏ dòng 'total')
    printf "%s\n" "$listing" | awk '
        NR==1 && /^total/ {print "   " $0; next}
        { printf "%3d) %s\n", ++i, $0 }
    '
}

fm_pick() {
    # lấy tên file theo số thứ tự
    local n="$1" listing
    listing="$(ls -A1 "$PWD" 2>/dev/null)"
    [ "$ROOT_GRANTED" = "1" ] && [ -z "$listing" ] && \
        listing="$(su -c "ls -A1 '$PWD'" 2>/dev/null)"
    printf "%s\n" "$listing" | awk -v n="$n" 'NR==n{print; exit}'
}

file_manager() {
    cd "${HOME:-/}" 2>/dev/null || cd / || return
    local sel target full

    while true; do
        fm_header
        fm_list
        hr
        cat <<EOF
  ${C_BOLD}Lệnh:${C_RESET}
    ${C_GREEN}cd <path|số>${C_RESET}    vào thư mục        ${C_GREEN}..${C_RESET}   lên cha
    ${C_GREEN}open <số>${C_RESET}       xem file (less)    ${C_GREEN}stat <số>${C_RESET}  chi tiết
    ${C_GREEN}rn <số>${C_RESET}         đổi tên            ${C_GREEN}rm <số>${C_RESET}    xoá
    ${C_GREEN}cp <số>${C_RESET}         copy vào clipboard ${C_GREEN}mv <số>${C_RESET}    cut vào clipboard
    ${C_GREEN}paste${C_RESET}           dán vào cwd        ${C_GREEN}mkdir <tên>${C_RESET}
    ${C_GREEN}touch <tên>${C_RESET}     tạo file rỗng      ${C_GREEN}find <kw>${C_RESET}  tìm tên
    ${C_GREEN}du${C_RESET}              dung lượng cwd     ${C_GREEN}q${C_RESET}         quay lại
EOF
        printf "${C_YELLOW}fm>${C_RESET} "
        read -r cmd arg rest || return
        case "$cmd" in
            "") continue ;;
            cd)
                if [ -z "$arg" ]; then cd "${HOME:-/}"; continue; fi
                if [ "$arg" = ".." ]; then cd ..; continue; fi
                if [[ "$arg" =~ ^[0-9]+$ ]]; then
                    target="$(fm_pick "$arg")"
                    [ -z "$target" ] && { warn "Không tìm thấy mục #$arg"; press_enter; continue; }
                    full="$PWD/$target"
                else
                    full="$arg"
                fi
                if [ -d "$full" ]; then
                    cd "$full" || { err "Không vào được $full"; press_enter; }
                else
                    warn "Không phải thư mục."; press_enter
                fi
                ;;
            open)
                target="$(fm_pick "${arg:-0}")"
                [ -z "$target" ] && { warn "Chọn số hợp lệ"; press_enter; continue; }
                full="$PWD/$target"
                if [ "$ROOT_GRANTED" = "1" ] && [ ! -r "$full" ]; then
                    su -c "cat '$full'" 2>/dev/null | ${PAGER:-less}
                else
                    ${PAGER:-less} "$full" 2>/dev/null || cat "$full"
                fi
                ;;
            stat)
                target="$(fm_pick "${arg:-0}")"
                [ -z "$target" ] && { warn "Chọn số hợp lệ"; press_enter; continue; }
                full="$PWD/$target"
                if [ "$ROOT_GRANTED" = "1" ]; then
                    su -c "stat '$full'"
                else
                    stat "$full" 2>/dev/null || err "Không stat được."
                fi
                press_enter
                ;;
            rn|rename)
                target="$(fm_pick "${arg:-0}")"
                [ -z "$target" ] && { warn "Chọn số hợp lệ"; press_enter; continue; }
                printf "Tên mới cho '%s': " "$target"; read -r newname || continue
                [ -z "$newname" ] && continue
                if [ "$ROOT_GRANTED" = "1" ]; then
                    su -c "mv '$PWD/$target' '$PWD/$newname'" && ok "Đã đổi tên." || err "Lỗi."
                else
                    mv "$PWD/$target" "$PWD/$newname" && ok "Đã đổi tên." || err "Lỗi."
                fi
                press_enter
                ;;
            rm|del)
                target="$(fm_pick "${arg:-0}")"
                [ -z "$target" ] && { warn "Chọn số hợp lệ"; press_enter; continue; }
                full="$PWD/$target"
                ask_yn "Xoá VĨNH VIỄN '$target'?" "N" || { info "Huỷ."; continue; }
                if [ "$ROOT_GRANTED" = "1" ]; then
                    su -c "rm -rf '$full'" && ok "Đã xoá." || err "Lỗi."
                else
                    rm -rf "$full" && ok "Đã xoá." || err "Lỗi."
                fi
                ;;
            cp|copy)
                target="$(fm_pick "${arg:-0}")"
                [ -z "$target" ] && { warn "Chọn số hợp lệ"; press_enter; continue; }
                CLIPBOARD_PATH="$PWD/$target"
                CLIPBOARD_MODE="copy"
                ok "Đã copy: $CLIPBOARD_PATH"
                ;;
            mv|cut)
                target="$(fm_pick "${arg:-0}")"
                [ -z "$target" ] && { warn "Chọn số hợp lệ"; press_enter; continue; }
                CLIPBOARD_PATH="$PWD/$target"
                CLIPBOARD_MODE="cut"
                ok "Đã cut: $CLIPBOARD_PATH"
                ;;
            paste)
                [ -z "$CLIPBOARD_PATH" ] && { warn "Clipboard trống."; continue; }
                local base; base="$(basename "$CLIPBOARD_PATH")"
                if [ "$CLIPBOARD_MODE" = "copy" ]; then
                    if [ "$ROOT_GRANTED" = "1" ]; then
                        su -c "cp -a '$CLIPBOARD_PATH' '$PWD/$base'"
                    else
                        cp -a "$CLIPBOARD_PATH" "$PWD/$base"
                    fi
                else
                    if [ "$ROOT_GRANTED" = "1" ]; then
                        su -c "mv '$CLIPBOARD_PATH' '$PWD/$base'"
                    else
                        mv "$CLIPBOARD_PATH" "$PWD/$base"
                    fi
                    CLIPBOARD_PATH=""; CLIPBOARD_MODE=""
                fi
                ok "Đã dán vào $PWD/$base"
                ;;
            mkdir)
                [ -z "$arg" ] && { warn "Dùng: mkdir <tên>"; continue; }
                mkdir -p "$PWD/$arg" && ok "Đã tạo." || err "Lỗi."
                ;;
            touch)
                [ -z "$arg" ] && { warn "Dùng: touch <tên>"; continue; }
                : > "$PWD/$arg" && ok "Đã tạo." || err "Lỗi."
                ;;
            find)
                [ -z "$arg" ] && { warn "Dùng: find <tên>"; continue; }
                find "$PWD" -iname "*$arg*" 2>/dev/null | head -n 100
                press_enter
                ;;
            du)
                du -sh "$PWD"/* 2>/dev/null | sort -h | tail -n 30
                press_enter
                ;;
            q|quit|exit|back) return ;;
            *) warn "Lệnh không hiểu." ;;
        esac
    done
}

# ========================= ÉP XUNG / TUNING ==========================
require_root_or_return() {
    if [ "$ROOT_GRANTED" != "1" ]; then
        err "Chức năng này yêu cầu root. Hãy cấp quyền ở menu chính."
        press_enter; return 1
    fi
    return 0
}

cpu_list_governors() {
    require_root_or_return || return
    banner
    printf "${C_BOLD}${C_MAGENTA}»»» CPU GOVERNOR «««${C_RESET}\n\n"
    local i=0
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        [ -d "$d" ] || continue
        local cpu cur avail min max
        cpu="$(basename "$(dirname "$d")")"
        cur="$(su -c "cat $d/scaling_governor" 2>/dev/null)"
        avail="$(su -c "cat $d/scaling_available_governors" 2>/dev/null)"
        min="$(su -c "cat $d/scaling_min_freq" 2>/dev/null)"
        max="$(su -c "cat $d/scaling_max_freq" 2>/dev/null)"
        printf "${C_CYAN}%s${C_RESET}  gov=${C_GREEN}%s${C_RESET}  min=%s max=%s\n" \
            "$cpu" "$cur" "${min:-?}" "${max:-?}"
        printf "  avail: %s\n" "$avail"
        i=$((i+1))
    done
    [ $i -eq 0 ] && warn "Không đọc được sysfs cpufreq."
    echo
    if ask_yn "Đổi governor cho tất cả core?" "N"; then
        printf "Nhập governor (vd: performance/powersave/schedutil): "
        read -r gov
        [ -z "$gov" ] && { info "Huỷ."; press_enter; return; }
        for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
            su -c "echo $gov > $d/scaling_governor" 2>/dev/null && \
                ok "$(basename "$(dirname "$d")") -> $gov" || \
                warn "Không set được $(basename "$(dirname "$d")")"
        done
    fi
    press_enter
}

cpu_set_maxfreq() {
    require_root_or_return || return
    banner
    printf "${C_BOLD}${C_MAGENTA}»»» GIỚI HẠN XUNG TỐI ĐA «««${C_RESET}\n\n"
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        [ -d "$d" ] || continue
        local cpu avail
        cpu="$(basename "$(dirname "$d")")"
        avail="$(su -c "cat $d/scaling_available_frequencies" 2>/dev/null)"
        printf "${C_CYAN}%s${C_RESET}: %s\n" "$cpu" "${avail:-?}"
    done
    echo
    printf "Nhập xung tối đa mới (kHz, vd 1804800): "
    read -r freq
    [ -z "$freq" ] && { info "Huỷ."; press_enter; return; }
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        su -c "echo $freq > $d/scaling_max_freq" 2>/dev/null && \
            ok "$(basename "$(dirname "$d")") max=$freq" || \
            warn "Không set được $(basename "$(dirname "$d")")"
    done
    press_enter
}

io_scheduler() {
    require_root_or_return || return
    banner
    printf "${C_BOLD}${C_MAGENTA}»»» I/O SCHEDULER «««${C_RESET}\n\n"
    local any=0
    for b in /sys/block/*/queue/scheduler; do
        [ -f "$b" ] || continue
        local name cur
        name="$(echo "$b" | awk -F/ '{print $4}')"
        cur="$(su -c "cat $b" 2>/dev/null)"
        printf "${C_CYAN}%-12s${C_RESET} %s\n" "$name" "$cur"
        any=1
    done
    [ $any -eq 0 ] && { warn "Không thấy block device."; press_enter; return; }
    echo
    if ask_yn "Đổi scheduler cho tất cả block device?" "N"; then
        printf "Nhập scheduler (vd: noop/deadline/cfq/bfq/mq-deadline/none/kyber): "
        read -r s
        [ -z "$s" ] && { info "Huỷ."; press_enter; return; }
        for b in /sys/block/*/queue/scheduler; do
            su -c "echo $s > $b" 2>/dev/null && \
                ok "$(echo "$b" | awk -F/ '{print $4}') -> $s" || \
                warn "Không set được $b"
        done
    fi
    press_enter
}

gpu_info() {
    require_root_or_return || return
    banner
    printf "${C_BOLD}${C_MAGENTA}»»» GPU «««${C_RESET}\n\n"
    local found=0
    for g in /sys/class/kgsl/kgsl-3d0 /sys/class/devfreq/*gpu* /sys/kernel/gpu; do
        [ -d "$g" ] || continue
        found=1
        printf "${C_CYAN}%s${C_RESET}\n" "$g"
        for f in governor cur_freq min_freq max_freq available_frequencies available_governors gpubusy; do
            if [ -r "$g/$f" ] || su -c "test -r '$g/$f'" 2>/dev/null; then
                printf "  %-24s %s\n" "$f" "$(su -c "cat $g/$f" 2>/dev/null)"
            fi
        done
    done
    [ $found -eq 0 ] && warn "Không tìm thấy node GPU tiêu chuẩn."
    press_enter
}

drop_caches() {
    require_root_or_return || return
    if ask_yn "Sync + drop caches (giải phóng RAM đệm)?" "Y"; then
        su -c "sync; echo 3 > /proc/sys/vm/drop_caches" && ok "Đã drop caches." || err "Lỗi."
    fi
    press_enter
}

tuning_menu() {
    while true; do
        banner
        printf "${C_BOLD}${C_MAGENTA}»»» TUNING / ÉP XUNG (ROOT) «««${C_RESET}\n\n"
        cat <<EOF
  ${C_GREEN}1)${C_RESET} Xem & đổi CPU governor
  ${C_GREEN}2)${C_RESET} Giới hạn / ép xung CPU max freq
  ${C_GREEN}3)${C_RESET} I/O scheduler
  ${C_GREEN}4)${C_RESET} Thông tin GPU
  ${C_GREEN}5)${C_RESET} Sync & drop caches (giải phóng RAM)
  ${C_GREEN}6)${C_RESET} Xem nhiệt độ các zone
  ${C_GREEN}0)${C_RESET} Quay lại
EOF
        printf "\n${C_YELLOW}tune>${C_RESET} "
        read -r c || return
        case "$c" in
            1) cpu_list_governors ;;
            2) cpu_set_maxfreq ;;
            3) io_scheduler ;;
            4) gpu_info ;;
            5) drop_caches ;;
            6) show_thermals ;;
            0|q|back) return ;;
            *) warn "Chọn không hợp lệ"; sleep 1 ;;
        esac
    done
}

show_thermals() {
    banner
    printf "${C_BOLD}${C_MAGENTA}»»» THERMAL ZONES «««${C_RESET}\n\n"
    local found=0
    for z in /sys/class/thermal/thermal_zone*; do
        [ -d "$z" ] || continue
        local name temp
        name="$(cat "$z/type" 2>/dev/null || su -c "cat $z/type" 2>/dev/null)"
        temp="$(cat "$z/temp" 2>/dev/null || su -c "cat $z/temp" 2>/dev/null)"
        [ -z "$temp" ] && continue
        # một số kernel trả mC, số khác trả độ C
        if [ "$temp" -gt 1000 ] 2>/dev/null; then
            temp="$(awk "BEGIN{printf \"%.1f °C\", $temp/1000}")"
        else
            temp="${temp} °C"
        fi
        printf "  ${C_CYAN}%-25s${C_RESET} %s\n" "${name:-$(basename "$z")}" "$temp"
        found=1
    done
    [ $found -eq 0 ] && warn "Không đọc được thermal zone."
    press_enter
}

# ========================= MENU CHÍNH ================================
main_menu() {
    while true; do
        banner
        cat <<EOF
  ${C_GREEN}1)${C_RESET}  Thông tin máy (siêu chi tiết)
  ${C_GREEN}2)${C_RESET}  Ứng dụng đã cài (xem / gỡ / gỡ app hệ thống)
  ${C_GREEN}3)${C_RESET}  File manager (cd, rename, cp, mv, rm, paste...)
  ${C_GREEN}4)${C_RESET}  Tuning & Ép xung ${C_DIM}(cần root)${C_RESET}
  ${C_GREEN}5)${C_RESET}  Cấp / kiểm tra quyền ROOT
  ${C_GREEN}6)${C_RESET}  Cập nhật Termux (pkg update & upgrade)
  ${C_GREEN}7)${C_RESET}  Shell root ${C_DIM}(mở su)${C_RESET}
  ${C_GREEN}0)${C_RESET}  Thoát
EOF
        printf "\n${C_YELLOW}Chọn:${C_RESET} "
        read -r choice || exit 0
        case "$choice" in
            1) show_device_info ;;
            2) list_apps ;;
            3) file_manager ;;
            4) tuning_menu ;;
            5) ask_for_root; press_enter ;;
            6)
                if [ "$IS_TERMUX" = "1" ]; then
                    yes | pkg update -y && yes | pkg upgrade -y
                else
                    warn "Không phải Termux."
                fi
                press_enter
                ;;
            7)
                if [ "$IS_ROOT" = "1" ]; then su; else err "Máy không có su."; press_enter; fi
                ;;
            0|q|exit) ok "Tạm biệt!"; exit 0 ;;
            *) warn "Chọn không hợp lệ"; sleep 1 ;;
        esac
    done
}

# ============================ BẮT LỖI ================================
on_error() {
    local ec=$?
    [ $ec -eq 0 ] && return
    err "Lỗi (exit=$ec) ở dòng ${BASH_LINENO[0]:-?}: ${BASH_COMMAND:-?}"
}
trap on_error ERR
trap 'echo; warn "Đã nhận Ctrl+C. Về menu chính..."; ' INT

# ============================ KHỞI CHẠY ==============================
main() {
    detect_env
    bootstrap_deps
    banner
    info "Chào mừng đến với ${C_BOLD}$SCRIPT_NAME v$SCRIPT_VER${C_RESET}"
    if [ "$IS_ROOT" = "1" ] && [ "$ROOT_GRANTED" = "0" ]; then
        ask_for_root
    fi
    press_enter
    main_menu
}

main "$@"
