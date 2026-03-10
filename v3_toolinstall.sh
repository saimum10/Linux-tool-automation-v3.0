#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — v3_toolinstall.sh
#   Tool Checker & Installer
#   সব tool check করে, যেটা নেই সেটা install করে
# ================================================================

set -o pipefail

# ── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m';  WHITE='\033[1;37m'
MAGENTA='\033[0;35m'; DIM='\033[2m';   BOLD='\033[1m'; NC='\033[0m'
ORANGE='\033[0;33m'

# ── Counters ──────────────────────────────────────────────────────
INSTALLED=0
ALREADY_OK=0
FAILED=0
SKIPPED=0
declare -a FAILED_TOOLS=()
declare -a INSTALLED_TOOLS=()

# ── Log helpers ───────────────────────────────────────────────────
ok()    { echo -e "  ${GREEN}${BOLD}[✓]${NC} ${WHITE}$1${NC} ${DIM}$2${NC}"; }
fail()  { echo -e "  ${RED}${BOLD}[✗]${NC} ${WHITE}$1${NC}${RED} — $2${NC}"; FAILED_TOOLS+=("$1"); ((FAILED++)); }
info()  { echo -e "  ${CYAN}[i]${NC} $1"; }
warn()  { echo -e "  ${YELLOW}[!]${NC} $1"; }
step()  { echo -e "\n${CYAN}${BOLD}  ──────────────────────────────────────────${NC}"; \
          echo -e "  ${MAGENTA}${BOLD}  $1${NC}"; \
          echo -e "${CYAN}${BOLD}  ──────────────────────────────────────────${NC}"; }
header(){ echo -e "\n${BLUE}${BOLD}  ┌─────────────────────────────────────────┐${NC}"; \
          echo -e "${BLUE}${BOLD}  │  $1${NC}"; \
          echo -e "${BLUE}${BOLD}  └─────────────────────────────────────────┘${NC}"; }

# ── Check if running as root ──────────────────────────────────────
check_root() {
    if [ "$EUID" -ne 0 ]; then
        warn "Root access নেই। apt install এর জন্য sudo ব্যবহার হবে।"
        SUDO="sudo"
    else
        SUDO=""
    fi
}

# ── OS Detection ─────────────────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_LIKE="${ID_LIKE:-}"
    elif command -v uname &>/dev/null; then
        OS_ID=$(uname -s | tr '[:upper:]' '[:lower:]')
    else
        OS_ID="unknown"
    fi

    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
    else
        PKG_MANAGER="unknown"
    fi

    info "OS: ${OS_ID} | Package manager: ${PKG_MANAGER}"
}

# ── APT install helper ────────────────────────────────────────────
apt_install() {
    local pkg="$1"
    $SUDO apt-get install -y "$pkg" -qq 2>/dev/null && return 0
    return 1
}

# ── pip install helper ────────────────────────────────────────────
pip_install() {
    local pkg="$1"
    pip3 install "$pkg" --break-system-packages -q 2>/dev/null && return 0
    pip3 install "$pkg" -q 2>/dev/null && return 0
    return 1
}

# ── Go install helper ─────────────────────────────────────────────
go_install() {
    local pkg="$1"
    command -v go &>/dev/null || { warn "Go নেই — $pkg skip।"; return 1; }
    GOPATH="${GOPATH:-$HOME/go}" go install "$pkg" 2>/dev/null && return 0
    return 1
}

# ── Generic checker + installer ───────────────────────────────────
check_and_install() {
    local name="$1"        # display name
    local binary="$2"      # command to check
    local install_fn="$3"  # function to call if missing
    local category="$4"    # apt/go/pip/git/manual

    if command -v "$binary" &>/dev/null; then
        local ver
        ver=$("$binary" --version 2>/dev/null | head -1 | tr -d '\n' | cut -c1-40 || echo "")
        ok "$name" "(${ver:-installed})"
        ((ALREADY_OK++))
    else
        warn "$name পাওয়া যায়নি — install করা হচ্ছে..."
        if $install_fn 2>/dev/null; then
            if command -v "$binary" &>/dev/null; then
                ok "$name" "(newly installed)"
                INSTALLED_TOOLS+=("$name")
                ((INSTALLED++))
            else
                fail "$name" "install হয়েছে কিন্তু command পাওয়া যাচ্ছে না"
            fi
        else
            fail "$name" "install failed — manual install করুন"
        fi
    fi
}

