#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — utils.sh
#   Engine: Colors, Logging, Menus, Timers, State, Deps
# ================================================================

# ── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';   YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';    MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  BOLD='\033[1m';       DIM='\033[2m'
ORANGE='\033[38;5;208m'; NC='\033[0m'

# ── Global Config Defaults ────────────────────────────────────────
SCAN_MODE=2
REPORT_FORMAT=2
REPORT_FILENAME="saimum_report"
OUTPUT_BASE="$HOME/saimum_scans"
OUTPUT_DIR=""
CURRENT_TARGET=""
CURRENT_STAGE=0
TOTAL_STAGES=9
START_TIME=0
PAUSED=0
PROXY=""
SELECTED_STAGES=()   # empty = all stages

SCAN_STATE_FILE="/tmp/.saimum_state"
PIPELINE_LOG=""

# ── Tool Timeouts (overridable via config) ────────────────────────
TIMEOUT_NMAP=${TIMEOUT_NMAP:-300}
TIMEOUT_NIKTO=${TIMEOUT_NIKTO:-300}
TIMEOUT_NUCLEI=${TIMEOUT_NUCLEI:-300}
TIMEOUT_GOBUSTER=${TIMEOUT_GOBUSTER:-180}
TIMEOUT_FFUF=${TIMEOUT_FFUF:-180}
TIMEOUT_SQLMAP=${TIMEOUT_SQLMAP:-300}
TIMEOUT_HYDRA=${TIMEOUT_HYDRA:-180}
TIMEOUT_METASPLOIT=${TIMEOUT_METASPLOIT:-120}
TIMEOUT_ZAP=${TIMEOUT_ZAP:-600}
TIMEOUT_AMASS=${TIMEOUT_AMASS:-300}
TIMEOUT_DEFAULT=${TIMEOUT_DEFAULT:-120}

# ── Shared Discovery State (global arrays — declare -g) ──────────
declare -g -a OPEN_PORTS=()
declare -g -a OPEN_SERVICES=()
declare -g    WEB_AVAILABLE=0
declare -g    SSL_AVAILABLE=0
declare -g    FTP_OPEN=0
declare -g    SSH_OPEN=0
declare -g    MYSQL_OPEN=0
declare -g    SMB_OPEN=0
declare -g    RDP_OPEN=0
declare -g    TELNET_OPEN=0
declare -g    SMTP_OPEN=0
declare -g    SNMP_OPEN=0
declare -g    VNC_OPEN=0
declare -g    POSTGRES_OPEN=0
declare -g    DETECTED_TECH=""
declare -g    DETECTED_CMS=""
declare -g    TARGET_IP=""
declare -g    TARGET_DOMAIN=""
declare -g    HAS_WAF=0
declare -g    WAF_NAME=""
declare -g    HAS_CDN=0
declare -g    CDN_NAME=""

declare -g -a LOGIN_PAGES=()
declare -g -a PHP_FILES=()
declare -g -a FOUND_HASHES=()
declare -g -a FOUND_SUBDOMAINS=()
declare -g -a FOUND_EMAILS=()
declare -g -a HISTORICAL_URLS=()
declare -g -a LIVE_SUBDOMAINS=()

declare -g    WORDLIST=""
declare -g    HAS_GPU=0
declare -g    SHODAN_API_KEY="${SHODAN_API_KEY:-}"
declare -g    HIBP_API_KEY="${HIBP_API_KEY:-}"
declare -g    WPSCAN_API_TOKEN="${WPSCAN_API_TOKEN:-}"

# ── Findings Counters ─────────────────────────────────────────────
declare -g    COUNT_CRITICAL=0
declare -g    COUNT_HIGH=0
declare -g    COUNT_MEDIUM=0
declare -g    COUNT_LOW=0
declare -g    COUNT_INFO=0

# ── Tool Tracking ─────────────────────────────────────────────────
declare -g -A TOOL_DURATIONS=()
declare -g -a TOOLS_USED=()
declare -g -a TOOLS_SKIPPED=()

# ── FILE REGISTRY — নাম দিয়ে track (hardcoded number এর বদলে) ──
declare -g -A FILE_REGISTRY=()

reg_file() {
    local key="$1" path="$2"
    FILE_REGISTRY["$key"]="$path"
}
get_file() {
    echo "${FILE_REGISTRY[$1]:-}"
}

