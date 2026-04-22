#!/usr/bin/env bash
# =====================================================================
#  TERMUX SUPER TOOLKIT  v2.0  -  by v0
#  Chạy trực tiếp:
#     bash <(curl -fsSL https://your.url/termux-toolkit.sh)
#  hoặc:
#     curl -fsSL https://your.url/termux-toolkit.sh | bash
# =====================================================================
#  - Giao diện CLI đẹp, box-drawing, màu sắc, gọn gàng
#  - Tự phát hiện + tự xin quyền ROOT (su) ngay khi khởi chạy
#  - Fix triệt để bug "uid=0 nhưng báo không root"
#  - Tự cài phụ thuộc thiếu (pkg / apt)
#  - Xem thông tin máy SIÊU chi tiết (CPU/RAM/ROM/PIN/NHIỆT/MẠNG/SIM…)
#  - Tuổi thọ PIN (design vs current capacity), tuổi máy (build date)
#  - Quản lý ứng dụng (kể cả hệ thống) – liệt kê / gỡ / disable
#  - File Manager kiểu ZArchiver (cd/ls/cp/mv/rm/rename/paste/mkdir)
#  - Ép xung CPU / GPU / I/O scheduler / Governor (cần root)
#  - Quản lý nhiệt, wakelock, logcat, dmesg, build.prop
# =====================================================================

# ----- Bash guard: đảm bảo đang chạy bằng bash ----------------------
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Vui lòng chạy script bằng bash, không phải sh/dash." >&2
    exit 1
fi

set -u
umask 022
export LC_ALL="${LC_ALL:-C.UTF-8}"
export LANG="${LANG:-C.UTF-8}"

# ============================= MÀU SẮC ==============================
if [ -t 1 ]; then
    C_RESET=$'\e[0m'
    C_BOLD=$'\e[1m'
    C_DIM=$'\e[2m'
    C_ITAL=$'\e[3m'
    C_UNDL=$'\e[4m'
    C_BLINK=$'\e[5m'
    C_INV=$'\e[7m'

    C_BLACK=$'\e[30m';  C_RED=$'\e[31m';    C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m';   C_MAGENTA=$'\e[35m'
    C_CYAN=$'\e[36m';   C_WHITE=$'\e[37m'
    C_BRED=$'\e[91m';   C_BGREEN=$'\e[92m'; C_BYELLOW=$'\e[93m'
    C_BBLUE=$'\e[94m';  C_BMAG=$'\e[95m';   C_BCYAN=$'\e[96m'
    C_BWHITE=$'\e[97m'

    C_BG_BLUE=$'\e[44m'; C_BG_CYAN=$'\e[46m'; C_BG_DARK=$'\e[100m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_ITAL=""; C_UNDL=""; C_BLINK=""; C_INV=""
    C_BLACK=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_MAGENTA=""
    C_CYAN=""; C_WHITE=""; C_BRED=""; C_BGREEN=""; C_BYELLOW=""; C_BBLUE=""
    C_BMAG=""; C_BCYAN=""; C_BWHITE=""; C_BG_BLUE=""; C_BG_CYAN=""; C_BG_DARK=""
fi

# Ký tự box-drawing (Unicode)
BOX_TL="╭"; BOX_TR="╮"; BOX_BL="╰"; BOX_BR="╯"
BOX_H="─";  BOX_V="│";  BOX_VR="├"; BOX_VL="┤"
BOX_DH="═"; BOX_DTL="╔"; BOX_DTR="╗"; BOX_DBL="╚"; BOX_DBR="╝"; BOX_DV="║"
ICON_OK="${C_GREEN}✔${C_RESET}"
ICON_ERR="${C_RED}✖${C_RESET}"
ICON_WARN="${C_YELLOW}⚠${C_RESET}"
ICON_INFO="${C_CYAN}ℹ${C_RESET}"
ICON_ARROW="${C_BMAG}➜${C_RESET}"
ICON_STAR="${C_BYELLOW}★${C_RESET}"
ICON_ROOT="${C_BRED}#${C_RESET}"
ICON_USER="${C_BGREEN}\$${C_RESET}"

# ============================ BIẾN TOÀN CỤC ==========================
SCRIPT_NAME="TERMUX SUPER TOOLKIT"
SCRIPT_VER="2.0.0"
SCRIPT_AUTHOR="v0"

IS_TERMUX=0
IS_ANDROID=0
IS_ROOT=0          # 1 nếu uid hiện tại = 0
ROOT_AVAILABLE=0   # 1 nếu có binary su
ROOT_GRANTED=0     # 1 nếu user đồng ý dùng su (hoặc đã là root)
SU_BIN=""          # đường dẫn binary su
TERM_COLS=80
TERM_ROWS=24
CLIPBOARD_PATH=""
CLIPBOARD_MODE=""

# ============================ TIỆN ÍCH ==============================
term_size() {
    TERM_COLS="$(tput cols 2>/dev/null || echo 80)"
    TERM_ROWS="$(tput lines 2>/dev/null || echo 24)"
    [ "$TERM_COLS" -lt 40 ] && TERM_COLS=40
}

repeat_char() {
    local ch="$1" n="$2" out=""
    local i=0
    while [ "$i" -lt "$n" ]; do out="${out}${ch}"; i=$((i+1)); done
    printf '%s' "$out"
}

# In 1 dòng chính giữa trong khung rộng n
center_text() {
    local text="$1" width="$2"
    # loại bỏ mã màu để đo độ dài
    local plain
    plain="$(printf '%s' "$text" | sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g')"
    local len=${#plain}
    [ "$len" -gt "$width" ] && { printf '%s' "$text"; return; }
    local pad=$(( (width - len) / 2 ))
    local rest=$(( width - len - pad ))
    printf '%*s%s%*s' "$pad" "" "$text" "$rest" ""
}

hr() {
    term_size
    printf '%s' "$C_DIM"
    repeat_char "$BOX_H" "$TERM_COLS"
    printf '%s\n' "$C_RESET"
}

hr_double() {
    term_size
    printf '%s' "$C_CYAN"
    repeat_char "$BOX_DH" "$TERM_COLS"
    printf '%s\n' "$C_RESET"
}

msg()   { printf '%s %s\n' "$ICON_INFO" "$*"; }
ok()    { printf '%s %s\n' "$ICON_OK" "$*"; }
warn()  { printf '%s %s\n' "$ICON_WARN" "$*"; }
err()   { printf '%s %s\n' "$ICON_ERR" "$*" >&2; }
die()   { err "$*"; exit 1; }

pause() {
    printf '\n%s%sNhấn Enter để tiếp tục...%s' "$C_DIM" "$C_ITAL" "$C_RESET"
    # shellcheck disable=SC2162
    read _dummy
}

confirm() {
    local prompt="${1:-Bạn có chắc chắn không?}"
    local default="${2:-N}"
    local hint="[y/N]"
    [ "$default" = "Y" ] && hint="[Y/n]"
    local ans=""
    printf '%s %s %s%s%s ' "$ICON_WARN" "$prompt" "$C_DIM" "$hint" "$C_RESET"
    # shellcheck disable=SC2162
    read ans || ans=""
    ans="${ans:-$default}"
    case "$ans" in
        y|Y|yes|YES|Yes) return 0 ;;
        *) return 1 ;;
    esac
}

