#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — recon.sh — Stage 1: Reconnaissance
# ================================================================

validate_target() {
    local target="$1"
    echo ""; log_info "Target validation: $target"

    if echo "$target" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
        TARGET_IP="$target"
        log_info "IP address detect হয়েছে।"
        echo "$target" | grep -qE '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' && \
            log_warn "Private/Internal IP — External tools কাজ নাও করতে পারে।"
    else
        TARGET_DOMAIN="$target"
        log_info "Domain detect হয়েছে। IP resolve করা হচ্ছে..."
        TARGET_IP=$(dig +short "$target" 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
        [ -n "$TARGET_IP" ] && log_success "Resolved: $target → $TARGET_IP" \
                             || log_warn "Domain resolve হয়নি।"
    fi

    log_info "Ping check করা হচ্ছে..."
    ping -c 2 -W 3 "$target" &>/dev/null \
        && log_success "Target online আছে।" \
        || log_warn "Ping response নেই (scan তবুও চলবে)।"
    echo ""
}

# ── WHOIS ─────────────────────────────────────────────────────────
run_whois() {
    local target="$1"
    local out="$OUTPUT_DIR/01_whois.txt"
    run_tool "WHOIS" "whois $target" "$out" 60

    local registrar country created ns
    registrar=$(grep -i "Registrar:"    "$out" 2>/dev/null | head -1 | cut -d: -f2- | xargs)
    country=$(grep -i "Country:"        "$out" 2>/dev/null | head -1 | cut -d: -f2- | xargs)
    created=$(grep -i "Creation Date:"  "$out" 2>/dev/null | head -1 | cut -d: -f2- | xargs)
    ns=$(grep -i "Name Server:"         "$out" 2>/dev/null | head -2 | cut -d: -f2- | xargs | tr '\n' ', ')

    write_bangla "$OUTPUT_DIR/01_whois_bangla.txt" \
        "  WHOIS — বাংলা বিশ্লেষণ" \
        "${registrar:+📌 Registrar  : $registrar}" \
        "${country:+🌍 দেশ         : $country}" \
        "${created:+📅 তৈরির তারিখ : $created}" \
        "${ns:+🖥️  Name Server  : $ns}" \
        "" \
        "💡 Domain মালিকানা ও বয়স সম্পর্কে ধারণা পাওয়া যায়।"
}

# ── DNS + GeoIP (ip-api + ipinfo) ─────────────────────────────────
run_dns_geo() {
    local target="$1"
    local out="$OUTPUT_DIR/02_dns_geo.txt"
    {
        echo "=== REVERSE DNS ==="
        dig -x "$target" +short 2>/dev/null || host "$target" 2>/dev/null
        echo ""; echo "=== ALL DNS RECORDS ==="
        dig "$target" ANY +noall +answer 2>/dev/null
        echo ""; echo "=== GeoIP (ip-api) ==="
        curl -sf --max-time 8 "http://ip-api.com/json/${TARGET_IP:-$target}" 2>/dev/null
        echo ""; echo "=== GeoIP (ipinfo) ==="
        curl -sf --max-time 8 "https://ipinfo.io/${TARGET_IP:-$target}/json" 2>/dev/null
    } | tee "$out"
    reg_file "dns_geo" "$out"

    local geo; geo=$(curl -sf --max-time 8 "http://ip-api.com/json/${TARGET_IP:-$target}" 2>/dev/null)
    local country="" region="" city="" isp="" asn=""
    if echo "$geo" | grep -q '"status":"success"'; then
        country=$(echo "$geo" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        region=$(echo  "$geo" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        city=$(echo    "$geo" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        isp=$(echo     "$geo" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
        asn=$(echo     "$geo" | grep -o '"as":"[^"]*"' | cut -d'"' -f4)
    fi

    write_bangla "$OUTPUT_DIR/02_dns_geo_bangla.txt" \
        "  DNS / GeoIP — বাংলা বিশ্লেষণ" \
        "${country:+🌍 দেশ    : $country}" \
        "${region:+📍 অঞ্চল  : $region / $city}" \
        "${isp:+📡 ISP    : $isp}" \
        "${asn:+🔢 ASN    : $asn}" \
        "" \
        "💡 Server কোথায় hosted এবং কার network এ সেটা জানা যাচ্ছে।"
}

# ── NMAP — 4 modes ───────────────────────────────────────────────
run_nmap() {
    local target="$1"
    local out="$OUTPUT_DIR/03_nmap.txt"

    local cmd
    case "$SCAN_MODE" in
        1) cmd="nmap -sS -T2 -f -sV --open $target" ;;
        2) cmd="nmap -sV -sC -T3 --open $target" ;;
        3) cmd="nmap -A -T4 --open $target" ;;
    esac
    run_tool "NMAP" "$cmd" "$out" "$TIMEOUT_NMAP"
    parse_nmap_output "$out"

    # OS Detection (Normal/Aggressive)
    if [ "$SCAN_MODE" -ge 2 ]; then
        local out_os="$OUTPUT_DIR/03b_nmap_os.txt"
        run_tool "NMAP OS" "nmap -O --osscan-guess $target" "$out_os" 120
    fi

    # UDP Scan top ports
    if [ "$SCAN_MODE" -ge 2 ]; then
        local out_udp="$OUTPUT_DIR/03c_nmap_udp.txt"
        run_tool "NMAP UDP" "nmap -sU --top-ports 20 $target" "$out_udp" 180
        # Check SNMP
        grep -q "161/udp.*open" "$out_udp" 2>/dev/null && SNMP_OPEN=1
    fi

    # NSE Vulnerability Scripts (Aggressive)
    if [ "$SCAN_MODE" -eq 3 ]; then
        local out_vuln="$OUTPUT_DIR/03d_nmap_vuln.txt"
        run_tool "NMAP Vuln" "nmap --script vuln $target" "$out_vuln" 300
        grep -qi "VULNERABLE" "$out_vuln" 2>/dev/null && log_critical "NMAP Vuln Script — Vulnerability পাওয়া গেছে!"
    fi

    # Specific NSE scripts based on open ports
    [ "$SMB_OPEN"  -eq 1 ] && {
        local out_smb="$OUTPUT_DIR/03e_nmap_smb.txt"
        run_tool "NMAP SMB" "nmap --script smb-vuln-ms17-010,smb-vuln-ms08-067 -p 445 $target" "$out_smb" 60
        grep -qi "VULNERABLE" "$out_smb" 2>/dev/null && log_critical "EternalBlue (MS17-010) VULNERABLE!"
    }
    [ "$SMTP_OPEN" -eq 1 ] && {
        local out_smtp="$OUTPUT_DIR/03f_nmap_smtp.txt"
        run_tool "NMAP SMTP" "nmap --script smtp-enum-users,smtp-open-relay -p 25 $target" "$out_smtp" 60
    }
    [ "$RDP_OPEN"  -eq 1 ] && {
        local out_rdp="$OUTPUT_DIR/03g_nmap_rdp.txt"
        run_tool "NMAP RDP" "nmap --script rdp-vuln-ms12-020 -p 3389 $target" "$out_rdp" 60
        grep -qi "VULNERABLE" "$out_rdp" 2>/dev/null && log_critical "RDP MS12-020 VULNERABLE!"
    }
    [ "$SNMP_OPEN" -eq 1 ] && {
        local out_snmp="$OUTPUT_DIR/03h_nmap_snmp.txt"
        run_tool "NMAP SNMP" "nmap --script snmp-brute,snmp-info -p 161 $target" "$out_snmp" 60
    }

    # Bangla analysis
    {
        echo "================================================================"
        echo "  NMAP — বাংলা বিশ্লেষণ"
        echo "================================================================"
        if [ ${#OPEN_PORTS[@]} -eq 0 ]; then
            echo "⚠️  কোনো open port পাওয়া যায়নি।"
        else
            echo "🔓 মোট ${#OPEN_PORTS[@]} টি open port:"
            echo ""
            for i in "${!OPEN_PORTS[@]}"; do
                local p="${OPEN_PORTS[$i]}" s="${OPEN_SERVICES[$i]:-unknown}" desc
                case "$p" in
                    21)   desc="FTP — Anonymous login test হবে।" ;;
                    22)   desc="SSH — Brute force সম্ভব।" ;;
                    23)   desc="Telnet — অনিরাপদ প্রোটোকল!" ;;
                    25)   desc="SMTP — Email server, user enum সম্ভব।" ;;
                    53)   desc="DNS — Zone transfer check হবে।" ;;
                    80)   desc="HTTP — Web vulnerability scan হবে।" ;;
                    443)  desc="HTTPS — SSL scan হবে।" ;;
                    445)  desc="SMB — EternalBlue check হবে!" ;;
                    3306) desc="MySQL — Database exposed!" ;;
                    3389) desc="RDP — Brute force সম্ভব।" ;;
                    161)  desc="SNMP — Community string check হবে।" ;;
                    5900) desc="VNC — Brute force সম্ভব।" ;;
                    5432) desc="PostgreSQL — Database exposed!" ;;
                    *)    desc="Service: $s" ;;
                esac
                echo "  Port $p → $desc"
            done
        fi
        echo ""
        [ "$SMB_OPEN"   -eq 1 ] && echo "🔴 CRITICAL: SMB open — EternalBlue possible!"
        [ "$MYSQL_OPEN" -eq 1 ] && echo "🔴 CRITICAL: MySQL internet-এ exposed!"
        [ "$RDP_OPEN"   -eq 1 ] && echo "🟠 HIGH: RDP open — brute force possible।"
        [ "$TELNET_OPEN" -eq 1 ] && echo "🟠 HIGH: Telnet open — plain text protocol!"
        [ "$SMTP_OPEN"  -eq 1 ] && echo "🟡 MEDIUM: SMTP open — user enumeration সম্ভব।"
        echo "================================================================"
    } > "$OUTPUT_DIR/03_nmap_bangla.txt"
    echo -e "${MAGENTA}${BOLD}  ── বাংলা বিশ্লেষণ (NMAP) ──${NC}"
    cat "$OUTPUT_DIR/03_nmap_bangla.txt"
}