# ================================================================
#   BANNER
# ================================================================
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║    SAIMUM v3.0 — Tool Installer / Checker           ║"
    echo "  ║    v3_toolinstall.sh                                 ║"
    echo "  ║    সব tool check + install হবে                      ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ================================================================
#   SYSTEM PREPARATION
# ================================================================
prepare_system() {
    step "System Preparation"

    if [ "$PKG_MANAGER" = "apt" ]; then
        info "apt update করা হচ্ছে..."
        $SUDO apt-get update -qq 2>/dev/null && ok "apt update" || warn "apt update fail"

        info "Core dependencies install করা হচ্ছে..."
        $SUDO apt-get install -y -qq \
            curl wget git python3 python3-pip golang-go \
            build-essential unzip tar make cmake \
            libssl-dev libffi-dev python3-dev \
            ruby ruby-dev rubygems \
            perl perl-modules \
            sqlite3 jq \
            2>/dev/null && ok "Core dependencies" || warn "কিছু core dep fail"
    fi

    # Go PATH setup
    if command -v go &>/dev/null; then
        export GOPATH="${GOPATH:-$HOME/go}"
        export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin"
        grep -q "GOPATH/bin" ~/.bashrc 2>/dev/null || \
            echo 'export PATH="$PATH:$HOME/go/bin"' >> ~/.bashrc
        ok "Go PATH" "($GOPATH/bin)"
    fi

    # pip PATH
    export PATH="$PATH:$HOME/.local/bin"
    grep -q ".local/bin" ~/.bashrc 2>/dev/null || \
        echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
}

# ================================================================
#   STAGE 1 — RECONNAISSANCE TOOLS
# ================================================================
install_recon_tools() {
    step "Stage 1 — Reconnaissance Tools"

    # nmap
    check_and_install "nmap" "nmap" \
        'apt_install nmap' "apt"

    # masscan
    check_and_install "masscan" "masscan" \
        'apt_install masscan' "apt"

    # whois
    check_and_install "whois" "whois" \
        'apt_install whois' "apt"

    # traceroute
    check_and_install "traceroute" "traceroute" \
        'apt_install traceroute' "apt"

    # dnsrecon
    check_and_install "dnsrecon" "dnsrecon" \
        'apt_install dnsrecon || pip_install dnsrecon' "apt"

    # theHarvester
    check_and_install "theHarvester" "theHarvester" \
        '_install_harvester' "git"

    # subfinder
    check_and_install "subfinder" "subfinder" \
        'go_install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest || apt_install subfinder' "go"

    # amass
    check_and_install "amass" "amass" \
        'apt_install amass || go_install github.com/owasp-amass/amass/v4/...@master' "apt"

    # httpx
    check_and_install "httpx" "httpx" \
        'go_install github.com/projectdiscovery/httpx/cmd/httpx@latest || apt_install httpx-toolkit' "go"

    # waybackurls
    check_and_install "waybackurls" "waybackurls" \
        'go_install github.com/tomnomnom/waybackurls@latest' "go"

    # gau
    check_and_install "gau" "gau" \
        'go_install github.com/lc/gau/v2/cmd/gau@latest' "go"

    # gowitness
    check_and_install "gowitness" "gowitness" \
        'go_install github.com/sensepost/gowitness@latest' "go"

    # whatweb
    check_and_install "whatweb" "whatweb" \
        'apt_install whatweb' "apt"

    # wafw00f
    check_and_install "wafw00f" "wafw00f" \
        'apt_install wafw00f || pip_install wafw00f' "apt"

    # tshark
    check_and_install "tshark" "tshark" \
        '$SUDO DEBIAN_FRONTEND=noninteractive apt_install tshark' "apt"

    # dig (dnsutils)
    check_and_install "dig" "dig" \
        'apt_install dnsutils' "apt"
}

_install_harvester() {
    if [ -d /opt/theHarvester ]; then
        info "theHarvester already cloned, updating..."
        cd /opt/theHarvester && git pull -q 2>/dev/null
    else
        $SUDO git clone https://github.com/laramies/theHarvester.git /opt/theHarvester -q 2>/dev/null
    fi
    $SUDO pip3 install -r /opt/theHarvester/requirements.txt \
        --break-system-packages -q 2>/dev/null || true
    $SUDO ln -sf /opt/theHarvester/theHarvester.py /usr/local/bin/theHarvester 2>/dev/null
    $SUDO chmod +x /usr/local/bin/theHarvester 2>/dev/null
    command -v theHarvester &>/dev/null
}

