#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — main_saimum.sh
#   Web Vulnerability Automation Pipeline
#   Author: SAIMUM | For authorized testing only
# ================================================================

# Strict mode — unexpected error এ বন্ধ হবে
set -o pipefail

# Get script directory (symlink-safe)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# Load all modules
for mod in utils recon headers webscanning directory injection auth framework ssl report; do
    src="$SCRIPT_DIR/modules/${mod}.sh"
    if [ -f "$src" ]; then
        source "$src"
    else
        echo "[ERROR] Module missing: $src" >&2
        exit 1
    fi
done

# Load user config
load_config

# Trap Ctrl+C
trap cleanup INT TERM

# ── RESUME CHECK ──────────────────────────────────────────────────
check_resume() {
    if [ -f "$SCAN_STATE_FILE" ] && load_state; then
        echo ""
        echo -e "${YELLOW}${BOLD}  [!] আগের scan পাওয়া গেছে!${NC}"
        echo -e "${WHITE}  Target : $CURRENT_TARGET${NC}"
        echo -e "${WHITE}  Stage  : $CURRENT_STAGE / $TOTAL_STAGES${NC}"
        echo -e "${WHITE}  Output : $OUTPUT_DIR${NC}"
        echo ""
        select_option "কি করবেন?" \
            "Resume — Stage $CURRENT_STAGE থেকে চালু করুন" \
            "New Scan — নতুন scan শুরু করুন"
        if [ "$SELECTED_OPT" -eq 1 ]; then
            return 1   # resume
        else
            rm -f "$SCAN_STATE_FILE"
            return 0   # new scan
        fi
    fi
    return 0
}

# ── MENUS ─────────────────────────────────────────────────────────

menu_target() {
    echo ""
    echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════╗"
    echo -e "  ║         🎯  TARGET SELECTION               ║"
    echo -e "  ╚══════════════════════════════════════════════╝${NC}"

    select_option "Target type:" \
        "Single IP / Domain" \
        "Multiple targets (একে একে)" \
        "File থেকে load করুন"

    case "$SELECTED_OPT" in
        1)
            read -rp "$(echo -e "  ${YELLOW}Enter target (IP or domain): ${NC}")" raw
            TARGETS=("$(sanitize_target "$raw")")
            ;;
        2)
            TARGETS=()
            echo -e "  ${DIM}(শেষ করতে blank line দিন)${NC}"
            while true; do
                read -rp "$(echo -e "  ${YELLOW}Target: ${NC}")" raw
                [ -z "$raw" ] && break
                TARGETS+=("$(sanitize_target "$raw")")
            done
            ;;
        3)
            read -rp "$(echo -e "  ${YELLOW}File path: ${NC}")" fpath
            if [ -f "$fpath" ]; then
                mapfile -t raw_targets < "$fpath"
                TARGETS=()
                for t in "${raw_targets[@]}"; do
                    [ -n "$t" ] && TARGETS+=("$(sanitize_target "$t")")
                done
            else
                log_error "File পাওয়া যায়নি: $fpath"
                exit 1
            fi
            ;;
    esac

    if [ ${#TARGETS[@]} -eq 0 ]; then
        log_error "কোনো target দেওয়া হয়নি।"; exit 1
    fi
    echo -e "  ${GREEN}[✓] Target(s): ${TARGETS[*]}${NC}"
}

menu_scan_mode() {
    echo ""
    echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════╗"
    echo -e "  ║         ⚙️   SCAN MODE                      ║"
    echo -e "  ╚══════════════════════════════════════════════╝${NC}"

    select_option "Scan mode নির্বাচন করুন:" \
        "🕵️  Stealth   — ধীর, কম noise, WAF-এ কম ধরা পড়ে" \
        "⚖️  Normal    — Balanced, বেশিরভাগ ক্ষেত্রে উপযুক্ত" \
        "🔥 Aggressive — সব tool, সব scan, সময় বেশি লাগে"
    SCAN_MODE=$SELECTED_OPT
    echo -e "  ${GREEN}[✓] Mode: $SCAN_MODE${NC}"
}

menu_report_format() {
    echo ""
    echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════╗"
    echo -e "  ║         📄  REPORT FORMAT                   ║"
    echo -e "  ╚══════════════════════════════════════════════╝${NC}"

    select_option "Report format:" \
        "TXT only" \
        "TXT + HTML (dark theme)" \
        "TXT + HTML + PDF"
    REPORT_FORMAT=$SELECTED_OPT

    read -rp "$(echo -e "  ${YELLOW}Report filename (without extension) [saimum_report]: ${NC}")" fname
    [ -n "$fname" ] && REPORT_FILENAME=$(echo "$fname" | tr -cd '[:alnum:]_-') || \
        REPORT_FILENAME="saimum_report"
    echo -e "  ${GREEN}[✓] Format: $REPORT_FORMAT | File: $REPORT_FILENAME${NC}"
}

menu_output_format() {
    echo ""
    select_option "Additional output formats:" \
        "Default (TXT/HTML/PDF only)" \
        "Include JSON" \
        "Include JSON + XML" \
        "All formats"
    OUTPUT_FORMAT=$SELECTED_OPT
    echo -e "  ${GREEN}[✓] Output: $OUTPUT_FORMAT${NC}"
}

menu_proxy() {
    echo ""
    echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════╗"
    echo -e "  ║         🌐  PROXY SETTINGS                  ║"
    echo -e "  ╚══════════════════════════════════════════════╝${NC}"

    select_option "Proxy নির্বাচন করুন:" \
        "No proxy (direct)" \
        "Tor (socks5://127.0.0.1:9050)" \
        "Burp Suite (http://127.0.0.1:8080)" \
        "Custom proxy"

    case "$SELECTED_OPT" in
        1) PROXY="" ;;
        2) PROXY="socks5://127.0.0.1:9050" ;;
        3) PROXY="http://127.0.0.1:8080" ;;
        4) read -rp "$(echo -e "  ${YELLOW}Proxy URL (e.g. http://host:port): ${NC}")" PROXY ;;
    esac
    [ -n "$PROXY" ] && echo -e "  ${GREEN}[✓] Proxy: $PROXY${NC}" || \
        echo -e "  ${GREEN}[✓] Direct connection${NC}"
}