parse_nmap_output() {
    local f="$1"; [ ! -f "$f" ] && return
    while IFS= read -r line; do
        echo "$line" | grep -qE "^[0-9]+/(tcp|udp).*open" || continue
        local port svc
        port=$(echo "$line" | awk '{print $1}' | cut -d/ -f1)
        svc=$(echo "$line" | awk '{print $3}')
        OPEN_PORTS+=("$port"); OPEN_SERVICES+=("$svc")
        case "$port" in
            80|443|8080|8443|8000|8888) WEB_AVAILABLE=1 ;;
        esac
        case "$port" in
            443|8443) SSL_AVAILABLE=1 ;;
            21)  FTP_OPEN=1 ;;
            22)  SSH_OPEN=1 ;;
            23)  TELNET_OPEN=1 ;;
            25)  SMTP_OPEN=1 ;;
            3306|3307) MYSQL_OPEN=1 ;;
            445|139) SMB_OPEN=1 ;;
            3389) RDP_OPEN=1 ;;
            5900) VNC_OPEN=1 ;;
            5432) POSTGRES_OPEN=1 ;;
        esac
    done < "$f"
    grep -qE "^443/tcp.*open" "$f" 2>/dev/null && SSL_AVAILABLE=1
}

# ── MASSCAN ───────────────────────────────────────────────────────
run_masscan() {
    local target="$1"
    local out="$OUTPUT_DIR/04_masscan.txt"
    command -v masscan &>/dev/null || { log_skip "masscan"; return; }
    [ "$SCAN_MODE" -eq 1 ] && { log_info "Masscan — Stealth mode এ skip।"; return; }

    local rate=1000
    [ "$SCAN_MODE" -eq 3 ] && rate=10000

    run_tool "Masscan" "masscan $target -p1-65535 --rate=$rate" "$out" 300

    write_bangla "$OUTPUT_DIR/04_masscan_bangla.txt" \
        "  Masscan — বাংলা বিশ্লেষণ" \
        "⚡ Masscan দ্রুতগতিতে সব port scan করে।" \
        "💡 Masscan + nmap মিলিয়ে সর্বোচ্চ coverage।"
}