# run_as_root <cmd...>  – chạy với quyền root nếu có, nếu không thì báo lỗi
run_as_root() {
    if [ "$IS_ROOT" = "1" ]; then
        "$@"
        return $?
    fi
    if [ "$ROOT_GRANTED" = "1" ] && [ -n "$SU_BIN" ]; then
        # build lệnh thành chuỗi shell-quoted
        local cmd=""
        local arg
        for arg in "$@"; do
            cmd+=" $(printf '%q' "$arg")"
        done
        "$SU_BIN" -c "$cmd"
        return $?
    fi
    err "Lệnh cần quyền root, nhưng chưa có su hoặc chưa được cấp."
    return 1
}

# đọc file cần root
root_cat() {
    local f="$1"
    if [ -r "$f" ]; then
        cat "$f" 2>/dev/null
    elif [ "$ROOT_GRANTED" = "1" ] || [ "$IS_ROOT" = "1" ]; then
        run_as_root cat "$f" 2>/dev/null
    else
        return 1
    fi
}

# ============================ BANNER =================================
banner() {
    clear 2>/dev/null || printf '\033[H\033[2J'
    term_size
    local w=$TERM_COLS
    [ "$w" -gt 78 ] && w=78

    local top="" bot=""
    top="$(repeat_char "$BOX_DH" "$((w-2))")"
    bot="$(repeat_char "$BOX_DH" "$((w-2))")"

    printf '%s%s%s%s%s\n' "$C_BCYAN" "$BOX_DTL" "$top" "$BOX_DTR" "$C_RESET"

    local line1 line2 line3 line4
    line1="$(center_text "${C_BOLD}${C_BWHITE}${SCRIPT_NAME}${C_RESET}${C_BCYAN}" "$((w-2))")"
    line2="$(center_text "${C_DIM}v${SCRIPT_VER}  –  by ${SCRIPT_AUTHOR}${C_RESET}${C_BCYAN}" "$((w-2))")"

    local mode="USER"
    local mode_color="$C_YELLOW"
    if [ "$IS_ROOT" = "1" ]; then
        mode="ROOT (uid=0)"; mode_color="$C_BRED"
    elif [ "$ROOT_GRANTED" = "1" ]; then
        mode="ROOT via su"; mode_color="$C_BGREEN"
    elif [ "$ROOT_AVAILABLE" = "1" ]; then
        mode="su sẵn có (chưa dùng)"; mode_color="$C_BYELLOW"
    fi
    line3="$(center_text "${mode_color}● ${mode}${C_RESET}${C_BCYAN}  ${C_DIM}|${C_RESET}${C_BCYAN}  $(date '+%Y-%m-%d %H:%M:%S')" "$((w-2))")"

    local envtag="Linux"
    [ "$IS_TERMUX" = "1" ] && envtag="Termux"
    [ "$IS_ANDROID" = "1" ] && envtag="${envtag} / Android"
    line4="$(center_text "${C_CYAN}${envtag}${C_RESET}${C_BCYAN}" "$((w-2))")"

    printf '%s%s%s%s%s\n' "$C_BCYAN" "$BOX_DV" "$line1" "$BOX_DV" "$C_RESET"
    printf '%s%s%s%s%s\n' "$C_BCYAN" "$BOX_DV" "$line2" "$BOX_DV" "$C_RESET"
    printf '%s%s%s%s%s\n' "$C_BCYAN" "$BOX_DV" "$line3" "$BOX_DV" "$C_RESET"
    printf '%s%s%s%s%s\n' "$C_BCYAN" "$BOX_DV" "$line4" "$BOX_DV" "$C_RESET"
    printf '%s%s%s%s%s\n' "$C_BCYAN" "$BOX_DBL" "$bot" "$BOX_DBR" "$C_RESET"
}

# Vẽ box đơn quanh 1 tiêu đề
box_title() {
    local title="$1"
    term_size
    local w=$TERM_COLS
    [ "$w" -gt 78 ] && w=78
    local inner=$((w-2))
    local top bot
    top="$(repeat_char "$BOX_H" "$inner")"
    bot="$(repeat_char "$BOX_H" "$inner")"
    printf '%s%s%s%s%s\n' "$C_CYAN" "$BOX_TL" "$top" "$BOX_TR" "$C_RESET"
    local mid
    mid="$(center_text "${C_BOLD}${C_BWHITE}${title}${C_RESET}${C_CYAN}" "$inner")"
    printf '%s%s%s%s%s\n' "$C_CYAN" "$BOX_V" "$mid" "$BOX_V" "$C_RESET"
    printf '%s%s%s%s%s\n' "$C_CYAN" "$BOX_BL" "$bot" "$BOX_BR" "$C_RESET"
}

# In 1 dòng key/value đẹp
kv() {
    local key="$1" val="$2"
    printf '  %s%-22s%s %s%s%s\n' "$C_CYAN" "$key" "$C_RESET" "$C_BWHITE" "$val" "$C_RESET"
}

section() {
    printf '\n%s%s %s %s%s\n' "$C_BMAG" "$BOX_VR$BOX_H" "$1" "$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H$BOX_H" "$C_RESET"
}

# ======================== PHÁT HIỆN MÔI TRƯỜNG =======================
detect_env() {
    # Termux?
    if [ -d "/data/data/com.termux" ] || [ -n "${TERMUX_VERSION:-}" ] || [ -n "${PREFIX:-}" ] && echo "${PREFIX:-}" | grep -q "com.termux"; then
        IS_TERMUX=1
    fi
    # Android?
    if [ -f "/system/build.prop" ] || [ -d "/system/app" ] || [ "${IS_TERMUX}" = "1" ]; then
        IS_ANDROID=1
    fi

    # --- ROOT detection ROBUST ---
    # Phương pháp 1: id -u
    local uid="unknown"
    if command -v id >/dev/null 2>&1; then
        uid="$(id -u 2>/dev/null || echo unknown)"
    fi
    if [ "$uid" = "0" ]; then
        IS_ROOT=1
    fi
    # Phương pháp 2: $EUID / $UID
    if [ "$IS_ROOT" != "1" ]; then
        if [ "${EUID:-x}" = "0" ] || [ "${UID:-x}" = "0" ]; then
            IS_ROOT=1
        fi
    fi
    # Phương pháp 3: whoami
    if [ "$IS_ROOT" != "1" ]; then
        local wh
        wh="$(whoami 2>/dev/null || echo "")"
        [ "$wh" = "root" ] && IS_ROOT=1
    fi
    # Phương pháp 4: ghi thử /data (chỉ root mới ghi được)
    if [ "$IS_ROOT" != "1" ] && [ -d /data ]; then
        if ( : >/data/.__v0_root_probe__ ) 2>/dev/null; then
            rm -f /data/.__v0_root_probe__ 2>/dev/null
            IS_ROOT=1
        fi
    fi

    if [ "$IS_ROOT" = "1" ]; then
        ROOT_GRANTED=1
        SU_BIN=""  # không cần su
    fi

    # Tìm binary su (Magisk / KernelSU / APatch / cũ)
    local candidates=(
        "/system/bin/su"
        "/system/xbin/su"
        "/sbin/su"
        "/su/bin/su"
        "/magisk/.core/bin/su"
        "/debug_ramdisk/su"
        "/data/adb/magisk/su"
        "/data/adb/ksu/bin/su"
        "/data/adb/ap/bin/su"
    )
    if [ "$IS_ROOT" != "1" ]; then
        # ưu tiên which
        local w
        w="$(command -v su 2>/dev/null || true)"
        [ -n "$w" ] && [ -x "$w" ] && SU_BIN="$w"
        if [ -z "$SU_BIN" ]; then
            for c in "${candidates[@]}"; do
                if [ -x "$c" ]; then SU_BIN="$c"; break; fi
            done
        fi
        [ -n "$SU_BIN" ] && ROOT_AVAILABLE=1
    fi
}