menu_stages() {
    echo ""
    echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════╗"
    echo -e "  ║         🗂️   STAGE SELECTION                ║"
    echo -e "  ╚══════════════════════════════════════════════╝${NC}"

    multi_select "কোন stage চালাবেন? (0 = সব)" \
        "Stage 1: Reconnaissance" \
        "Stage 2: Header & Fingerprint" \
        "Stage 3: Web Scanning" \
        "Stage 4: Directory Discovery" \
        "Stage 5: Injection Testing" \
        "Stage 6: Authentication Testing" \
        "Stage 7: Framework & Exploits" \
        "Stage 8: SSL/TLS Testing" \
        "Stage 9: Reporting"

    SELECTED_STAGES=("${MULTI_SELECTED[@]}")

    if [ ${#SELECTED_STAGES[@]} -eq 9 ]; then
        echo -e "  ${GREEN}[✓] সব stage চলবে।${NC}"
    else
        echo -e "  ${GREEN}[✓] Selected stages: ${SELECTED_STAGES[*]}${NC}"
    fi
}

# ── OUTPUT DIR SETUP ──────────────────────────────────────────────
setup_output_dir() {
    local target="$1"
    local safe; safe=$(echo "$target" | tr '/' '_' | tr -cd '[:alnum:]._-')
    local ts; ts=$(date +%Y%m%d_%H%M%S)
    OUTPUT_DIR="${OUTPUT_BASE}/${safe}_${ts}"
    mkdir -p "$OUTPUT_DIR"
    PIPELINE_LOG="$OUTPUT_DIR/pipeline.log"
    touch "$PIPELINE_LOG"
    echo -e "  ${GREEN}[✓] Output → $OUTPUT_DIR${NC}"
}

# ── RUN PIPELINE FOR ONE TARGET ───────────────────────────────────
run_pipeline() {
    local target="$1"
    CURRENT_TARGET="$target"
    START_TIME=$(date +%s)

    # Reset state for this target
    OPEN_PORTS=(); OPEN_SERVICES=()
    WEB_AVAILABLE=0; SSL_AVAILABLE=0
    FTP_OPEN=0; SSH_OPEN=0; MYSQL_OPEN=0; SMB_OPEN=0
    RDP_OPEN=0; TELNET_OPEN=0; SMTP_OPEN=0; SNMP_OPEN=0
    VNC_OPEN=0; POSTGRES_OPEN=0
    DETECTED_CMS=""; DETECTED_TECH=""; DETECTED_FRAMEWORK=""
    TARGET_IP=""; TARGET_DOMAIN=""
    HAS_WAF=0; WAF_NAME=""; HAS_CDN=0; CDN_NAME=""
    LOGIN_PAGES=(); PHP_FILES=(); FOUND_HASHES=()
    FOUND_SUBDOMAINS=(); FOUND_EMAILS=(); HISTORICAL_URLS=(); LIVE_SUBDOMAINS=()
    COUNT_CRITICAL=0; COUNT_HIGH=0; COUNT_MEDIUM=0; COUNT_LOW=0; COUNT_INFO=0
    TOOL_DURATIONS=(); TOOLS_USED=(); TOOLS_SKIPPED=()
    FILE_REGISTRY=()

    setup_output_dir "$target"
    init_sqlite

    echo ""
    echo -e "${CYAN}${BOLD}  ┌───────────────────────────────────────────────────┐"
    echo -e "  │  🎯 Target  : ${WHITE}$target${CYAN}${BOLD}"
    echo -e "  │  📁 Output  : ${WHITE}$OUTPUT_DIR${CYAN}${BOLD}"
    echo -e "  │  ⚙️  Mode    : ${WHITE}$([ $SCAN_MODE -eq 1 ] && echo 'Stealth' || ([ $SCAN_MODE -eq 2 ] && echo 'Normal' || echo 'Aggressive'))${CYAN}${BOLD}"
    echo -e "  └───────────────────────────────────────────────────┘${NC}"
    echo ""

    stage_selected 1 && run_recon          "$target"
    stage_selected 2 && run_header_analysis "$target"
    stage_selected 3 && run_web_scanning   "$target"
    stage_selected 4 && run_directory_discovery "$target"
    stage_selected 5 && run_injection_testing   "$target"
    stage_selected 6 && run_auth_testing   "$target"
    stage_selected 7 && run_full_framework "$target"
    stage_selected 8 && run_ssl_testing    "$target"
    stage_selected 9 && generate_report    "$target"

    # Cleanup temp files
    rm -f /tmp/saimum_*.txt /tmp/saimum_*.pcap 2>/dev/null
}

# ── MAIN ──────────────────────────────────────────────────────────
main() {
    show_banner

    echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════╗"
    echo -e "  ║   ⚠️  DISCLAIMER                             ║"
    echo -e "  ║   এই tool শুধু authorized target এ          ║"
    echo -e "  ║   ব্যবহার করুন। Unauthorized use illegal।   ║"
    echo -e "  ╚══════════════════════════════════════════════╝${NC}"
    echo ""

    check_all_deps

    # Resume check
    local resume_target=""
    if ! check_resume; then
        # Resume mode
        resume_target="$CURRENT_TARGET"
    fi

    if [ -n "$resume_target" ]; then
        echo -e "${GREEN}  [▶] Resuming scan: $resume_target from stage $CURRENT_STAGE...${NC}"
        run_pipeline "$resume_target"
        exit 0
    fi

    # Full menu flow
    menu_target
    menu_scan_mode
    menu_proxy
    menu_stages
    menu_report_format
    menu_output_format

    echo ""
    echo -e "${WHITE}${BOLD}  ═══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  Scan শুরু হচ্ছে ${#TARGETS[@]} টি target এ...${NC}"
    echo -e "${WHITE}${BOLD}  ═══════════════════════════════════════════════${NC}"
    echo -e "${DIM}  Tip: Pause করতে → touch /tmp/.saimum_pause${NC}"
    echo ""

    for target in "${TARGETS[@]}"; do
        echo -e "${CYAN}${BOLD}\n  ══════ TARGET: $target ══════${NC}"
        run_pipeline "$target"
    done

    echo -e "${GREEN}${BOLD}\n  ✅ সব target scan সম্পন্ন।${NC}"
}

main "$@"