# ── TRACEROUTE ────────────────────────────────────────────────────
run_traceroute() {
    local target="$1"
    local out="$OUTPUT_DIR/05_traceroute.txt"
    command -v traceroute &>/dev/null || { log_skip "traceroute"; return; }

    run_tool "Traceroute" "traceroute -m 20 $target" "$out" 60

    local hops; hops=$(grep -c "^[0-9]" "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/05_traceroute_bangla.txt" \
        "  Traceroute — বাংলা বিশ্লেষণ" \
        "🌐 Network path এ $hops টি hop পাওয়া গেছে।" \
        "💡 কোন ISP বা CDN এর মধ্য দিয়ে traffic যাচ্ছে বোঝা যায়।"
}

# ── theHarvester (all sources) ────────────────────────────────────
run_harvester() {
    local target="$1"
    local out="$OUTPUT_DIR/06_harvester.txt"
    command -v theHarvester &>/dev/null || { log_skip "theHarvester"; return; }

    local sources="bing,certspotter,crtsh,dnsdumpster,hackertarget,rapiddns,urlscan"
    [ "$SCAN_MODE" -eq 3 ] && sources="$sources,google,yahoo,baidu,bing,virustotal"

    run_tool "theHarvester" "theHarvester -d $target -b $sources -l 200" "$out" 180

    while IFS= read -r email; do
        [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && \
            FOUND_EMAILS+=("$email")
    done < <(grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$out" 2>/dev/null | sort -u)

    local ec=${#FOUND_EMAILS[@]}
    write_bangla "$OUTPUT_DIR/06_harvester_bangla.txt" \
        "  theHarvester — বাংলা বিশ্লেষণ" \
        "📧 পাওয়া Email: $ec টি" \
        "💡 Email গুলো phishing বা credential attack এ কাজে লাগে।" \
        "${ec:+💡 HIBP দিয়ে breach check হবে।}"
}

# ── SUBFINDER ─────────────────────────────────────────────────────
run_subfinder() {
    local target="$1"
    local out="$OUTPUT_DIR/07_subfinder.txt"
    command -v subfinder &>/dev/null || { log_skip "subfinder"; return; }

    local flags="-silent"
    [ "$SCAN_MODE" -eq 3 ] && flags="-silent -all"

    run_tool "subfinder" "subfinder -d $target $flags" "$out" 180

    while IFS= read -r sub; do
        [ -n "$sub" ] && FOUND_SUBDOMAINS+=("$sub")
    done < "$out"

    local cnt=${#FOUND_SUBDOMAINS[@]}
    write_bangla "$OUTPUT_DIR/07_subfinder_bangla.txt" \
        "  subfinder — বাংলা বিশ্লেষণ" \
        "🔍 মোট $cnt টি subdomain পাওয়া গেছে।" \
        "💡 প্রতিটি subdomain আলাদাভাবে vulnerable হতে পারে।"
}

# ── AMASS ─────────────────────────────────────────────────────────
run_amass() {
    local target="$1"
    local out="$OUTPUT_DIR/08_amass.txt"
    command -v amass &>/dev/null || { log_skip "amass"; return; }

    local mode="-passive"
    [ "$SCAN_MODE" -ge 2 ] && mode=""
    [ "$SCAN_MODE" -eq 3 ] && mode="-brute"

    run_tool "Amass" "amass enum $mode -d $target" "$out" "$TIMEOUT_AMASS"

    while IFS= read -r sub; do
        [ -n "$sub" ] && FOUND_SUBDOMAINS+=("$sub")
    done < "$out"

    # amass intel mode (aggressive)
    if [ "$SCAN_MODE" -eq 3 ]; then
        local out_intel="$OUTPUT_DIR/08b_amass_intel.txt"
        run_tool "Amass Intel" "amass intel -whois -d $target" "$out_intel" 120
    fi

    local cnt=${#FOUND_SUBDOMAINS[@]}
    write_bangla "$OUTPUT_DIR/08_amass_bangla.txt" \
        "  Amass — বাংলা বিশ্লেষণ" \
        "🔍 Amass মোট $(wc -l < "$out" 2>/dev/null) টি subdomain পেয়েছে।" \
        "💡 Amass subfinder এর চেয়ে বেশি source ব্যবহার করে।" \
        "   Combined total: $cnt টি unique subdomain।"
}

# ── DNSRECON ──────────────────────────────────────────────────────
run_dnsrecon() {
    local target="$1"
    local out="$OUTPUT_DIR/09_dnsrecon.txt"
    command -v dnsrecon &>/dev/null || { log_skip "dnsrecon"; return; }

    local dtype="-t std,axfr"
    [ "$SCAN_MODE" -eq 2 ] && dtype="-t std,axfr,srv"
    [ "$SCAN_MODE" -eq 3 ] && dtype="-t std,axfr,brt,srv,rvl,snoop"

    run_tool "DNSrecon" "dnsrecon -d $target $dtype" "$out" 180

    grep -qi "Zone Transfer" "$out" 2>/dev/null && \
        log_critical "DNS Zone Transfer allowed! সব DNS record expose!"

    local recs; recs=$(grep -c "A\|CNAME\|MX\|TXT" "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/09_dnsrecon_bangla.txt" \
        "  DNSrecon — বাংলা বিশ্লেষণ" \
        "$(grep -qi 'Zone Transfer' "$out" 2>/dev/null && echo '🔴 CRITICAL: DNS Zone Transfer চালু!' || echo '✅ Zone Transfer blocked।')" \
        "📋 মোট $recs DNS record পাওয়া গেছে।" \
        "💡 Zone transfer চালু থাকলে সব internal DNS record expose হয়।"
}

# ── CRT.SH — Certificate Transparency ────────────────────────────
run_crtsh() {
    local target="$1"
    local out="$OUTPUT_DIR/10_crtsh.txt"

    log_info "crt.sh — certificate transparency থেকে subdomain খোঁজা হচ্ছে..."
    local raw
    raw=$(curl -sf --max-time 30 \
        "https://crt.sh/?q=%.${target}&output=json" 2>/dev/null)

    if [ -n "$raw" ]; then
        echo "$raw" | grep -o '"name_value":"[^"]*"' | \
            cut -d'"' -f4 | sed 's/\*\.//g' | \
            sort -u > "$out"
        while IFS= read -r sub; do
            [ -n "$sub" ] && FOUND_SUBDOMAINS+=("$sub")
        done < "$out"
        local cnt; cnt=$(wc -l < "$out")
        log_success "crt.sh — $cnt টি subdomain/SANs পাওয়া গেছে।"
        reg_file "crtsh" "$out"
    else
        log_warn "crt.sh — response পাওয়া যায়নি।"
    fi

    write_bangla "$OUTPUT_DIR/10_crtsh_bangla.txt" \
        "  crt.sh — বাংলা বিশ্লেষণ" \
        "🔐 SSL Certificate log থেকে subdomains বের করা হয়েছে।" \
        "💡 এই method passive — target জানতে পারে না।" \
        "   dev., staging., admin. prefix এর domain গুলো sensitive।"
}

# ── HACKERTARGET — Reverse IP ─────────────────────────────────────
run_hackertarget() {
    local target="$1"
    local out="$OUTPUT_DIR/11_hackertarget.txt"
    local ip="${TARGET_IP:-$target}"

    log_info "HackerTarget — Reverse IP lookup: $ip"
    curl -sf --max-time 15 \
        "https://api.hackertarget.com/reverseiplookup/?q=$ip" 2>/dev/null > "$out"

    local cnt; cnt=$(grep -c "\." "$out" 2>/dev/null || echo 0)
    log_success "HackerTarget — $cnt টি domain একই server এ পাওয়া গেছে।"
    reg_file "hackertarget" "$out"

    write_bangla "$OUTPUT_DIR/11_hackertarget_bangla.txt" \
        "  HackerTarget Reverse IP — বাংলা বিশ্লেষণ" \
        "🖥️ একই server ($ip) এ $cnt টি domain আছে।" \
        "💡 Shared hosting এ অন্য vulnerable site পেলে" \
        "   cross-site attack সম্ভব হতে পারে।"
}

# ── WHATWEB ───────────────────────────────────────────────────────
run_whatweb() {
    local target="$1"
    local out="$OUTPUT_DIR/12_whatweb.txt"
    command -v whatweb &>/dev/null || { log_skip "whatweb"; return; }

    local aggr="1"
    [ "$SCAN_MODE" -eq 3 ] && aggr="3"

    run_tool "WhatWeb" "whatweb -v -a $aggr http://$target" "$out" 60

    DETECTED_TECH=$(cat "$out" 2>/dev/null)
    echo "$DETECTED_TECH" | grep -qi "wordpress" && DETECTED_CMS="wordpress"
    echo "$DETECTED_TECH" | grep -qi "joomla"    && DETECTED_CMS="joomla"
    echo "$DETECTED_TECH" | grep -qi "drupal"    && DETECTED_CMS="drupal"
    echo "$DETECTED_TECH" | grep -qi "laravel"   && DETECTED_FRAMEWORK="laravel"
    echo "$DETECTED_TECH" | grep -qi "django"    && DETECTED_FRAMEWORK="django"
    echo "$DETECTED_TECH" | grep -qi "spring"    && DETECTED_FRAMEWORK="spring"

    {
        echo "================================================================"
        echo "  WhatWeb — বাংলা বিশ্লেষণ"
        echo "================================================================"
        grep -oE "WordPress|Joomla|Drupal|PHP|Apache|Nginx|IIS|jQuery|Laravel|Django|Spring" \
             "$out" 2>/dev/null | sort -u | while read -r tech; do
            case "$tech" in
                WordPress) echo "  🟠 WordPress → WPScan চলবে।" ;;
                Joomla)    echo "  🟠 Joomla → droopescan চলবে।" ;;
                Drupal)    echo "  🟠 Drupal → droopescan চলবে।" ;;
                PHP)       echo "  🟡 PHP — injection সম্ভব।" ;;
                Laravel)   echo "  🟡 Laravel — debug mode check হবে।" ;;
                Django)    echo "  🟡 Django — debug mode check হবে।" ;;
                Spring)    echo "  🟡 Spring Boot — Actuator check হবে।" ;;
                Apache)    echo "  🟡 Apache — misconfiguration check।" ;;
                Nginx)     echo "  🟡 Nginx — configuration check।" ;;
                IIS)       echo "  🟡 IIS — Windows vuln check।" ;;
                *)         echo "  🔵 $tech" ;;
            esac
        done
        [ -n "$DETECTED_CMS" ] && echo "" && echo "🎯 CMS Detected: $DETECTED_CMS"
        echo "================================================================"
    } > "$OUTPUT_DIR/12_whatweb_bangla.txt"
    echo -e "${MAGENTA}${BOLD}  ── বাংলা বিশ্লেষণ (WhatWeb) ──${NC}"
    cat "$OUTPUT_DIR/12_whatweb_bangla.txt"
}