# Xác nhận cấp root ngay sau banner
request_root() {
    if [ "$IS_ROOT" = "1" ]; then
        ok "Đang chạy với quyền ${C_BRED}ROOT${C_RESET} (uid=0). Bỏ qua bước xin su."
        ROOT_GRANTED=1
        sleep 0.6
        return 0
    fi
    if [ "$ROOT_AVAILABLE" != "1" ]; then
        warn "Không tìm thấy binary ${C_BOLD}su${C_RESET}. Máy có vẻ chưa root."
        warn "Các chức năng cần root sẽ bị vô hiệu."
        ROOT_GRANTED=0
        sleep 0.8
        return 0
    fi

    box_title "YÊU CẦU QUYỀN ROOT"
    printf '  %sPhát hiện binary su tại:%s %s%s%s\n' "$C_CYAN" "$C_RESET" "$C_BYELLOW" "$SU_BIN" "$C_RESET"
    printf '  %sĐồng ý cấp TOÀN QUYỀN root cho toolkit này?%s\n' "$C_BOLD" "$C_RESET"
    printf '  %s(Popup Magisk/KernelSU sẽ hiện ra, hãy bấm Grant/Allow)%s\n\n' "$C_DIM" "$C_RESET"

    if confirm "Cấp quyền root và tự khởi chạy các lệnh cần root?" "Y"; then
        # Thử chạy một lệnh nhỏ để trigger popup
        msg "Đang yêu cầu su... (xem popup trên màn hình)"
        local out
        out="$("$SU_BIN" -c 'id -u' 2>/dev/null | tr -d '\r\n ')"
        if [ "$out" = "0" ]; then
            ROOT_GRANTED=1
            ok "Đã được cấp quyền root qua ${C_BYELLOW}${SU_BIN}${C_RESET}."
            # kiểm tra mount hệ thống có đang RO hay RW
            local mntinfo
            mntinfo="$("$SU_BIN" -c 'mount | grep " /system "' 2>/dev/null || true)"
            [ -n "$mntinfo" ] && printf '  %s%s%s\n' "$C_DIM" "$mntinfo" "$C_RESET"
        else
            err "Yêu cầu root BỊ TỪ CHỐI hoặc su không phản hồi."
            warn "Các chức năng nâng cao (ép xung, xoá app hệ thống, ...) sẽ bị khoá."
            ROOT_GRANTED=0
        fi
    else
        warn "Bạn đã từ chối cấp root. Chạy ở chế độ USER."
        ROOT_GRANTED=0
    fi
    sleep 0.8
}

# ======================== CÀI ĐẶT PHỤ THUỘC ==========================
ensure_pkg() {
    # ensure_pkg <cmd> [pkg_name]
    local cmd="$1"
    local pkg="${2:-$1}"
    command -v "$cmd" >/dev/null 2>&1 && return 0

    if [ "$IS_TERMUX" = "1" ] && command -v pkg >/dev/null 2>&1; then
        msg "Đang cài ${C_BYELLOW}${pkg}${C_RESET} qua pkg..."
        pkg install -y "$pkg" >/dev/null 2>&1 && return 0
    fi
    if command -v apt-get >/dev/null 2>&1; then
        msg "Đang cài ${C_BYELLOW}${pkg}${C_RESET} qua apt-get..."
        apt-get install -y "$pkg" >/dev/null 2>&1 && return 0
    fi
    warn "Không thể tự cài ${pkg}. Một số chức năng có thể hạn chế."
    return 1
}

bootstrap_deps() {
    # những thứ nên có, không bắt buộc
    local deps=(awk sed grep tput date stat find du df free uptime)
    local miss=()
    local d
    for d in "${deps[@]}"; do
        command -v "$d" >/dev/null 2>&1 || miss+=("$d")
    done
    if [ "${#miss[@]}" -gt 0 ]; then
        if [ "$IS_TERMUX" = "1" ]; then
            msg "Thiếu các tool: ${miss[*]} – thử cài coreutils/procps/ncurses-utils"
            pkg install -y coreutils procps ncurses-utils gawk >/dev/null 2>&1 || true
        fi
    fi
}

# =========================== THÔNG TIN MÁY ===========================
getprop_safe() {
    local key="$1"
    if command -v getprop >/dev/null 2>&1; then
        getprop "$key" 2>/dev/null
    else
        # tự đọc build.prop
        grep -E "^${key}=" /system/build.prop 2>/dev/null | head -n1 | cut -d= -f2-
    fi
}

human_kb() {
    local kb="$1"
    [ -z "$kb" ] || [ "$kb" = "0" ] && { echo "-"; return; }
    awk -v k="$kb" 'BEGIN{
        split("KB MB GB TB", u);
        v=k; i=1;
        while (v>=1024 && i<4){ v/=1024; i++ }
        printf("%.2f %s", v, u[i]);
    }'
}

human_bytes() {
    local b="$1"
    [ -z "$b" ] || [ "$b" = "0" ] && { echo "-"; return; }
    awk -v b="$b" 'BEGIN{
        split("B KB MB GB TB PB", u);
        v=b; i=1;
        while (v>=1024 && i<6){ v/=1024; i++ }
        printf("%.2f %s", v, u[i]);
    }'
}