# ================================================================
#   STAGE 2 — HEADER TOOLS
# ================================================================
install_header_tools() {
    step "Stage 2 — Header & Fingerprint Tools"

    # curl (system)
    check_and_install "curl" "curl" \
        'apt_install curl' "apt"

    # openssl
    check_and_install "openssl" "openssl" \
        'apt_install openssl' "apt"
}

# ================================================================
#   STAGE 3 — WEB SCANNING TOOLS
# ================================================================
install_webscanning_tools() {
    step "Stage 3 — Web Scanning Tools"

    # nikto
    check_and_install "nikto" "nikto" \
        'apt_install nikto' "apt"

    # nuclei
    check_and_install "nuclei" "nuclei" \
        '_install_nuclei' "go"

    # wpscan
    check_and_install "wpscan" "wpscan" \
        '_install_wpscan' "gem"

    # droopescan
    check_and_install "droopescan" "droopescan" \
        'pip_install droopescan' "pip"

    # paramspider
    check_and_install "paramspider" "paramspider" \
        '_install_paramspider' "pip"

    # arjun
    check_and_install "arjun" "arjun" \
        'pip_install arjun' "pip"

    # corscanner
    if python3 -c "import CORScanner" 2>/dev/null || command -v corscanner &>/dev/null; then
        ok "CORScanner" "(installed)"
        ((ALREADY_OK++))
    else
        warn "CORScanner পাওয়া যায়নি — install করা হচ্ছে..."
        if pip_install cors; then
            ok "CORScanner" "(newly installed)"
            INSTALLED_TOOLS+=("CORScanner")
            ((INSTALLED++))
        else
            git clone https://github.com/chenjj/CORScanner.git /opt/CORScanner -q 2>/dev/null && \
            pip_install -r /opt/CORScanner/requirements.txt 2>/dev/null && \
            $SUDO ln -sf /opt/CORScanner/cors_scan.py /usr/local/bin/corscanner 2>/dev/null && \
            ok "CORScanner" "(git install)" || fail "CORScanner" "install failed"
        fi
    fi
}

_install_nuclei() {
    go_install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest 2>/dev/null || \
    apt_install nuclei 2>/dev/null
    # Update templates
    command -v nuclei &>/dev/null && nuclei -update-templates -silent 2>/dev/null || true
    command -v nuclei &>/dev/null
}

_install_wpscan() {
    if command -v gem &>/dev/null; then
        $SUDO gem install wpscan -q 2>/dev/null && return 0
    fi
    apt_install wpscan 2>/dev/null
}

_install_paramspider() {
    pip_install paramspider 2>/dev/null && return 0
    git clone https://github.com/devanshbatham/ParamSpider.git /opt/paramspider -q 2>/dev/null && \
    pip_install -r /opt/paramspider/requirements.txt -q 2>/dev/null && \
    $SUDO ln -sf /opt/paramspider/paramspider/main.py /usr/local/bin/paramspider 2>/dev/null && \
    $SUDO chmod +x /usr/local/bin/paramspider 2>/dev/null
    command -v paramspider &>/dev/null
}

# ================================================================
#   STAGE 4 — DIRECTORY DISCOVERY TOOLS
# ================================================================
install_directory_tools() {
    step "Stage 4 — Directory Discovery Tools"

    # gobuster
    check_and_install "gobuster" "gobuster" \
        'apt_install gobuster || go_install github.com/OJ/gobuster/v3@latest' "apt"

    # ffuf
    check_and_install "ffuf" "ffuf" \
        'apt_install ffuf || go_install github.com/ffuf/ffuf/v2@latest' "apt"

    # wfuzz
    check_and_install "wfuzz" "wfuzz" \
        'apt_install wfuzz || pip_install wfuzz' "apt"

    # dirb
    check_and_install "dirb" "dirb" \
        'apt_install dirb' "apt"

    # feroxbuster
    check_and_install "feroxbuster" "feroxbuster" \
        '_install_feroxbuster' "cargo"

    # Wordlists
    _install_wordlists
}

_install_feroxbuster() {
    # Method 1: apt
    apt_install feroxbuster 2>/dev/null && return 0
    # Method 2: curl installer
    curl -sL https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh \
        2>/dev/null | $SUDO bash -s /usr/local/bin 2>/dev/null && return 0
    # Method 3: cargo
    if command -v cargo &>/dev/null; then
        cargo install feroxbuster -q 2>/dev/null && return 0
    fi
    return 1
}