# ── WAFW00F ───────────────────────────────────────────────────────
run_wafw00f() {
    local target="$1"
    local out="$OUTPUT_DIR/13_wafw00f.txt"
    command -v wafw00f &>/dev/null || { log_skip "wafw00f"; return; }

    run_tool "wafw00f" "wafw00f -a http://$target" "$out" 60

    if grep -qi "is behind" "$out" 2>/dev/null; then
        HAS_WAF=1
        WAF_NAME=$(grep -i "is behind" "$out" | head -1 | grep -oE '\(.*\)' | tr -d '()')
        log_warn "WAF Detected: $WAF_NAME"
    fi

    write_bangla "$OUTPUT_DIR/13_wafw00f_bangla.txt" \
        "  wafw00f — বাংলা বিশ্লেষণ" \
        "$([ "$HAS_WAF" -eq 1 ] && echo "🛡️ WAF সনাক্ত: $WAF_NAME" || echo '✅ কোনো WAF সনাক্ত হয়নি।')" \
        "$([ "$HAS_WAF" -eq 1 ] && echo '⚠️ WAF থাকলে কিছু scan blocked হতে পারে।' || echo '💡 Scan বাধাহীনভাবে চলবে।')"
}

# ── TSHARK ────────────────────────────────────────────────────────
run_tshark() {
    local target="$1"
    local out="$OUTPUT_DIR/14_tshark.txt"
    command -v tshark &>/dev/null || { log_skip "tshark"; return; }
    [ "$SCAN_MODE" -eq 1 ] && { log_info "tshark — Stealth mode এ skip।"; return; }

    log_info "tshark — 30s traffic capture করা হচ্ছে..."
    local pcap="/tmp/saimum_cap_$$.pcap"

    timeout 35 tshark -i any -a "duration:30" \
        -f "host $target" -w "$pcap" 2>&1 | head -5 | tee "$out"

    if [ -f "$pcap" ]; then
        {
            echo "=== HTTP Requests ==="
            tshark -r "$pcap" -Y "http.request" -T fields \
                -e ip.src -e http.request.method -e http.request.uri 2>/dev/null | head -20
            echo ""
            echo "=== DNS Queries ==="
            tshark -r "$pcap" -Y "dns.qry.name" -T fields \
                -e dns.qry.name 2>/dev/null | sort -u | head -20
            echo ""
            echo "=== Potential Credentials (FTP/Telnet) ==="
            tshark -r "$pcap" -Y "ftp or telnet" -T fields \
                -e ip.src -e ip.dst -e tcp.payload 2>/dev/null | head -10
            echo ""
            echo "=== Traffic Stats ==="
            tshark -r "$pcap" -qz io,stat,0 2>/dev/null
        } >> "$out"
        rm -f "$pcap"
    fi
    reg_file "tshark" "$out"

    write_bangla "$OUTPUT_DIR/14_tshark_bangla.txt" \
        "  tshark — বাংলা বিশ্লেষণ" \
        "📡 Network traffic analysis সম্পন্ন।" \
        "💡 HTTP traffic এ plain-text credential দেখা যেতে পারে।" \
        "   FTP/Telnet এ username/password visible হতে পারে।"
}