show_system_info() {
    banner
    box_title "THÔNG TIN MÁY – SIÊU CHI TIẾT"

    # ==== IDENTITY ====
    section "Thiết bị"
    kv "Thương hiệu"     "$(getprop_safe ro.product.brand)"
    kv "Nhà sản xuất"    "$(getprop_safe ro.product.manufacturer)"
    kv "Model"           "$(getprop_safe ro.product.model)"
    kv "Device"          "$(getprop_safe ro.product.device)"
    kv "Board"           "$(getprop_safe ro.product.board)"
    kv "Hardware"        "$(getprop_safe ro.hardware)"
    kv "Platform"        "$(getprop_safe ro.board.platform)"
    kv "Serial"          "$(getprop_safe ro.serialno)"

    # ==== ANDROID / BUILD ====
    section "Hệ điều hành"
    kv "Android"         "$(getprop_safe ro.build.version.release) (SDK $(getprop_safe ro.build.version.sdk))"
    kv "Security patch"  "$(getprop_safe ro.build.version.security_patch)"
    kv "Build ID"        "$(getprop_safe ro.build.id)"
    kv "Build type"      "$(getprop_safe ro.build.type) / $(getprop_safe ro.build.tags)"
    kv "Kernel"          "$(uname -srm 2>/dev/null)"
    kv "Bootloader"      "$(getprop_safe ro.bootloader)"
    kv "ABI"             "$(getprop_safe ro.product.cpu.abi)"
    kv "Fingerprint"     "$(getprop_safe ro.build.fingerprint)"

    # ==== TUỔI MÁY ====
    section "Tuổi máy (ước lượng)"
    local build_utc build_date
    build_utc="$(getprop_safe ro.build.date.utc)"
    build_date="$(getprop_safe ro.build.date)"
    kv "Build date"      "$build_date"
    if [ -n "$build_utc" ] && [ "$build_utc" -gt 0 ] 2>/dev/null; then
        local now age_days age_years
        now="$(date +%s)"
        age_days=$(( (now - build_utc) / 86400 ))
        age_years="$(awk -v d="$age_days" 'BEGIN{printf "%.2f", d/365.25}')"
        kv "Build UTC"       "$build_utc ($(date -d "@$build_utc" 2>/dev/null || echo ''))"
        kv "Tuổi firmware"   "${age_days} ngày  (~${age_years} năm)"
    fi
    # Tuổi dựa trên /data
    if [ -d /data ]; then
        local data_birth
        data_birth="$(stat -c %Y /data 2>/dev/null || echo 0)"
        if [ "$data_birth" != "0" ]; then
            local d_days
            d_days=$(( ($(date +%s) - data_birth) / 86400 ))
            kv "Tuổi /data (~)"  "${d_days} ngày"
        fi
    fi

    # ==== CPU ====
    section "CPU"
    local cpu_model cpu_cores cpu_freq
    cpu_model="$(grep -m1 'Hardware' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //')"
    [ -z "$cpu_model" ] && cpu_model="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //')"
    cpu_cores="$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo ?)"
    kv "Chip"            "${cpu_model:-$(getprop_safe ro.soc.model)}"
    kv "SoC"             "$(getprop_safe ro.soc.manufacturer) / $(getprop_safe ro.soc.model)"
    kv "Số nhân"         "$cpu_cores"
    kv "Kiến trúc"       "$(uname -m 2>/dev/null)"

    # Frequency từng nhân
    local i=0
    while [ -d "/sys/devices/system/cpu/cpu$i" ]; do
        local cur max min gov
        cur="$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq" 2>/dev/null || echo 0)"
        max="$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo 0)"
        min="$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_min_freq" 2>/dev/null || echo 0)"
        gov="$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" 2>/dev/null || echo -)"
        if [ "$max" != "0" ]; then
            local cur_mhz max_mhz min_mhz
            cur_mhz=$((cur/1000)); max_mhz=$((max/1000)); min_mhz=$((min/1000))
            kv "CPU$i"          "${cur_mhz} MHz  (min ${min_mhz} / max ${max_mhz})  gov=${gov}"
        fi
        i=$((i+1))
        [ "$i" -gt 32 ] && break
    done

    # ==== GPU ====
    section "GPU"
    local gpu_model gpu_cur gpu_max
    gpu_model="$(getprop_safe ro.hardware.egl)"
    kv "GPU (egl)"       "${gpu_model:--}"
    for gd in /sys/class/kgsl/kgsl-3d0 /sys/devices/platform/mali /sys/class/devfreq/*gpu*; do
        [ -e "$gd" ] || continue
        gpu_cur="$(cat "$gd/cur_freq" 2>/dev/null || cat "$gd/gpuclk" 2>/dev/null || echo -)"
        gpu_max="$(cat "$gd/max_freq" 2>/dev/null || cat "$gd/max_gpuclk" 2>/dev/null || echo -)"
        kv "$(basename "$gd")"  "cur=${gpu_cur}  max=${gpu_max}"
        break
    done

    # ==== RAM ====
    section "Bộ nhớ RAM"
    if [ -r /proc/meminfo ]; then
        local mt ma mf sw st
        mt="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
        ma="$(awk '/MemAvailable/{print $2}' /proc/meminfo)"
        mf="$(awk '/MemFree/{print $2}' /proc/meminfo)"
        st="$(awk '/SwapTotal/{print $2}' /proc/meminfo)"
        sw="$(awk '/SwapFree/{print $2}' /proc/meminfo)"
        kv "RAM tổng"        "$(human_kb "$mt")"
        kv "RAM khả dụng"    "$(human_kb "$ma")"
        kv "RAM trống"       "$(human_kb "$mf")"
        kv "Swap tổng"       "$(human_kb "$st")"
        kv "Swap trống"      "$(human_kb "$sw")"
    fi

    # ==== STORAGE ====
    section "Bộ nhớ trong / Thẻ nhớ"
    if command -v df >/dev/null 2>&1; then
        df -h 2>/dev/null | awk 'NR==1 || /\/data|\/storage|\/sdcard|\/system|\/mnt/' | sed "s/^/  ${C_DIM}/;s/\$/${C_RESET}/"
    fi

    # ==== PIN ====
    section "PIN & Tuổi thọ PIN"
    local bpath=""
    for p in /sys/class/power_supply/battery /sys/class/power_supply/Battery /sys/class/power_supply/BAT0; do
        [ -d "$p" ] && bpath="$p" && break
    done
    if [ -n "$bpath" ]; then
        local cap status health tech volt temp cyc
        cap="$(cat "$bpath/capacity" 2>/dev/null || echo -)"
        status="$(cat "$bpath/status" 2>/dev/null || echo -)"
        health="$(cat "$bpath/health" 2>/dev/null || echo -)"
        tech="$(cat "$bpath/technology" 2>/dev/null || echo -)"
        volt="$(cat "$bpath/voltage_now" 2>/dev/null || echo 0)"
        temp="$(cat "$bpath/temp" 2>/dev/null || echo 0)"
        cyc="$(cat "$bpath/cycle_count" 2>/dev/null || echo -)"
        kv "Trạng thái"      "$status"
        kv "Sức khoẻ"        "$health"
        kv "Công nghệ"       "$tech"
        kv "Mức pin"         "${cap}%"
        [ "$volt" != "0" ] && kv "Điện áp"      "$(awk -v v="$volt" 'BEGIN{printf "%.3f V", v/1000000}')"
        [ "$temp" != "0" ] && kv "Nhiệt độ pin" "$(awk -v t="$temp" 'BEGIN{printf "%.1f °C", t/10}')"
        kv "Chu kỳ sạc"      "$cyc"

        # Dung lượng thiết kế vs hiện tại
        local design_uah full_uah now_uah
        design_uah="$(cat "$bpath/charge_full_design" 2>/dev/null || cat "$bpath/energy_full_design" 2>/dev/null || echo 0)"
        full_uah="$(cat "$bpath/charge_full" 2>/dev/null || cat "$bpath/energy_full" 2>/dev/null || echo 0)"
        now_uah="$(cat "$bpath/charge_now" 2>/dev/null || cat "$bpath/energy_now" 2>/dev/null || echo 0)"
        if [ "$design_uah" != "0" ]; then
            kv "Dung lượng TK"   "$(awk -v v="$design_uah" 'BEGIN{printf "%.0f mAh", v/1000}')"
        fi
        if [ "$full_uah" != "0" ]; then
            kv "Dung lượng hiện" "$(awk -v v="$full_uah" 'BEGIN{printf "%.0f mAh", v/1000}')"
        fi
        if [ "$design_uah" != "0" ] && [ "$full_uah" != "0" ]; then
            local wear health_pct
            health_pct="$(awk -v d="$design_uah" -v f="$full_uah" 'BEGIN{printf "%.1f", (f/d)*100}')"
            wear="$(awk -v d="$design_uah" -v f="$full_uah" 'BEGIN{printf "%.1f", (1-f/d)*100}')"
            kv "Sức khoẻ pin (%)" "${health_pct}%"
            kv "Hao mòn pin (%)"  "${wear}%"
        fi
    else
        kv "Pin"             "(không tìm thấy /sys/class/power_supply)"
    fi

    # ==== NHIỆT ====
    section "Cảm biến nhiệt"
    local tz
    local shown=0
    for tz in /sys/class/thermal/thermal_zone*; do
        [ -e "$tz/type" ] || continue
        local t ty
        ty="$(cat "$tz/type" 2>/dev/null)"
        t="$(cat "$tz/temp" 2>/dev/null || echo 0)"
        if [ "$t" != "0" ]; then
            local tc
            if [ "$t" -gt 1000 ]; then tc="$(awk -v t="$t" 'BEGIN{printf "%.1f", t/1000}')"
            else tc="$t"; fi
            kv "$ty" "${tc} °C"
            shown=$((shown+1))
            [ "$shown" -ge 10 ] && break
        fi
    done

    # ==== MẠNG ====
    section "Mạng"
    kv "Hostname"        "$(uname -n 2>/dev/null)"
    if command -v ip >/dev/null 2>&1; then
        ip -brief addr 2>/dev/null | awk '{printf "  '"${C_CYAN}"'%-10s'"${C_RESET}"' %-20s %s\n", $1, $2, $3}'
    elif command -v ifconfig >/dev/null 2>&1; then
        ifconfig 2>/dev/null | grep -E "inet |UP|flags" | sed "s/^/  ${C_DIM}/;s/\$/${C_RESET}/"
    fi

    # ==== UPTIME / LOAD ====
    section "Hiệu năng thời gian thực"
    kv "Uptime"          "$(uptime -p 2>/dev/null || uptime)"
    kv "Load average"    "$(cat /proc/loadavg 2>/dev/null)"
    kv "Số tiến trình"   "$(ls /proc 2>/dev/null | grep -c '^[0-9]')"

    # ==== SELINUX ====
    section "Bảo mật"
    kv "SELinux"         "$(getenforce 2>/dev/null || echo '-')"
    kv "Root status"     "$(if [ "$IS_ROOT" = "1" ]; then echo "ROOT (uid=0)"; elif [ "$ROOT_GRANTED" = "1" ]; then echo "ROOT via su"; else echo "USER"; fi)"

    pause
}

# =========================== QUẢN LÝ APP =============================
list_apps() {
    banner
    box_title "QUẢN LÝ ỨNG DỤNG"

    if ! command -v pm >/dev/null 2>&1; then
        err "Không tìm thấy lệnh ${C_BOLD}pm${C_RESET}. Cần chạy trong môi trường Android."
        pause; return
    fi

    local show_system=0
    if confirm "Hiển thị CẢ ứng dụng hệ thống?" "N"; then show_system=1; fi

    local flag="-3"
    [ "$show_system" = "1" ] && flag=""

    section "Danh sách package (${flag:-all})"
    local pkgs
    pkgs="$(pm list packages $flag 2>/dev/null | sed 's/^package://' | sort)"
    if [ -z "$pkgs" ]; then
        warn "Không có package nào."
        pause; return
    fi

    local total
    total="$(printf '%s\n' "$pkgs" | wc -l | tr -d ' ')"
    msg "Tổng: ${C_BYELLOW}${total}${C_RESET} package"

    # Hiển thị dạng cột với số thứ tự
    local arr=()
    local line
    while IFS= read -r line; do arr+=("$line"); done <<< "$pkgs"

    local page=0
    local per=20
    local n=${#arr[@]}
    while :; do
        clear 2>/dev/null || printf '\033[H\033[2J'
        box_title "APP LIST  (trang $((page+1))/$(( (n+per-1)/per )))"
        local start=$((page*per))
        local end=$((start+per))
        [ "$end" -gt "$n" ] && end=$n
        local i=$start
        while [ "$i" -lt "$end" ]; do
            printf '  %s%4d%s  %s\n' "$C_DIM" "$((i+1))" "$C_RESET" "${arr[$i]}"
            i=$((i+1))
        done
        printf '\n  %s[n]%s trang sau  %s[p]%s trang trước  %s[s]%s chọn số  %s[f]%s tìm  %s[q]%s thoát\n' \
            "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BRED" "$C_RESET"
        printf '%s > %s' "$ICON_ARROW" ""
        local cmd=""
        # shellcheck disable=SC2162
        read cmd || break
        case "$cmd" in
            n|N) [ "$end" -lt "$n" ] && page=$((page+1)) ;;
            p|P) [ "$page" -gt 0 ] && page=$((page-1)) ;;
            q|Q) break ;;
            f|F)
                printf 'Từ khoá: '
                # shellcheck disable=SC2162
                read kw
                [ -z "$kw" ] && continue
                local hits
                hits="$(printf '%s\n' "${arr[@]}" | grep -i -- "$kw" | head -40)"
                [ -z "$hits" ] && { warn "Không có kết quả."; pause; continue; }
                printf '%s\n' "$hits"
                pause
                ;;
            s|S)
                printf 'Nhập số thứ tự (1..%d): ' "$n"
                # shellcheck disable=SC2162
                read num
                case "$num" in ''|*[!0-9]*) continue;; esac
                [ "$num" -lt 1 ] || [ "$num" -gt "$n" ] && continue
                app_actions "${arr[$((num-1))]}"
                ;;
            *) ;;
        esac
    done
}

app_actions() {
    local pkg="$1"
    while :; do
        clear 2>/dev/null || printf '\033[H\033[2J'
        box_title "APP: $pkg"
        local label version path uid enabled
        label="$(dumpsys package "$pkg" 2>/dev/null | awk -F= '/applicationInfo=/{print;exit}' | head -c200)"
        version="$(dumpsys package "$pkg" 2>/dev/null | awk -F= '/versionName=/{print $2; exit}')"
        path="$(pm path "$pkg" 2>/dev/null | head -n1 | sed 's/^package://')"
        uid="$(dumpsys package "$pkg" 2>/dev/null | awk -F= '/userId=/{print $2; exit}' | awk '{print $1}')"
        enabled="$(dumpsys package "$pkg" 2>/dev/null | awk -F= '/enabled=/{print $2; exit}')"
        kv "Package"         "$pkg"
        kv "Version"         "${version:--}"
        kv "APK path"        "${path:--}"
        kv "UID"             "${uid:--}"
        kv "Enabled"         "${enabled:--}"

        printf '\n  %s[1]%s Mở (launch)     %s[2]%s Force-stop      %s[3]%s Clear data\n' \
            "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET"
        printf '  %s[4]%s Disable         %s[5]%s Enable          %s[6]%s Uninstall (user)\n' \
            "$C_BYELLOW" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BRED" "$C_RESET"
        printf '  %s[7]%s Uninstall SYSTEM (root)   %s[8]%s Copy APK ra sdcard\n' \
            "$C_BRED" "$C_RESET" "$C_BCYAN" "$C_RESET"
        printf '  %s[0]%s Quay lại\n' "$C_DIM" "$C_RESET"
        printf '%s > ' "$ICON_ARROW"
        local c
        # shellcheck disable=SC2162
        read c || break
        case "$c" in
            1) monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 && ok "Đã mở" || err "Không mở được"; pause ;;
            2) run_as_root am force-stop "$pkg" && ok "force-stop xong" || am force-stop "$pkg"; pause ;;
            3) if confirm "Xoá DỮ LIỆU của $pkg?" "N"; then run_as_root pm clear "$pkg" || pm clear "$pkg"; fi; pause ;;
            4) run_as_root pm disable-user --user 0 "$pkg" || pm disable-user --user 0 "$pkg"; pause ;;
            5) run_as_root pm enable "$pkg" || pm enable "$pkg"; pause ;;
            6) if confirm "Gỡ $pkg (user 0)?" "N"; then pm uninstall --user 0 "$pkg"; fi; pause ;;
            7)
                if [ "$ROOT_GRANTED" != "1" ] && [ "$IS_ROOT" != "1" ]; then
                    err "Cần ROOT để gỡ app hệ thống."; pause; continue
                fi
                if confirm "GỠ HẲN app hệ thống $pkg? KHÔNG THỂ HOÀN TÁC!" "N"; then
                    run_as_root pm uninstall -k --user 0 "$pkg"
                fi
                pause ;;
            8)
                [ -z "$path" ] && { err "Không có APK path"; pause; continue; }
                local dst="/sdcard/${pkg}.apk"
                cp "$path" "$dst" 2>/dev/null || run_as_root cp "$path" "$dst"
                ok "Đã copy sang $dst"; pause ;;
            0|q|Q) return ;;
            *) ;;
        esac
    done
}

# =========================== FILE MANAGER ============================
fm_main() {
    local cwd="${1:-${HOME:-/}}"
    [ ! -d "$cwd" ] && cwd="/"
    while :; do
        clear 2>/dev/null || printf '\033[H\033[2J'
        box_title "FILE MANAGER  –  $cwd"

        # liệt kê
        local entries=()
        entries+=(".. (thư mục cha)")
        local f
        local list
        # ls có thể fail trên thư mục bảo vệ
        if ! list="$(ls -A -- "$cwd" 2>/dev/null)"; then
            list="$(run_as_root ls -A -- "$cwd" 2>/dev/null || true)"
        fi
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            entries+=("$f")
        done <<< "$list"

        local i=0
        local n=${#entries[@]}
        # show
        while [ "$i" -lt "$n" ] && [ "$i" -lt 30 ]; do
            local name="${entries[$i]}"
            local full="$cwd/$name"
            [ "$i" = "0" ] && full="$cwd/.."
            local tag="" size="" perms=""
            if [ -d "$full" ]; then
                tag="${C_BBLUE}[DIR]${C_RESET}"
            elif [ -L "$full" ]; then
                tag="${C_BMAG}[LNK]${C_RESET}"
            elif [ -x "$full" ]; then
                tag="${C_BGREEN}[EXE]${C_RESET}"
            else
                tag="${C_DIM}[FIL]${C_RESET}"
            fi
            if [ -e "$full" ]; then
                size="$(stat -c %s "$full" 2>/dev/null || echo -)"
                perms="$(stat -c %A "$full" 2>/dev/null || echo -)"
                [ "$size" != "-" ] && size="$(human_bytes "$size")"
            fi
            printf '  %s%3d%s  %s  %s%-10s%s  %s%-10s%s  %s\n' \
                "$C_DIM" "$i" "$C_RESET" "$tag" \
                "$C_DIM" "${perms:--}" "$C_RESET" \
                "$C_YELLOW" "${size:--}" "$C_RESET" \
                "$name"
            i=$((i+1))
        done
        [ "$n" -gt 30 ] && printf '  %s... và %d mục khác (dùng [m] để xem thêm)%s\n' "$C_DIM" "$((n-30))" "$C_RESET"

        printf '\n  Clipboard: '
        if [ -n "$CLIPBOARD_PATH" ]; then
            printf '%s[%s] %s%s\n' "$C_BYELLOW" "$CLIPBOARD_MODE" "$CLIPBOARD_PATH" "$C_RESET"
        else
            printf '%s(trống)%s\n' "$C_DIM" "$C_RESET"
        fi

        printf '\n  %s[cd N]%s mở  %s[v N]%s xem  %s[e N]%s sửa  %s[r N]%s rename  %s[c N]%s copy  %s[x N]%s cut\n' \
            "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BYELLOW" "$C_RESET" "$C_BCYAN" "$C_RESET" "$C_BCYAN" "$C_RESET"
        printf '  %s[p]%s paste  %s[d N]%s xoá  %s[mk]%s mkdir  %s[tf]%s touch  %s[g PATH]%s jump  %s[s]%s size  %s[q]%s thoát\n' \
            "$C_BMAG" "$C_RESET" "$C_BRED" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BGREEN" "$C_RESET" "$C_BRED" "$C_RESET"
        printf '%s > ' "$ICON_ARROW"

        local cmd arg
        # shellcheck disable=SC2162
        read cmd arg _rest || break
        case "$cmd" in
            cd)
                local idx="${arg:-}"
                case "$idx" in ''|*[!0-9]*) continue;; esac
                [ "$idx" -ge "$n" ] && continue
                local sel="${entries[$idx]}"
                [ "$idx" = "0" ] && { cwd="$(dirname "$cwd")"; continue; }
                local target="$cwd/$sel"
                if [ -d "$target" ]; then cwd="$target"
                else err "Không phải thư mục"; pause; fi
                ;;
            v|view)
                local idx="${arg:-}"
                case "$idx" in ''|*[!0-9]*) continue;; esac
                local target="$cwd/${entries[$idx]}"
                clear; (cat "$target" 2>/dev/null || run_as_root cat "$target") | ${PAGER:-less} 2>/dev/null || \
                    (cat "$target" 2>/dev/null || run_as_root cat "$target")
                pause
                ;;
            e|edit)
                local idx="${arg:-}"
                case "$idx" in ''|*[!0-9]*) continue;; esac
                local target="$cwd/${entries[$idx]}"
                ${EDITOR:-nano} "$target" 2>/dev/null || vi "$target"
                ;;
            r|rename)
                local idx="${arg:-}"
                case "$idx" in ''|*[!0-9]*) continue;; esac
                local target="$cwd/${entries[$idx]}"
                printf 'Tên mới: '
                # shellcheck disable=SC2162
                read newn
                [ -z "$newn" ] && continue
                mv "$target" "$cwd/$newn" 2>/dev/null || run_as_root mv "$target" "$cwd/$newn"
                ;;
            c|copy)
                local idx="${arg:-}"
                case "$idx" in ''|*[!0-9]*) continue;; esac
                CLIPBOARD_PATH="$cwd/${entries[$idx]}"; CLIPBOARD_MODE="copy"
                ok "Copy: $CLIPBOARD_PATH"; sleep 0.5
                ;;
            x|cut)
                local idx="${arg:-}"
                case "$idx" in ''|*[!0-9]*) continue;; esac
                CLIPBOARD_PATH="$cwd/${entries[$idx]}"; CLIPBOARD_MODE="cut"
                ok "Cut: $CLIPBOARD_PATH"; sleep 0.5
                ;;
            p|paste)
                [ -z "$CLIPBOARD_PATH" ] && { warn "Clipboard trống"; pause; continue; }
                local base
                base="$(basename "$CLIPBOARD_PATH")"
                if [ "$CLIPBOARD_MODE" = "copy" ]; then
                    cp -r "$CLIPBOARD_PATH" "$cwd/" 2>/dev/null || run_as_root cp -r "$CLIPBOARD_PATH" "$cwd/"
                else
                    mv "$CLIPBOARD_PATH" "$cwd/" 2>/dev/null || run_as_root mv "$CLIPBOARD_PATH" "$cwd/"
                    CLIPBOARD_PATH=""; CLIPBOARD_MODE=""
                fi
                ok "Đã paste: $base"; sleep 0.5
                ;;
            d|del)
                local idx="${arg:-}"
                case "$idx" in ''|*[!0-9]*) continue;; esac
                local target="$cwd/${entries[$idx]}"
                if confirm "XOÁ $target?" "N"; then
                    rm -rf -- "$target" 2>/dev/null || run_as_root rm -rf -- "$target"
                fi
                ;;
            mk)
                printf 'Tên thư mục: '
                # shellcheck disable=SC2162
                read nn
                [ -z "$nn" ] && continue
                mkdir -p "$cwd/$nn" 2>/dev/null || run_as_root mkdir -p "$cwd/$nn"
                ;;
            tf)
                printf 'Tên file: '
                # shellcheck disable=SC2162
                read nn
                [ -z "$nn" ] && continue
                : >"$cwd/$nn" 2>/dev/null || run_as_root touch "$cwd/$nn"
                ;;
            g|goto)
                [ -z "${arg:-}" ] && continue
                if [ -d "$arg" ]; then cwd="$arg"
                else err "Không tồn tại: $arg"; pause; fi
                ;;
            s|size)
                msg "Đang tính dung lượng..."
                du -sh "$cwd"/* 2>/dev/null | sort -h | tail -n 20
                pause
                ;;
            q|quit|exit) return ;;
            *) ;;
        esac
    done
}

# =========================== ROOT TOOLS ==============================
root_tools_menu() {
    while :; do
        banner
        box_title "CÔNG CỤ NÂNG CAO (ROOT)"
        if [ "$ROOT_GRANTED" != "1" ] && [ "$IS_ROOT" != "1" ]; then
            warn "Chưa có quyền root – các mục dưới đây sẽ không chạy được."
        fi
        cat <<EOF

  ${C_BGREEN}[1]${C_RESET} Xem / đổi CPU governor
  ${C_BGREEN}[2]${C_RESET} Ép xung / giới hạn min-max CPU
  ${C_BGREEN}[3]${C_RESET} Xem / đổi GPU governor & freq
  ${C_BGREEN}[4]${C_RESET} Xem / đổi I/O scheduler
  ${C_BGREEN}[5]${C_RESET} Drop caches (giải phóng RAM)
  ${C_BGREEN}[6]${C_RESET} Xem wakelock / active_wakeup_sources
  ${C_BGREEN}[7]${C_RESET} Xem logcat realtime (q để thoát)
  ${C_BGREEN}[8]${C_RESET} dmesg kernel log
  ${C_BGREEN}[9]${C_RESET} build.prop viewer / editor
  ${C_BGREEN}[10]${C_RESET} Remount /system rw
  ${C_BGREEN}[11]${C_RESET} Reboot / reboot recovery / bootloader
  ${C_BRED}[0]${C_RESET} Quay lại

EOF
        printf '%s > ' "$ICON_ARROW"
        local c
        # shellcheck disable=SC2162
        read c
        case "$c" in
            1) rt_governor ;;
            2) rt_cpu_freq ;;
            3) rt_gpu ;;
            4) rt_ioscheduler ;;
            5) rt_drop_caches ;;
            6) rt_wakelocks ;;
            7) rt_logcat ;;
            8) rt_dmesg ;;
            9) rt_buildprop ;;
            10) rt_remount ;;
            11) rt_reboot ;;
            0|q|Q) return ;;
        esac
    done
}

rt_governor() {
    box_title "CPU GOVERNOR"
    local i=0
    while [ -d "/sys/devices/system/cpu/cpu$i/cpufreq" ]; do
        local cur avail
        cur="$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor" 2>/dev/null)"
        avail="$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_available_governors" 2>/dev/null)"
        kv "cpu$i cur"       "$cur"
        kv "cpu$i avail"     "$avail"
        i=$((i+1))
    done
    printf '\nGovernor mới (enter = bỏ qua): '
    # shellcheck disable=SC2162
    read gv
    [ -z "$gv" ] && return
    i=0
    while [ -d "/sys/devices/system/cpu/cpu$i/cpufreq" ]; do
        run_as_root sh -c "echo $gv > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor"
        i=$((i+1))
    done
    ok "Đã áp dụng $gv"
    pause
}

rt_cpu_freq() {
    box_title "CPU FREQUENCY"
    local i=0
    while [ -d "/sys/devices/system/cpu/cpu$i/cpufreq" ]; do
        local mn mx av
        mn="$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_min_freq" 2>/dev/null)"
        mx="$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq" 2>/dev/null)"
        av="$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_available_frequencies" 2>/dev/null)"
        kv "cpu$i"           "min=$mn max=$mx"
        [ -n "$av" ] && printf '    %savailable:%s %s\n' "$C_DIM" "$C_RESET" "$av"
        i=$((i+1))
    done
    printf '\nGiá trị MIN mới (Hz, enter bỏ qua): '
    # shellcheck disable=SC2162
    read nmn
    printf 'Giá trị MAX mới (Hz, enter bỏ qua): '
    # shellcheck disable=SC2162
    read nmx
    i=0
    while [ -d "/sys/devices/system/cpu/cpu$i/cpufreq" ]; do
        [ -n "$nmn" ] && run_as_root sh -c "echo $nmn > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_min_freq"
        [ -n "$nmx" ] && run_as_root sh -c "echo $nmx > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq"
        i=$((i+1))
    done
    ok "Áp dụng xong (nếu giá trị hợp lệ)."
    pause
}

rt_gpu() {
    box_title "GPU"
    for gd in /sys/class/kgsl/kgsl-3d0 /sys/devices/platform/mali /sys/class/devfreq/*gpu*; do
        [ -e "$gd" ] || continue
        ls -la "$gd" 2>/dev/null | head -n 20
        echo
        for k in cur_freq max_freq min_freq governor available_governors available_frequencies; do
            [ -e "$gd/$k" ] && kv "$k" "$(cat "$gd/$k" 2>/dev/null)"
        done
        break
    done
    pause
}

rt_ioscheduler() {
    box_title "I/O SCHEDULER"
    local bd
    for bd in /sys/block/*/queue/scheduler; do
        [ -e "$bd" ] || continue
        kv "$(echo "$bd" | awk -F/ '{print $4}')" "$(cat "$bd" 2>/dev/null)"
    done
    printf '\nScheduler mới (enter bỏ qua): '
    # shellcheck disable=SC2162
    read sch
    [ -z "$sch" ] && return
    for bd in /sys/block/*/queue/scheduler; do
        run_as_root sh -c "echo $sch > $bd" 2>/dev/null || true
    done
    ok "Đã thử áp dụng $sch"
    pause
}

rt_drop_caches() {
    run_as_root sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' && ok "Đã drop caches" || err "Không thành công"
    pause
}

rt_wakelocks() {
    box_title "WAKELOCK"
    root_cat /sys/kernel/debug/wakeup_sources 2>/dev/null | head -n 40 || \
    root_cat /d/wakeup_sources 2>/dev/null | head -n 40 || \
    warn "Không đọc được wakelock (cần root + debugfs)"
    pause
}

rt_logcat() {
    command -v logcat >/dev/null 2>&1 || { err "Không có logcat"; pause; return; }
    msg "Ctrl+C hoặc q để thoát logcat"
    sleep 0.5
    logcat -v color 2>/dev/null || logcat
}

rt_dmesg() {
    (dmesg 2>/dev/null || run_as_root dmesg) | tail -n 200 | ${PAGER:-less}
}

rt_buildprop() {
    local bp="/system/build.prop"
    [ -r "$bp" ] || { err "Không đọc được $bp"; pause; return; }
    ${PAGER:-less} "$bp"
}

rt_remount() {
    if confirm "Remount /system RW? (nguy hiểm)" "N"; then
        run_as_root mount -o rw,remount /system && ok "Remount OK" || err "Thất bại"
    fi
    pause
}

rt_reboot() {
    cat <<EOF

  ${C_BGREEN}[1]${C_RESET} Reboot bình thường
  ${C_BGREEN}[2]${C_RESET} Reboot Recovery
  ${C_BGREEN}[3]${C_RESET} Reboot Bootloader
  ${C_BGREEN}[4]${C_RESET} Shutdown
  ${C_BRED}[0]${C_RESET} Huỷ

EOF
    printf '%s > ' "$ICON_ARROW"
    local c
    # shellcheck disable=SC2162
    read c
    case "$c" in
        1) confirm "Reboot?" "N" && run_as_root reboot ;;
        2) confirm "Reboot recovery?" "N" && run_as_root reboot recovery ;;
        3) confirm "Reboot bootloader?" "N" && run_as_root reboot bootloader ;;
        4) confirm "Shutdown?" "N" && run_as_root reboot -p ;;
    esac
}

# =========================== MISC TOOLS ==============================
misc_menu() {
    while :; do
        banner
        box_title "TIỆN ÍCH KHÁC"
        cat <<EOF

  ${C_BGREEN}[1]${C_RESET} Cập nhật Termux (pkg upgrade)
  ${C_BGREEN}[2]${C_RESET} Dọn cache pkg
  ${C_BGREEN}[3]${C_RESET} Hiện địa chỉ IP công cộng
  ${C_BGREEN}[4]${C_RESET} Speedtest (cài nếu thiếu)
  ${C_BGREEN}[5]${C_RESET} Chụp ảnh màn hình (screencap)
  ${C_BGREEN}[6]${C_RESET} Ghi màn hình (screenrecord)
  ${C_BGREEN}[7]${C_RESET} Top CPU / RAM (htop)
  ${C_BGREEN}[8]${C_RESET} Danh sách service đang chạy
  ${C_BGREEN}[9]${C_RESET} Xem nhật ký pin battery_history (root)
  ${C_BRED}[0]${C_RESET} Quay lại

EOF
        printf '%s > ' "$ICON_ARROW"
        local c
        # shellcheck disable=SC2162
        read c
        case "$c" in
            1) pkg update -y && pkg upgrade -y; pause ;;
            2) pkg clean; ok "Đã dọn"; pause ;;
            3) curl -fsSL https://ifconfig.me 2>/dev/null; echo; pause ;;
            4) ensure_pkg speedtest-cli speedtest-cli; speedtest-cli 2>/dev/null || speedtest 2>/dev/null; pause ;;
            5) local out="/sdcard/screen_$(date +%s).png"; run_as_root screencap -p "$out" && ok "Lưu $out" || screencap -p "$out"; pause ;;
            6) local out="/sdcard/rec_$(date +%s).mp4"; msg "Ghi 30s, Ctrl+C để dừng sớm"; screenrecord --time-limit 30 "$out"; ok "Lưu $out"; pause ;;
            7) command -v htop >/dev/null 2>&1 || ensure_pkg htop; htop || top ;;
            8) run_as_root service list 2>/dev/null | head -n 80 || service list | head -n 80; pause ;;
            9) run_as_root dumpsys batterystats --charged 2>/dev/null | head -n 200 | ${PAGER:-less}; ;;
            0|q|Q) return ;;
        esac
    done
}

# ============================== MENU =================================
main_menu() {
    while :; do
        banner
        term_size
        local w=$TERM_COLS
        [ "$w" -gt 78 ] && w=78
        cat <<EOF

  ${C_BOLD}${C_BWHITE}═══ MENU CHÍNH ═══${C_RESET}

  ${C_BGREEN}[1]${C_RESET}  ${ICON_STAR} Thông tin máy siêu chi tiết (CPU/RAM/PIN/NHIỆT/TUỔI MÁY)
  ${C_BGREEN}[2]${C_RESET}  ${ICON_STAR} Quản lý ứng dụng (gồm cả hệ thống)
  ${C_BGREEN}[3]${C_RESET}  ${ICON_STAR} File Manager (ZArchiver-like)
  ${C_BGREEN}[4]${C_RESET}  Công cụ ROOT (ép xung, governor, logcat, dmesg, remount…)
  ${C_BGREEN}[5]${C_RESET}  Tiện ích khác (update, speedtest, screenshot…)
  ${C_BGREEN}[6]${C_RESET}  Xem lại trạng thái root / xin lại root
  ${C_BGREEN}[7]${C_RESET}  Kiểm tra & cài phụ thuộc
  ${C_BRED}[0]${C_RESET}  Thoát

EOF
        printf '%s%s Chọn:%s ' "$ICON_ARROW" "$C_BOLD" "$C_RESET"
        local c
        # shellcheck disable=SC2162
        read c || break
        case "$c" in
            1) show_system_info ;;
            2) list_apps ;;
            3) fm_main "${HOME:-/sdcard}" ;;
            4) root_tools_menu ;;
            5) misc_menu ;;
            6) detect_env; request_root ;;
            7) bootstrap_deps; pause ;;
            0|q|Q|exit) printf '\n%sHẹn gặp lại!%s\n' "$C_BCYAN" "$C_RESET"; exit 0 ;;
            *) warn "Lựa chọn không hợp lệ"; sleep 0.6 ;;
        esac
    done
}

# =============================== ENTRY ===============================
trap 'printf "\n%sĐã huỷ.%s\n" "$C_YELLOW" "$C_RESET"; exit 130' INT

banner
detect_env
request_root
bootstrap_deps
main_menu