# ── Load User Config ──────────────────────────────────────────────
load_config() {
    local cfg="$HOME/.saimum.conf"
    [ -f "$cfg" ] && source "$cfg"
    # Also load from script dir
    local dir_cfg
    dir_cfg="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/.saimum.conf"
    [ -f "$dir_cfg" ] && source "$dir_cfg"
}

# ── Target Sanitization ───────────────────────────────────────────
sanitize_target() {
    local t="$1"
    # Remove protocol prefix
    t="${t#http://}"; t="${t#https://}"
    # Remove trailing slash/path
    t="${t%%/*}"
    # Allow only safe chars: alphanumeric, dot, hyphen, colon (for port)
    t=$(echo "$t" | tr -cd '[:alnum:].-:')
    echo "$t"
}

# ── Banner ────────────────────────────────────────────────────────
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
  ███████╗ █████╗ ██╗███╗   ███╗██╗   ██╗███╗   ███╗
  ██╔════╝██╔══██╗██║████╗ ████║██║   ██║████╗ ████║
  ███████╗███████║██║██╔████╔██║██║   ██║██╔████╔██║
  ╚════██║██╔══██║██║██║╚██╔╝██║██║   ██║██║╚██╔╝██║
  ███████║██║  ██║██║██║ ╚═╝ ██║╚██████╔╝██║ ╚═╝ ██║
  ╚══════╝╚═╝  ╚═╝╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝     ╚═╝
EOF
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}  ╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}${BOLD}  ║   Web Vulnerability Automation Pipeline v3.0        ║${NC}"
    echo -e "${WHITE}${BOLD}  ║                  By  S A I M U M                    ║${NC}"
    echo -e "${YELLOW}${BOLD}  ╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ── Logging ───────────────────────────────────────────────────────
_log() {
    local level="$1" color="$2" icon="$3" msg="$4"
    echo -e "${color}${icon}${NC} $msg"
    [ -n "$PIPELINE_LOG" ] && echo "[$level] $(date '+%H:%M:%S') $msg" >> "$PIPELINE_LOG"
}

log_info()    { _log "INFO"    "$CYAN"   "[*]" "$1"; }
log_success() { _log "SUCCESS" "$GREEN"  "[✓]" "$1"; }
log_warn()    { _log "WARN"    "$YELLOW" "[!]" "$1"; }
log_error()   { _log "ERROR"   "$RED"    "[✗]" "$1"; }
log_skip()    { echo -e "${DIM}[~] $1 — not installed, skipping.${NC}"; TOOLS_SKIPPED+=("$1"); }

log_critical() {
    COUNT_CRITICAL=$(( COUNT_CRITICAL + 1 ))
    echo ""
    echo -e "${RED}${BOLD}  ╔══════════════════════════════════════════════════════╗"
    echo -e "  ║  🚨  CRITICAL VULNERABILITY FOUND!                  ║"
    printf  "  ║  %-52s║\n" "  $1"
    echo -e "  ╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    [ -n "$PIPELINE_LOG" ] && echo "[CRITICAL] $(date '+%H:%M:%S') $1" >> "$PIPELINE_LOG"
}
log_high()   { COUNT_HIGH=$(( COUNT_HIGH+1 ));     echo -e "${ORANGE}${BOLD}  [HIGH]   $1${NC}";   [ -n "$PIPELINE_LOG" ] && echo "[HIGH]   $(date '+%H:%M:%S') $1" >> "$PIPELINE_LOG"; }
log_medium() { COUNT_MEDIUM=$(( COUNT_MEDIUM+1 )); echo -e "${YELLOW}${BOLD}  [MEDIUM] $1${NC}";   [ -n "$PIPELINE_LOG" ] && echo "[MEDIUM] $(date '+%H:%M:%S') $1" >> "$PIPELINE_LOG"; }
log_low()    { COUNT_LOW=$(( COUNT_LOW+1 ));       echo -e "${GREEN}  [LOW]    $1${NC}";           [ -n "$PIPELINE_LOG" ] && echo "[LOW]    $(date '+%H:%M:%S') $1" >> "$PIPELINE_LOG"; }
log_inf()    { COUNT_INFO=$(( COUNT_INFO+1 ));     echo -e "${BLUE}  [INFO]   $1${NC}";            [ -n "$PIPELINE_LOG" ] && echo "[INFO_F] $(date '+%H:%M:%S') $1" >> "$PIPELINE_LOG"; }

