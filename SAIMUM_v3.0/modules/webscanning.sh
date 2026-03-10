#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — webscanning.sh — Stage 3: Web Scanning
# ================================================================

run_nikto() {
    local target="$1"
    local out="$OUTPUT_DIR/24_nikto.txt"
    command -v nikto &>/dev/null || { log_skip "nikto"; return; }

    local ports=""; for p in "${OPEN_PORTS[@]}"; do
        [[ "$p" =~ ^(80|443|8080|8443|8000|8888)$ ]] && ports+="$p,"
    done
    ports="${ports%,}"; [ -z "$ports" ] && ports="80"

    local flags=""
    [ "$SCAN_MODE" -eq 1 ] && flags="-Pause 2"
    [ "$SCAN_MODE" -eq 2 ] && flags="-Tuning 1234568"
    [ "$SCAN_MODE" -eq 3 ] && flags="-Tuning 1234568 -evasion 1,2,3"
    [ "$SSL_AVAILABLE" -eq 1 ] && flags="$flags -ssl"

    run_tool "Nikto" "nikto -h $target -port $ports $flags" "$out" "$TIMEOUT_NIKTO"

    grep -qi "SQL\|sqli"       "$out" 2>/dev/null && log_critical "Nikto — SQL Injection hint!"
    grep -qi "XSS\|cross.site" "$out" 2>/dev/null && log_high "Nikto — XSS hint।"
    grep -qi "OSVDB\|CVE"      "$out" 2>/dev/null && log_high "Nikto — Vulnerability hints।"

    grep -Eo 'http[s]?://[^ ]+\.php[^ ]*' "$out" 2>/dev/null | while read -r u; do PHP_FILES+=("$u"); done
    grep -Ei 'login|admin|signin' "$out" 2>/dev/null | grep -Eo 'http[s]?://[^ ]+' | \
        while read -r u; do LOGIN_PAGES+=("$u"); done

    local vc; vc=$(grep -c "OSVDB\|CVE" "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/24_nikto_bangla.txt" \
        "  Nikto — বাংলা বিশ্লেষণ" \
        "🔍 মোট $vc টি vulnerability hint পাওয়া গেছে।" \
        "💡 এখানে পাওয়া hints পরবর্তী stage এ verify হবে।"
}

run_nuclei() {
    local target="$1"
    local out="$OUTPUT_DIR/25_nuclei.txt"
    command -v nuclei &>/dev/null || { log_skip "nuclei"; return; }

    local severity tags
    case "$SCAN_MODE" in
        1) severity="-severity medium,high,critical"
           tags="-tags cve,misconfig" ;;
        2) severity="-severity low,medium,high,critical"
           tags="-tags cve,misconfig,exposure,tech" ;;
        3) severity="-severity info,low,medium,high,critical"
           tags="-tags cve,misconfig,exposure,tech,network,dns,headless,token-spray,default-login" ;;
    esac

    # Auto-scan based on detected tech
    local as_flag=""
    [ -n "$DETECTED_CMS" ] && as_flag="-as"

    run_tool "Nuclei" "nuclei -u http://$target $severity $tags $as_flag -silent" \
        "$out" "$TIMEOUT_NUCLEI"

    grep -i "\[critical\]" "$out" 2>/dev/null | while read -r l; do log_critical "$l"; done
    grep -i "\[high\]"     "$out" 2>/dev/null | while read -r l; do log_high "$l"; done

    # Subdomain takeover check
    local out_takeover="$OUTPUT_DIR/25b_nuclei_takeover.txt"
    if [ ${#LIVE_SUBDOMAINS[@]} -gt 0 ]; then
        local tmp="/tmp/saimum_live2_$$.txt"
        printf '%s\n' "${LIVE_SUBDOMAINS[@]}" > "$tmp"
        run_tool "Nuclei Takeover" \
            "nuclei -l $tmp -tags takeover -silent" "$out_takeover" 180
        grep -qi "\[" "$out_takeover" 2>/dev/null && \
            log_critical "Subdomain Takeover vulnerability পাওয়া গেছে!"
        rm -f "$tmp"
    fi

    local crit high med low
    crit=$(grep -ci "\[critical\]" "$out" 2>/dev/null || echo 0)
    high=$(grep -ci "\[high\]"     "$out" 2>/dev/null || echo 0)
    med=$(grep -ci  "\[medium\]"   "$out" 2>/dev/null || echo 0)
    low=$(grep -ci  "\[low\]"      "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/25_nuclei_bangla.txt" \
        "  Nuclei — বাংলা বিশ্লেষণ" \
        "📊 Critical: $crit | High: $high | Medium: $med | Low: $low" \
        "$([ "$crit" -gt 0 ] && echo '⚠️ Critical vulnerability — অবিলম্বে fix করুন!')" \
        "💡 Nuclei CVE, misconfiguration ও default-login ধরে।"
}

run_wpscan() {
    local target="$1"
    local out="$OUTPUT_DIR/26_wpscan.txt"
    command -v wpscan &>/dev/null || { log_skip "wpscan"; return; }

    local enum="--enumerate p,t,u --plugins-detection mixed"
    [ "$SCAN_MODE" -eq 1 ] && enum="--enumerate p,t,u --plugins-detection passive --stealthy"
    [ "$SCAN_MODE" -eq 3 ] && enum="--enumerate ap,at,u,m --plugins-detection aggressive"

    local api=""
    [ -n "$WPSCAN_API_TOKEN" ] && api="--api-token $WPSCAN_API_TOKEN"

    run_tool "WPScan" "wpscan --url http://$target $enum $api --no-banner" \
        "$out" "$TIMEOUT_NIKTO"

    grep -i "\[!\]" "$out" 2>/dev/null | while read -r l; do log_high "WPScan: $l"; done

    # Password brute (aggressive + login page found)
    if [ "$SCAN_MODE" -eq 3 ] && [ ${#LOGIN_PAGES[@]} -gt 0 ]; then
        local out_brute="$OUTPUT_DIR/26b_wpscan_brute.txt"
        run_tool "WPScan Brute" \
            "wpscan --url http://$target --passwords /tmp/saimum_pass.txt --usernames admin,administrator --no-banner" \
            "$out_brute" 180
        grep -qi "SUCCESS" "$out_brute" 2>/dev/null && \
            log_critical "WordPress weak password পাওয়া গেছে!"
    fi

    local pc; pc=$(grep -c "\[+\] Name:" "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/26_wpscan_bangla.txt" \
        "  WPScan — বাংলা বিশ্লেষণ" \
        "🔌 পাওয়া Plugin: $pc টি" \
        "💡 Outdated plugin ও weak password WordPress এর বড় ঝুঁকি।"
}

run_droopescan() {
    local target="$1"
    local out="$OUTPUT_DIR/27_droopescan.txt"
    command -v droopescan &>/dev/null || { log_skip "droopescan"; return; }
    [ "$DETECTED_CMS" != "joomla" ] && [ "$DETECTED_CMS" != "drupal" ] && return

    run_tool "droopescan" "droopescan scan $DETECTED_CMS -u http://$target" \
        "$out" 180

    grep -qi "vulnerability\|CVE" "$out" 2>/dev/null && \
        log_high "droopescan — Vulnerability hint পাওয়া গেছে।"

    write_bangla "$OUTPUT_DIR/27_droopescan_bangla.txt" \
        "  droopescan ($DETECTED_CMS) — বাংলা বিশ্লেষণ" \
        "💡 $DETECTED_CMS specific vulnerability scan সম্পন্ন।"
}

run_paramspider() {
    local target="$1"
    local out="$OUTPUT_DIR/28_paramspider.txt"
    command -v paramspider &>/dev/null || { log_skip "paramspider"; return; }

    run_tool "ParamSpider" "paramspider -d $target --quiet" "$out" 120

    grep -E "\?.*=" "$out" 2>/dev/null | while read -r url; do PHP_FILES+=("$url"); done

    local cnt; cnt=$(grep -c "=" "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/28_paramspider_bangla.txt" \
        "  ParamSpider — বাংলা বিশ্লেষণ" \
        "🔍 মোট $cnt টি URL parameter পাওয়া গেছে।" \
        "💡 এই parameter গুলো SQLi, XSS, SSRF এর জন্য test হবে।"
}

run_arjun() {
    local target="$1"
    local out="$OUTPUT_DIR/29_arjun.txt"
    command -v arjun &>/dev/null || { log_skip "arjun"; return; }

    run_tool "Arjun" "arjun -u http://$target --stable -q" "$out" 120

    if grep -qi "Parameter found" "$out" 2>/dev/null; then
        grep -oE 'Parameter found: [^ ]+' "$out" | cut -d' ' -f3 | \
            while read -r p; do PHP_FILES+=("http://$target?$p=test"); done
        log_high "Arjun — Hidden parameter পাওয়া গেছে!"
    fi

    local cnt; cnt=$(grep -c "Parameter found" "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/29_arjun_bangla.txt" \
        "  Arjun — বাংলা বিশ্লেষণ" \
        "🔍 $cnt টি hidden parameter পাওয়া গেছে।" \
        "💡 Hidden parameter এ sensitive data pass হতে পারে।"
}

run_corscanner() {
    local target="$1"
    local out="$OUTPUT_DIR/30_cors.txt"
    command -v corscanner &>/dev/null || python3 -c "import CORScanner" 2>/dev/null || \
        { log_skip "CORScanner"; return; }

    local cmd="corscanner -u http://$target"
    command -v corscanner &>/dev/null || cmd="python3 -m CORScanner -u http://$target"

    run_tool "CORScanner" "$cmd" "$out" 60

    grep -qi "vulnerable\|misconfig" "$out" 2>/dev/null && \
        log_high "CORS misconfiguration পাওয়া গেছে!"

    write_bangla "$OUTPUT_DIR/30_cors_bangla.txt" \
        "  CORScanner — বাংলা বিশ্লেষণ" \
        "$(grep -qi 'vulnerable' "$out" 2>/dev/null && echo '🟠 CORS misconfiguration পাওয়া গেছে!' || echo '✅ CORS properly configured।')" \
        "💡 CORS misconfiguration দিয়ে attacker cross-domain request করতে পারে।"
}

run_api_discovery() {
    local target="$1"
    local out="$OUTPUT_DIR/31_api_discovery.txt"

    log_info "API endpoint discovery করা হচ্ছে..."
    {
        echo "=== Common API Paths ==="
        for path in "/api" "/api/v1" "/api/v2" "/api/v3" \
                    "/graphql" "/graphiql" "/swagger" "/swagger-ui.html" \
                    "/api-docs" "/openapi.json" "/v1" "/v2"; do
            local code
            code=$(curl -sf --max-time 8 -o /dev/null -w "%{http_code}" \
                "http://$target$path" 2>/dev/null)
            [ "$code" != "404" ] && [ "$code" != "000" ] && \
                echo "[$code] http://$target$path"
        done

        echo ""
        echo "=== GraphQL Introspection ==="
        local gql_resp
        gql_resp=$(curl -sf --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d '{"query":"{__schema{types{name}}}"}' \
            "http://$target/graphql" 2>/dev/null)
        echo "$gql_resp" | grep -q "types" && \
            echo "GRAPHQL_ENABLED: Introspection allowed!" || \
            echo "GraphQL: Not found or introspection disabled."
    } | tee "$out"

    grep -q "GRAPHQL_ENABLED" "$out" 2>/dev/null && \
        log_high "GraphQL Introspection enabled — Schema fully exposed!"

    write_bangla "$OUTPUT_DIR/31_api_bangla.txt" \
        "  API Discovery — বাংলা বিশ্লেষণ" \
        "💡 API endpoint গুলো authentication ও authorization check করুন।" \
        "   GraphQL introspection enabled থাকলে পুরো schema বের হয়।"
    reg_file "api_discovery" "$out"
}

run_clickjacking_check() {
    local target="$1"
    local hfile="$OUTPUT_DIR/19_headers.txt"
    [ ! -f "$hfile" ] && return

    if ! grep -qi "X-Frame-Options\|frame-ancestors" "$hfile" 2>/dev/null; then
        log_medium "Clickjacking — X-Frame-Options missing!"
        {
            echo "=== CLICKJACKING TEST ==="
            echo "VULNERABLE: X-Frame-Options header নেই।"
            echo "Target site কে iframe এ embed করা যেতে পারে।"
            echo ""
            echo "Test PoC HTML:"
            echo "<html><body><iframe src='http://$target' width='500' height='500'></iframe></body></html>"
        } > "$OUTPUT_DIR/32_clickjacking.txt"
        reg_file "clickjacking" "$OUTPUT_DIR/32_clickjacking.txt"
    fi
}

run_open_redirect_check() {
    local target="$1"
    local out="$OUTPUT_DIR/33_open_redirect.txt"
    local payloads=("//evil.com" "https://evil.com" "//evil.com/%2F.." "///evil.com")
    local params=("next" "url" "redirect" "redirect_url" "return" "return_to" "goto" "dest" "destination" "r" "u")

    log_info "Open Redirect check করা হচ্ছে..."
    {
        echo "=== OPEN REDIRECT TEST ==="
        for param in "${params[@]}"; do
            for payload in "${payloads[@]}"; do
                local resp
                resp=$(curl -sf --max-time 8 -I \
                    "http://$target/?${param}=${payload}" 2>/dev/null)
                if echo "$resp" | grep -qi "Location:.*evil.com"; then
                    echo "VULNERABLE: ?${param}=${payload}"
                    log_high "Open Redirect পাওয়া গেছে! param: $param"
                fi
            done
        done
        echo "Scan complete."
    } | tee "$out"
    reg_file "open_redirect" "$out"
}

run_web_scanning() {
    local target="$1"
    [ "$WEB_AVAILABLE" -eq 0 ] && log_warn "Web port নেই — Stage 3 skip।" && return
    show_stage 3 "WEB SCANNING"

    run_nikto          "$target"
    run_nuclei         "$target"
    run_paramspider    "$target"
    run_arjun          "$target"
    run_corscanner     "$target"
    run_api_discovery  "$target"
    run_clickjacking_check "$target"
    run_open_redirect_check "$target"

    case "$DETECTED_CMS" in
        wordpress) log_info "WordPress → WPScan চলবে..."; run_wpscan "$target" ;;
        joomla|drupal) log_info "$DETECTED_CMS → droopescan চলবে..."; run_droopescan "$target" ;;
    esac

    save_state
}