# ── HTTPX — Live subdomain check ─────────────────────────────────
run_httpx() {
    local target="$1"
    local out="$OUTPUT_DIR/15_httpx.txt"
    command -v httpx &>/dev/null || { log_skip "httpx"; return; }
    [ ${#FOUND_SUBDOMAINS[@]} -eq 0 ] && { log_info "Subdomain নেই — httpx skip।"; return; }

    # Unique subdomains to temp file
    local tmp="/tmp/saimum_subs_$$.txt"
    printf '%s\n' "${FOUND_SUBDOMAINS[@]}" | sort -u > "$tmp"

    run_tool "httpx" "httpx -l $tmp -silent -status-code -title -tech-detect -cdn" "$out" 120

    # Save live subdomains
    while IFS= read -r line; do
        [ -n "$line" ] && LIVE_SUBDOMAINS+=("$(echo "$line" | awk '{print $1}')")
    done < "$out"
    rm -f "$tmp"

    local live=${#LIVE_SUBDOMAINS[@]}
    write_bangla "$OUTPUT_DIR/15_httpx_bangla.txt" \
        "  httpx — বাংলা বিশ্লেষণ" \
        "🌐 মোট $live টি live subdomain পাওয়া গেছে।" \
        "💡 প্রতিটি live subdomain vulnerability scan এর target।" \
        "   Title ও tech stack দেখে interesting target বাছাই করুন।"
}

# ── WAYBACKURLS / GAU ─────────────────────────────────────────────
run_wayback() {
    local target="$1"
    local out="$OUTPUT_DIR/16_wayback.txt"

    if command -v waybackurls &>/dev/null; then
        run_tool "waybackurls" "waybackurls $target" "$out" 120
    elif command -v gau &>/dev/null; then
        run_tool "gau" "gau $target" "$out" 120
    else
        log_skip "waybackurls/gau"; return
    fi

    # Extract interesting historical URLs
    grep -E "\?.*=" "$out" 2>/dev/null | sort -u | while read -r url; do
        HISTORICAL_URLS+=("$url")
    done

    local total; total=$(wc -l < "$out" 2>/dev/null || echo 0)
    local params=${#HISTORICAL_URLS[@]}

    write_bangla "$OUTPUT_DIR/16_wayback_bangla.txt" \
        "  Wayback URLs — বাংলা বিশ্লেষণ" \
        "📜 মোট $total টি historical URL পাওয়া গেছে।" \
        "🎯 Parameter সহ URL: $params টি → Injection testing এ যাবে।" \
        "💡 পুরোনো exposed endpoint গুলো এখনও accessible থাকতে পারে।"
}

# ── GOWITNESS — Screenshots ───────────────────────────────────────
run_gowitness() {
    local target="$1"
    local out="$OUTPUT_DIR/17_gowitness.txt"
    command -v gowitness &>/dev/null || { log_skip "gowitness"; return; }
    [ "${GOWITNESS_ENABLED:-1}" -eq 0 ] && return

    local ss_dir="$OUTPUT_DIR/screenshots"
    mkdir -p "$ss_dir"

    if [ ${#LIVE_SUBDOMAINS[@]} -gt 0 ]; then
        local tmp="/tmp/saimum_live_$$.txt"
        printf '%s\n' "${LIVE_SUBDOMAINS[@]}" > "$tmp"
        run_tool "gowitness" "gowitness file -f $tmp -P $ss_dir" "$out" 180
        rm -f "$tmp"
    else
        run_tool "gowitness" "gowitness single -u http://$target -P $ss_dir" "$out" 60
    fi

    local cnt; cnt=$(ls "$ss_dir"/*.png 2>/dev/null | wc -l)
    log_success "gowitness — $cnt screenshots নেওয়া হয়েছে → $ss_dir"
    reg_file "screenshots_dir" "$ss_dir"
}

# ── GOOGLE DORKING ────────────────────────────────────────────────
run_google_dork() {
    local target="$1"
    local out="$OUTPUT_DIR/18_google_dork.txt"

    log_info "Google Dork patterns তৈরি করা হচ্ছে..."
    {
        echo "=== Google Dork Queries for $target ==="
        echo ""
        echo "# Sensitive Files"
        echo "site:$target filetype:pdf"
        echo "site:$target filetype:doc OR filetype:docx"
        echo "site:$target ext:sql OR ext:env OR ext:log"
        echo "site:$target ext:bak OR ext:old OR ext:backup"
        echo ""
        echo "# Admin/Login Pages"
        echo "site:$target inurl:admin"
        echo "site:$target inurl:login"
        echo "site:$target inurl:dashboard"
        echo ""
        echo "# Config/Code Exposure"
        echo "site:$target inurl:config"
        echo "site:$target inurl:phpinfo"
        echo "site:$target \"index of /\""
        echo ""
        echo "# Error Messages"
        echo "site:$target \"Warning: mysql\""
        echo "site:$target \"Fatal error\""
        echo "site:$target \"SQL syntax\""
        echo ""
        echo "# GitHub/Pastebin"
        echo "site:github.com $target password OR secret OR key"
        echo "site:pastebin.com $target"
    } | tee "$out"
    reg_file "google_dork" "$out"

    log_info "💡 এই dork গুলো manually Google এ search করুন।"
}

# ── MAIN RECON RUNNER ─────────────────────────────────────────────
run_recon() {
    local target="$1"
    show_stage 1 "RECONNAISSANCE"

    validate_target "$target"

    run_whois       "$target"
    run_dns_geo     "$target"
    run_nmap        "$target"
    run_masscan     "$target"
    run_traceroute  "$target"
    run_harvester   "$target"
    run_subfinder   "$target"
    run_amass       "$target"
    run_dnsrecon    "$target"
    run_crtsh       "$target"
    run_hackertarget "$target"
    run_httpx       "$target"
    run_wayback     "$target"

    if [ "$WEB_AVAILABLE" -eq 1 ]; then
        run_whatweb "$target"
        run_wafw00f "$target"
    fi

    [ "$SCAN_MODE" -ge 2 ] && run_tshark "$target"
    [ "$SCAN_MODE" -ge 2 ] && run_gowitness "$target"
    run_google_dork "$target"

    # Dedup subdomains
    local tmp_arr=()
    while IFS= read -r s; do tmp_arr+=("$s"); done < \
        <(printf '%s\n' "${FOUND_SUBDOMAINS[@]}" | sort -u)
    FOUND_SUBDOMAINS=("${tmp_arr[@]}")

    echo ""
    echo -e "${CYAN}${BOLD}  [*] Recon সিদ্ধান্ত:${NC}"
    [ "$WEB_AVAILABLE"  -eq 1 ] && log_success "Web port open → Web Scanning চলবে।"
    [ "$FTP_OPEN"       -eq 1 ] && log_warn    "FTP (21) open → Auth testing হবে।"
    [ "$SSH_OPEN"       -eq 1 ] && log_warn    "SSH (22) open → Brute force হবে।"
    [ "$TELNET_OPEN"    -eq 1 ] && log_warn    "Telnet (23) open — অনিরাপদ!"
    [ "$SMTP_OPEN"      -eq 1 ] && log_warn    "SMTP (25) open → User enum হবে।"
    [ "$MYSQL_OPEN"     -eq 1 ] && log_critical "MySQL (3306) exposed!"
    [ "$SMB_OPEN"       -eq 1 ] && log_critical "SMB (445) open — EternalBlue check হবে!"
    [ "$RDP_OPEN"       -eq 1 ] && log_warn    "RDP (3389) open → Brute force হবে।"
    [ "$SSL_AVAILABLE"  -eq 1 ] && log_info    "HTTPS open → SSL testing হবে।"
    [ -n "$DETECTED_CMS" ]     && log_info    "CMS: $DETECTED_CMS → CMS scan হবে।"
    [ ${#FOUND_SUBDOMAINS[@]} -gt 0 ] && log_info "Subdomains: ${#FOUND_SUBDOMAINS[@]} টি।"
    [ ${#FOUND_EMAILS[@]}     -gt 0 ] && log_info "Emails: ${#FOUND_EMAILS[@]} টি।"
    echo ""
    save_state
}