# ── Stage Header ──────────────────────────────────────────────────
show_stage() {
    local num="$1" name="$2"
    CURRENT_STAGE=$num
    local pct=$(( num * 100 / TOTAL_STAGES ))
    local filled=$(( num * 24 / TOTAL_STAGES ))
    local empty=$(( 24 - filled ))
    local bar=""
    for ((i=0;i<filled;i++)); do bar+="█"; done
    for ((i=0;i<empty;i++));  do bar+="░"; done
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}${BOLD}  STAGE ${num}/${TOTAL_STAGES}: ${GREEN}${name}${NC}"
    echo -e "${WHITE}  Progress: [${YELLOW}${bar}${WHITE}] ${pct}%${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    [ -n "$PIPELINE_LOG" ] && echo "=== STAGE $num: $name ===" >> "$PIPELINE_LOG"
}

# ── Show Command Box ──────────────────────────────────────────────
show_command() {
    local tool="$1" cmd="$2"
    echo ""
    echo -e "${CYAN}${BOLD}  ┌──────────────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}${BOLD}  │  🔧 Tool    : ${GREEN}${tool}${NC}"
    echo -e "${WHITE}${BOLD}  │  📌 Command : ${YELLOW}${cmd}${NC}"
    echo -e "${CYAN}${BOLD}  └──────────────────────────────────────────────────────┘${NC}"
    echo -e "${DIM}  ⏳ Running...${NC}"
    echo ""
}

# ── Timer ─────────────────────────────────────────────────────────
_TOOL_T0=0
start_timer() { _TOOL_T0=$(date +%s); }

stop_timer() {
    local tool="$1"
    local t1; t1=$(date +%s)
    local dur=$(( t1 - _TOOL_T0 ))
    TOOL_DURATIONS["$tool"]=$dur
    TOOLS_USED+=("$tool")
    local m=$(( dur/60 )) s=$(( dur%60 ))
    echo -e "${GREEN}  ⏱️  ${tool} — ${m}m ${s}s${NC}"
}

elapsed_total() {
    local now; now=$(date +%s)
    local dur=$(( now - START_TIME ))
    local m=$(( dur/60 )) s=$(( dur%60 ))
    echo "${m}m ${s}s"
}

# ── Tool Runner (with timeout + proxy) ────────────────────────────
run_tool() {
    local tool="$1" cmd="$2" outfile="$3"
    local tout="${4:-$TIMEOUT_DEFAULT}"

    # Inject proxy env if set
    local proxy_prefix=""
    if [ -n "$PROXY" ]; then
        proxy_prefix="env http_proxy=$PROXY https_proxy=$PROXY "
    fi

    show_command "$tool" "$cmd"
    start_timer
    monitor_pause; check_pause

    # Run with timeout
    if eval "timeout $tout $proxy_prefix $cmd" 2>&1 | tee "$outfile"; then
        stop_timer "$tool"
        log_success "$tool সম্পন্ন।"
        reg_file "$tool" "$outfile"
        return 0
    else
        local ec=$?
        stop_timer "$tool"
        if [ $ec -eq 124 ]; then
            log_warn "$tool — timeout (${tout}s) হয়েছে। Partial result saved।"
        else
            log_warn "$tool — কোনো output নেই বা error হয়েছে।"
        fi
        reg_file "$tool" "$outfile"
        return 1
    fi
}

# ── Bangla Analysis Writer ────────────────────────────────────────
write_bangla() {
    local outfile="$1"
    shift
    {
        echo "================================================================"
        printf '%s\n' "$@"
        echo "================================================================"
    } > "$outfile"
    echo -e "${MAGENTA}${BOLD}  ── বাংলা বিশ্লেষণ ──${NC}"
    cat "$outfile"
}