_install_wordlists() {
    info "Wordlists check করা হচ্ছে..."

    # seclists
    if [ ! -d /usr/share/seclists ] && [ ! -d /opt/SecLists ]; then
        info "SecLists install করা হচ্ছে..."
        apt_install seclists 2>/dev/null || \
        $SUDO git clone https://github.com/danielmiessler/SecLists.git \
            /opt/SecLists --depth=1 -q 2>/dev/null && \
        ok "SecLists" "(/opt/SecLists)" || warn "SecLists install fail"
    else
        ok "SecLists" "($(ls /usr/share/seclists /opt/SecLists 2>/dev/null | head -1))"
        ((ALREADY_OK++))
    fi

    # dirbuster / dirb wordlists
    if [ ! -d /usr/share/wordlists ]; then
        $SUDO mkdir -p /usr/share/wordlists
    fi

    # rockyou.txt
    if [ ! -f /usr/share/wordlists/rockyou.txt ]; then
        info "rockyou.txt check করা হচ্ছে..."
        if [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
            $SUDO gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null && \
            ok "rockyou.txt" "(unzipped)"
        else
            apt_install wordlists 2>/dev/null || \
            warn "rockyou.txt নেই — apt install wordlists চালান"
        fi
    else
        ok "rockyou.txt" "(/usr/share/wordlists/rockyou.txt)"
        ((ALREADY_OK++))
    fi
}

# ================================================================
#   STAGE 5 — INJECTION TESTING TOOLS
# ================================================================
install_injection_tools() {
    step "Stage 5 — Injection Testing Tools"

    # sqlmap
    check_and_install "sqlmap" "sqlmap" \
        'apt_install sqlmap || pip_install sqlmap' "apt"

    # dalfox
    check_and_install "dalfox" "dalfox" \
        'go_install github.com/hahwul/dalfox/v2@latest' "go"

    # xsstrike
    check_and_install "xsstrike" "xsstrike" \
        '_install_xsstrike' "git"

    # commix
    check_and_install "commix" "commix" \
        'apt_install commix || _install_commix' "apt"

    # jwt_tool
    check_and_install "jwt_tool" "jwt_tool" \
        '_install_jwt_tool' "git"
}

_install_xsstrike() {
    apt_install xsstrike 2>/dev/null && return 0
    git clone https://github.com/s0md3v/XSStrike.git /opt/XSStrike -q 2>/dev/null && \
    pip_install -r /opt/XSStrike/requirements.txt -q 2>/dev/null && \
    echo '#!/bin/bash
python3 /opt/XSStrike/xsstrike.py "$@"' | $SUDO tee /usr/local/bin/xsstrike > /dev/null && \
    $SUDO chmod +x /usr/local/bin/xsstrike
    command -v xsstrike &>/dev/null
}

_install_commix() {
    git clone https://github.com/commixproject/commix.git /opt/commix -q 2>/dev/null && \
    echo '#!/bin/bash
python3 /opt/commix/commix.py "$@"' | $SUDO tee /usr/local/bin/commix > /dev/null && \
    $SUDO chmod +x /usr/local/bin/commix
    command -v commix &>/dev/null
}

_install_jwt_tool() {
    apt_install jwt-tool 2>/dev/null && return 0
    pip_install jwt_tool 2>/dev/null && return 0
    git clone https://github.com/ticarpi/jwt_tool.git /opt/jwt_tool -q 2>/dev/null && \
    pip_install -r /opt/jwt_tool/requirements.txt -q 2>/dev/null && \
    echo '#!/bin/bash
python3 /opt/jwt_tool/jwt_tool.py "$@"' | $SUDO tee /usr/local/bin/jwt_tool > /dev/null && \
    $SUDO chmod +x /usr/local/bin/jwt_tool
    command -v jwt_tool &>/dev/null
}

# ================================================================
#   STAGE 6 — AUTHENTICATION TOOLS
# ================================================================
install_auth_tools() {
    step "Stage 6 — Authentication & Password Tools"

    # hydra
    check_and_install "hydra" "hydra" \
        'apt_install hydra' "apt"

    # medusa
    check_and_install "medusa" "medusa" \
        'apt_install medusa' "apt"

    # john the ripper
    check_and_install "john" "john" \
        'apt_install john' "apt"

    # hashcat
    check_and_install "hashcat" "hashcat" \
        'apt_install hashcat' "apt"

    # hashid
    check_and_install "hashid" "hashid" \
        'apt_install hashid || pip_install hashid' "apt"

    # onesixtyone (SNMP)
    check_and_install "onesixtyone" "onesixtyone" \
        'apt_install onesixtyone' "apt"

    # snmpwalk
    check_and_install "snmpwalk" "snmpwalk" \
        'apt_install snmp' "apt"
}

# ================================================================
#   STAGE 7 — FRAMEWORK TOOLS
# ================================================================
install_framework_tools() {
    step "Stage 7 — Framework & Exploit Tools"

    # searchsploit / exploitdb
    check_and_install "searchsploit" "searchsploit" \
        '_install_searchsploit' "apt"

    # metasploit
    check_and_install "msfconsole" "msfconsole" \
        '_install_metasploit' "curl"

    # OWASP ZAP
    _check_owasp_zap

    # trufflehog
    check_and_install "trufflehog" "trufflehog" \
        'go_install github.com/trufflesecurity/trufflehog/v3@latest || _install_trufflehog' "go"

    # gitleaks
    check_and_install "gitleaks" "gitleaks" \
        'apt_install gitleaks || go_install github.com/gitleaks/gitleaks/v8@latest' "apt"

    # java (for ZAP)
    check_and_install "java" "java" \
        'apt_install default-jre-headless' "apt"
}

_install_searchsploit() {
    apt_install exploitdb 2>/dev/null && return 0
    git clone https://gitlab.com/exploit-database/exploitdb.git \
        /opt/exploitdb --depth=1 -q 2>/dev/null && \
    $SUDO ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit 2>/dev/null
    command -v searchsploit &>/dev/null
}

_install_metasploit() {
    if apt_install metasploit-framework 2>/dev/null; then return 0; fi
    # Official installer
    warn "Metasploit official installer দিয়ে install করা হচ্ছে (সময় লাগবে)..."
    curl -sf https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
        > /tmp/msfinstall 2>/dev/null && \
    chmod +x /tmp/msfinstall && \
    $SUDO /tmp/msfinstall 2>/dev/null
    command -v msfconsole &>/dev/null
}

_check_owasp_zap() {
    local zap_bin
    zap_bin=$(command -v zaproxy 2>/dev/null || command -v zap.sh 2>/dev/null || \
              ls /opt/zaproxy/zap.sh 2>/dev/null || ls /usr/share/zaproxy/zap.sh 2>/dev/null || echo "")

    if [ -n "$zap_bin" ]; then
        ok "OWASP ZAP" "($zap_bin)"
        ((ALREADY_OK++))
    else
        warn "OWASP ZAP পাওয়া যায়নি — install করা হচ্ছে..."
        if apt_install zaproxy 2>/dev/null; then
            ok "OWASP ZAP" "(apt)"
            INSTALLED_TOOLS+=("OWASP ZAP")
            ((INSTALLED++))
        else
            warn "OWASP ZAP: apt এ নেই।"
            info "Manual install: https://www.zaproxy.org/download/"
            info "  বা: snap install zaproxy --classic"
            FAILED_TOOLS+=("OWASP ZAP (manual install প্রয়োজন)")
            ((FAILED++))
        fi
    fi
}

_install_trufflehog() {
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
        2>/dev/null | $SUDO sh -s -- -b /usr/local/bin 2>/dev/null
    command -v trufflehog &>/dev/null
}

# ================================================================
#   STAGE 8 — SSL/TLS TOOLS
# ================================================================
install_ssl_tools() {
    step "Stage 8 — SSL/TLS Testing Tools"

    # sslscan
    check_and_install "sslscan" "sslscan" \
        'apt_install sslscan' "apt"

    # testssl.sh
    _check_testssl

    # sslyze
    check_and_install "sslyze" "sslyze" \
        'pip_install sslyze' "pip"

    # openssl (already checked in stage 2)
    command -v openssl &>/dev/null && ok "openssl" "(already verified)" || \
        { apt_install openssl && ok "openssl" "(installed)"; }
}

_check_testssl() {
    if command -v testssl.sh &>/dev/null || command -v testssl &>/dev/null; then
        ok "testssl.sh" "($(command -v testssl.sh 2>/dev/null || command -v testssl))"
        ((ALREADY_OK++))
    else
        warn "testssl.sh পাওয়া যায়নি — install করা হচ্ছে..."
        if apt_install testssl.sh 2>/dev/null; then
            ok "testssl.sh" "(apt)"; INSTALLED_TOOLS+=("testssl.sh"); ((INSTALLED++))
        else
            $SUDO git clone https://github.com/drwetter/testssl.sh.git \
                /opt/testssl.sh --depth=1 -q 2>/dev/null && \
            $SUDO ln -sf /opt/testssl.sh/testssl.sh /usr/local/bin/testssl.sh 2>/dev/null && \
            ok "testssl.sh" "(git)" && INSTALLED_TOOLS+=("testssl.sh") && ((INSTALLED++)) || \
            fail "testssl.sh" "install failed"
        fi
    fi
}

# ================================================================
#   STAGE 9 — REPORT TOOLS
# ================================================================
install_report_tools() {
    step "Stage 9 — Reporting Tools"

    # wkhtmltopdf
    check_and_install "wkhtmltopdf" "wkhtmltopdf" \
        'apt_install wkhtmltopdf' "apt"

    # sqlite3
    check_and_install "sqlite3" "sqlite3" \
        'apt_install sqlite3' "apt"

    # python3
    check_and_install "python3" "python3" \
        'apt_install python3' "apt"

    # jq (JSON processing)
    check_and_install "jq" "jq" \
        'apt_install jq' "apt"
}

# ================================================================
#   OPTIONAL / ENHANCEMENT TOOLS
# ================================================================
install_optional_tools() {
    step "Optional / Enhancement Tools"

    # s3scanner (cloud bucket)
    check_and_install "s3scanner" "s3scanner" \
        'pip_install s3scanner || go_install github.com/sa7mon/S3Scanner@latest' "pip"

    # dotdotpwn (LFI)
    _check_dotdotpwn

    # ssrfmap
    _check_ssrfmap

    # arjun (already in stage 3 but double-check)
    command -v arjun &>/dev/null || \
        { pip_install arjun -q 2>/dev/null && ok "arjun" "(installed)"; }

    # gobuster (already done but check vhost support)
    command -v gobuster &>/dev/null && ok "gobuster vhost support" "(same binary)" && ((ALREADY_OK++))

    # impacket (SMB)
    if python3 -c "import impacket" 2>/dev/null; then
        ok "impacket" "(installed)"
        ((ALREADY_OK++))
    else
        warn "impacket নেই — install করা হচ্ছে..."
        pip_install impacket -q 2>/dev/null && \
        ok "impacket" "(pip)" && INSTALLED_TOOLS+=("impacket") && ((INSTALLED++)) || \
        fail "impacket" "install failed"
    fi
}

_check_dotdotpwn() {
    if command -v dotdotpwn &>/dev/null; then
        ok "dotdotpwn" "(installed)"
        ((ALREADY_OK++))
    else
        apt_install dotdotpwn -qq 2>/dev/null && \
        ok "dotdotpwn" "(apt)" && INSTALLED_TOOLS+=("dotdotpwn") && ((INSTALLED++)) || \
        warn "dotdotpwn — optional, skip"
    fi
}

_check_ssrfmap() {
    if [ -f /opt/SSRFmap/ssrfmap.py ] || command -v ssrfmap &>/dev/null; then
        ok "SSRFmap" "(installed)"
        ((ALREADY_OK++))
    else
        git clone https://github.com/swisskyrepo/SSRFmap.git \
            /opt/SSRFmap --depth=1 -q 2>/dev/null && \
        pip_install -r /opt/SSRFmap/requirements.txt -q 2>/dev/null && \
        echo '#!/bin/bash
python3 /opt/SSRFmap/ssrfmap.py "$@"' | $SUDO tee /usr/local/bin/ssrfmap > /dev/null && \
        $SUDO chmod +x /usr/local/bin/ssrfmap && \
        ok "SSRFmap" "(git)" && INSTALLED_TOOLS+=("SSRFmap") && ((INSTALLED++)) || \
        warn "SSRFmap — optional, skip"
    fi
}

# ================================================================
#   FINAL VERIFICATION
# ================================================================
final_check() {
    step "Final Verification — সব tool আবার check"

    echo ""
    echo -e "  ${WHITE}${BOLD}Binary / Command Check:${NC}"

    local all_tools=(
        nmap masscan whois traceroute dig tshark
        dnsrecon theHarvester subfinder amass httpx waybackurls gau gowitness whatweb wafw00f
        curl openssl
        nikto nuclei wpscan droopescan paramspider arjun
        gobuster ffuf wfuzz dirb feroxbuster
        sqlmap dalfox xsstrike commix jwt_tool
        hydra medusa john hashcat hashid onesixtyone snmpwalk
        searchsploit msfconsole trufflehog gitleaks java
        sslscan sslyze testssl.sh
        wkhtmltopdf sqlite3 python3 jq go
    )

    local ok_count=0 fail_count=0
    for tool in "${all_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            printf "    ${GREEN}✓${NC} %-20s" "$tool"
            ((ok_count++))
        else
            printf "    ${RED}✗${NC} %-20s" "$tool"
            ((fail_count++))
        fi
        # 3 columns
        [ $(( (ok_count + fail_count) % 3 )) -eq 0 ] && echo ""
    done
    echo ""

    # testssl fallback check
    if ! command -v testssl.sh &>/dev/null; then
        command -v testssl &>/dev/null && \
        printf "    ${GREEN}✓${NC} %-20s\n" "testssl (alt)" && ((ok_count++))
    fi

    echo ""
    echo -e "  ${GREEN}${BOLD}✓ OK:   $ok_count tools${NC}"
    echo -e "  ${RED}${BOLD}✗ Missing: $fail_count tools${NC}"
    echo ""
}

# ================================================================
#   SUMMARY
# ================================================================
show_summary() {
    echo ""
    echo -e "${CYAN}${BOLD}  ╔══════════════════════════════════════════════════════╗"
    echo -e "  ║   SAIMUM v3.0 — Installation Summary               ║"
    echo -e "  ╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}Already installed : $ALREADY_OK tools${NC}"
    echo -e "  ${BLUE}${BOLD}Newly installed   : $INSTALLED tools${NC}"
    echo -e "  ${RED}${BOLD}Failed            : $FAILED tools${NC}"
    echo -e "  ${YELLOW}${BOLD}Skipped           : $SKIPPED tools${NC}"
    echo ""

    if [ ${#INSTALLED_TOOLS[@]} -gt 0 ]; then
        echo -e "  ${BLUE}Newly installed tools:${NC}"
        for t in "${INSTALLED_TOOLS[@]}"; do
            echo -e "    ${GREEN}+${NC} $t"
        done
        echo ""
    fi

    if [ ${#FAILED_TOOLS[@]} -gt 0 ]; then
        echo -e "  ${RED}Failed / Manual install প্রয়োজন:${NC}"
        for t in "${FAILED_TOOLS[@]}"; do
            echo -e "    ${RED}✗${NC} $t"
        done
        echo ""
        echo -e "  ${YELLOW}💡 Manual install guide:${NC}"
        echo -e "    ${DIM}OWASP ZAP    → snap install zaproxy --classic${NC}"
        echo -e "    ${DIM}Metasploit   → apt install metasploit-framework${NC}"
        echo -e "    ${DIM}Go tools     → go install <pkg>@latest${NC}"
        echo ""
    fi

    echo -e "  ${DIM}PATH যোগ করতে এখনই চালান:${NC}"
    echo -e "    ${CYAN}source ~/.bashrc${NC}"
    echo ""

    if [ "$FAILED" -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}✅ সব tool install সম্পন্ন! SAIMUM v3.0 চালানোর জন্য ready।${NC}"
    else
        echo -e "  ${YELLOW}${BOLD}⚠️  $FAILED টি tool manually install করতে হবে।${NC}"
    fi
    echo ""
}

# ================================================================
#   MAIN
# ================================================================
main() {
    show_banner
    check_root
    detect_os

    echo -e "  ${YELLOW}⚠️  এই script টি অনেক tool install করবে।${NC}"
    echo -e "  ${YELLOW}   Kali Linux / Debian / Ubuntu তে best কাজ করে।${NC}"
    echo ""
    read -rp "$(echo -e "  ${CYAN}Continue? (y/N): ${NC}")" confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "বাতিল।"; exit 0; }

    prepare_system

    install_recon_tools
    install_header_tools
    install_webscanning_tools
    install_directory_tools
    install_injection_tools
    install_auth_tools
    install_framework_tools
    install_ssl_tools
    install_report_tools
    install_optional_tools

    final_check
    show_summary
}

main "$@"