# ── SELECT MENU (central, validated) ─────────────────────────────
# Usage: select_option "prompt" opt1 opt2 opt3 ...
# Returns selected index (1-based) in SELECTED_OPT
select_option() {
    local prompt="$1"; shift
    local opts=("$@")
    local n=${#opts[@]}
    while true; do
        echo ""
        echo -e "${CYAN}${BOLD}  $prompt${NC}"
        for i in "${!opts[@]}"; do
            echo -e "    ${GREEN}$((i+1)))${NC} ${opts[$i]}"
        done
        echo ""
        read -rp "$(echo -e "${YELLOW}  Select [1-${n}]: ${NC}")" SELECTED_OPT
        if [[ "$SELECTED_OPT" =~ ^[0-9]+$ ]] && \
           [ "$SELECTED_OPT" -ge 1 ] && \
           [ "$SELECTED_OPT" -le "$n" ]; then
            return 0
        fi
        log_warn "ভুল অপশন। আবার দিন।"
    done
}

# Multi-select: "1,3,5" বা "all"
# Returns array in MULTI_SELECTED
multi_select() {
    local prompt="$1"; shift
    local opts=("$@")
    local n=${#opts[@]}
    while true; do
        echo ""
        echo -e "${CYAN}${BOLD}  $prompt${NC}"
        for i in "${!opts[@]}"; do
            echo -e "    ${GREEN}$((i+1)))${NC} ${opts[$i]}"
        done
        echo -e "    ${GREEN}0)${NC} সব select করুন"
        echo ""
        read -rp "$(echo -e "${YELLOW}  Select (comma-separated, e.g. 1,3,5): ${NC}")" raw
        MULTI_SELECTED=()
        if [ "$raw" = "0" ] || [ "$raw" = "all" ]; then
            for i in "${!opts[@]}"; do MULTI_SELECTED+=($((i+1))); done
            return 0
        fi
        local valid=1
        IFS=',' read -ra parts <<< "$raw"
        for p in "${parts[@]}"; do
            p=$(echo "$p" | tr -d ' ')
            if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -ge 1 ] && [ "$p" -le "$n" ]; then
                MULTI_SELECTED+=("$p")
            else
                valid=0; break
            fi
        done
        [ "$valid" -eq 1 ] && [ ${#MULTI_SELECTED[@]} -gt 0 ] && return 0
        log_warn "ভুল অপশন। আবার দিন।"
    done
}

# stage_selected: stage চলবে কিনা check
stage_selected() {
    local s="$1"
    [ ${#SELECTED_STAGES[@]} -eq 0 ] && return 0   # সব চলবে
    for sel in "${SELECTED_STAGES[@]}"; do
        [ "$sel" -eq "$s" ] && return 0
    done
    return 1
}

# ── Pause/Resume ──────────────────────────────────────────────────
check_pause() {
    if [ "$PAUSED" -eq 1 ]; then
        echo -e "${YELLOW}${BOLD}\n  [⏸] PAUSED — Enter চাপুন resume করতে...${NC}"
        read -r
        PAUSED=0
        echo -e "${GREEN}  [▶] Resuming...${NC}\n"
    fi
}
monitor_pause() {
    [ -f "/tmp/.saimum_pause" ] && { PAUSED=1; rm -f "/tmp/.saimum_pause"; }
}

# ── State Save/Load ───────────────────────────────────────────────
save_state() {
    {
        echo "CURRENT_STAGE=$CURRENT_STAGE"
        echo "CURRENT_TARGET=$(printf '%q' "$CURRENT_TARGET")"
        echo "SCAN_MODE=$SCAN_MODE"
        echo "OUTPUT_DIR=$(printf '%q' "$OUTPUT_DIR")"
        echo "REPORT_FORMAT=$REPORT_FORMAT"
        echo "REPORT_FILENAME=$(printf '%q' "$REPORT_FILENAME")"
        echo "WEB_AVAILABLE=$WEB_AVAILABLE"
        echo "SSL_AVAILABLE=$SSL_AVAILABLE"
        echo "FTP_OPEN=$FTP_OPEN"
        echo "SSH_OPEN=$SSH_OPEN"
        echo "MYSQL_OPEN=$MYSQL_OPEN"
        echo "SMB_OPEN=$SMB_OPEN"
        echo "RDP_OPEN=$RDP_OPEN"
        echo "TELNET_OPEN=$TELNET_OPEN"
        echo "SMTP_OPEN=$SMTP_OPEN"
        echo "COUNT_CRITICAL=$COUNT_CRITICAL"
        echo "COUNT_HIGH=$COUNT_HIGH"
        echo "COUNT_MEDIUM=$COUNT_MEDIUM"
        echo "COUNT_LOW=$COUNT_LOW"
    } > "$SCAN_STATE_FILE"
}

load_state() {
    [ -f "$SCAN_STATE_FILE" ] && source "$SCAN_STATE_FILE" && return 0 || return 1
}

# ── Cleanup on Ctrl+C ─────────────────────────────────────────────
cleanup() {
    echo ""
    echo -e "${YELLOW}${BOLD}  [!] Scan বন্ধ হচ্ছে... partial report save হচ্ছে।${NC}"
    # Kill child processes
    jobs -p 2>/dev/null | xargs -r kill 2>/dev/null
    save_state
    if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
        {
            echo "=== PARTIAL SCAN REPORT ==="
            echo "Target  : $CURRENT_TARGET"
            echo "Stage   : $CURRENT_STAGE / $TOTAL_STAGES"
            echo "Time    : $(date)"
            echo "Elapsed : $(elapsed_total)"
            echo "Critical: $COUNT_CRITICAL | High: $COUNT_HIGH | Medium: $COUNT_MEDIUM"
            echo "Tools done: ${TOOLS_USED[*]}"
        } >> "$OUTPUT_DIR/partial_report.txt" 2>/dev/null
        echo -e "${GREEN}  [✓] Partial report → $OUTPUT_DIR/partial_report.txt${NC}"
        echo -e "${CYAN}  [*] Resume করতে আবার script চালান।${NC}"
    fi
    echo ""; exit 130
}

# ── GPU Check ─────────────────────────────────────────────────────
check_gpu() {
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null 2>&1; then
        HAS_GPU=1; log_success "NVIDIA GPU পাওয়া গেছে — Hashcat ব্যবহার হবে।"
    elif command -v rocm-smi &>/dev/null; then
        HAS_GPU=1; log_success "AMD GPU পাওয়া গেছে — Hashcat ব্যবহার হবে।"
    else
        HAS_GPU=0; log_info "GPU নেই — John the Ripper ব্যবহার হবে।"
    fi
}

# ── Hash Type Detection ───────────────────────────────────────────
detect_hash_type() {
    local hash="$1" mode=0
    if command -v hashid &>/dev/null; then
        local out; out=$(hashid "$hash" 2>/dev/null | head -3)
        echo "$out" | grep -qi "MD5"         && mode=0
        echo "$out" | grep -qi "SHA-1"       && mode=100
        echo "$out" | grep -qi "SHA-256"     && mode=1400
        echo "$out" | grep -qi "SHA-512"     && mode=1700
        echo "$out" | grep -qi "bcrypt"      && mode=3200
        echo "$out" | grep -qi "SHA-512.*crypt" && mode=1800
    else
        local len=${#hash}
        case "$len" in
            32) mode=0 ;; 40) mode=100 ;; 64) mode=1400 ;; 128) mode=1700 ;;
        esac
        echo "$hash" | grep -qE '^\$2[aby]\$' && mode=3200
        echo "$hash" | grep -qE '^\$6\$'      && mode=1800
        echo "$hash" | grep -qE '^\$1\$'      && mode=500
    fi
    echo "$mode"
}

# ── Wordlist Selection ────────────────────────────────────────────
select_wordlist() {
    local sm="${WORDLIST_SMALL:-/usr/share/wordlists/dirb/small.txt}"
    local md="${WORDLIST_MEDIUM:-/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt}"
    local lg="${WORDLIST_LARGE:-/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-big.txt}"

    case "$SCAN_MODE" in
        1) WORDLIST="$sm"  ;;
        2) WORDLIST="$md"  ;;
        3) WORDLIST="$lg"  ;;
    esac

    if [ ! -f "$WORDLIST" ]; then
        for wl in "$sm" "$md" "/usr/share/wordlists/dirb/common.txt"; do
            [ -f "$wl" ] && { WORDLIST="$wl"; log_info "Wordlist: $WORDLIST"; return; }
        done
        log_info "Wordlist download করা হচ্ছে..."
        mkdir -p "$(dirname "$sm")"
        curl -sf "https://raw.githubusercontent.com/v0re/dirb/master/wordlists/small.txt" \
             -o "$sm" 2>/dev/null && WORDLIST="$sm" \
             || { log_warn "Wordlist download হয়নি।"; WORDLIST=""; }
    fi
    log_info "Wordlist: $WORDLIST"
}

select_dns_wordlist() {
    local wl="${WORDLIST_DNS:-/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt}"
    [ -f "$wl" ] && { DNS_WORDLIST="$wl"; return; }
    DNS_WORDLIST="/usr/share/wordlists/dirb/small.txt"
    [ -f "$DNS_WORDLIST" ] || DNS_WORDLIST=""
}

# ── Required / Optional Tools ─────────────────────────────────────
REQUIRED_TOOLS=(nmap whois curl dig host ping)
OPTIONAL_TOOLS=(
    masscan theHarvester subfinder amass whatweb wafw00f
    dnsrecon tshark traceroute httpx gowitness
    nikto nuclei wpscan droopescan paramspider arjun
    gobuster dirb ffuf wfuzz feroxbuster
    sqlmap dalfox xsstrike commix ssrfmap jwt_tool
    hydra medusa john hashcat hashid
    searchsploit msfconsole
    sslscan testssl sslyze openssl
    trufflehog gitleaks
    waybackurls gau
    wkhtmltopdf sqlite3
)

check_all_deps() {
    echo -e "${CYAN}${BOLD}\n  [*] Tool availability চেক করা হচ্ছে...${NC}\n"
    local missing=()

    echo -e "  ${WHITE}${BOLD}─── Required ────────────────────────${NC}"
    for t in "${REQUIRED_TOOLS[@]}"; do
        if command -v "$t" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $t${NC}"
        else
            echo -e "  ${RED}[✗] $t${NC}"
            missing+=("$t")
        fi
    done

    echo ""
    echo -e "  ${WHITE}${BOLD}─── Optional ────────────────────────${NC}"
    local installed=0 notinstalled=0
    for t in "${OPTIONAL_TOOLS[@]}"; do
        if command -v "$t" &>/dev/null; then
            echo -e "  ${GREEN}[✓] $t${NC}"
            ((installed++))
        else
            echo -e "  ${YELLOW}[~] $t${NC}"
            ((notinstalled++))
        fi
    done
    echo ""
    echo -e "  ${GREEN}Installed: $installed${NC} | ${YELLOW}Missing: $notinstalled${NC}"
    echo ""

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}  [✗] Required tools missing: ${missing[*]}${NC}"
        echo -e "${YELLOW}  Run: sudo apt install ${missing[*]}${NC}"
        exit 1
    fi

    check_gpu

    if command -v nuclei &>/dev/null; then
        log_info "Nuclei templates update করা হচ্ছে (background)..."
        nuclei -update-templates -silent 2>/dev/null &
    fi
}

# ── SQLite History ────────────────────────────────────────────────
init_sqlite() {
    command -v sqlite3 &>/dev/null || return
    local db="${SQLITE_DB:-$HOME/.saimum_history.db}"
    sqlite3 "$db" "
        CREATE TABLE IF NOT EXISTS scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target TEXT, scan_date TEXT, scan_mode INTEGER,
            critical INTEGER, high INTEGER, medium INTEGER, low INTEGER,
            output_dir TEXT
        );
        CREATE TABLE IF NOT EXISTS findings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_id INTEGER, severity TEXT, tool TEXT, description TEXT
        );
    " 2>/dev/null
    SQLITE_DB_PATH="$db"
}

save_to_sqlite() {
    command -v sqlite3 &>/dev/null || return
    local db="${SQLITE_DB_PATH:-}"
    [ -z "$db" ] && return
    local scan_id
    scan_id=$(sqlite3 "$db" "
        INSERT INTO scans (target,scan_date,scan_mode,critical,high,medium,low,output_dir)
        VALUES ('$CURRENT_TARGET','$(date +%Y-%m-%d\ %H:%M:%S)',$SCAN_MODE,
                $COUNT_CRITICAL,$COUNT_HIGH,$COUNT_MEDIUM,$COUNT_LOW,'$OUTPUT_DIR');
        SELECT last_insert_rowid();
    " 2>/dev/null)
    log_info "Scan history saved (SQLite ID: $scan_id)"
}
