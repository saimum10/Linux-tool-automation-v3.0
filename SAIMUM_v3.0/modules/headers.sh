#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — headers.sh — Stage 2: Header & Fingerprint
# ================================================================

# ── HTTP Headers Full Dump ────────────────────────────────────────
run_header_dump() {
    local target="$1"
    local out="$OUTPUT_DIR/19_headers.txt"

    local proxy_flag=""
    [ -n "$PROXY" ] && proxy_flag="--proxy $PROXY"

    run_tool "HTTP Headers" \
        "curl -sI $proxy_flag --max-time 15 --connect-timeout 8 -L http://$target" \
        "$out" 30

    # Also HTTPS
    if [ "$SSL_AVAILABLE" -eq 1 ]; then
        local out_ssl="$OUTPUT_DIR/19b_headers_https.txt"
        run_tool "HTTPS Headers" \
            "curl -sI $proxy_flag --max-time 15 -k -L https://$target" \
            "$out_ssl" 30
    fi
    reg_file "headers" "$out"
}

# ── CDN Detection ─────────────────────────────────────────────────
run_cdn_detect() {
    local target="$1"
    local hfile="$OUTPUT_DIR/19_headers.txt"
    [ ! -f "$hfile" ] && return

    local cdn=""
    grep -qi "cloudflare"         "$hfile" && cdn="Cloudflare"
    grep -qi "akamai"             "$hfile" && cdn="Akamai"
    grep -qi "fastly"             "$hfile" && cdn="Fastly"
    grep -qi "x-amz-cf-id\|CloudFront" "$hfile" && cdn="AWS CloudFront"
    grep -qi "x-vercel"          "$hfile" && cdn="Vercel"
    grep -qi "x-netlify"         "$hfile" && cdn="Netlify"
    grep -qi "x-sucuri"          "$hfile" && cdn="Sucuri"
    grep -qi "x-cache.*HIT\|Via.*Varnish" "$hfile" && cdn="Varnish/CDN"
    grep -qi "server:.*BunnyCDN"  "$hfile" && cdn="BunnyCDN"

    if [ -n "$cdn" ]; then
        HAS_CDN=1; CDN_NAME="$cdn"
        log_info "CDN Detected: $CDN_NAME"
    fi

    # WAF from headers
    grep -qi "x-protected-by\|x-firewall\|x-waf" "$hfile" && {
        HAS_WAF=1
        WAF_NAME=$(grep -i "x-protected-by\|x-firewall" "$hfile" | head -1 | cut -d: -f2- | xargs)
        log_warn "WAF (header-based): $WAF_NAME"
    }
}

# ── Security Header Audit ─────────────────────────────────────────
run_security_headers() {
    local target="$1"
    local out="$OUTPUT_DIR/20_sec_headers.txt"
    local hfile="$OUTPUT_DIR/19_headers.txt"
    [ ! -f "$hfile" ] && { log_warn "Header dump নেই — Security header audit skip।"; return; }

    log_info "Security headers audit করা হচ্ছে..."

    declare -A HEADERS_STATUS=()

    # Check each security header
    local checks=(
        "Strict-Transport-Security:HSTS:prevents protocol downgrade"
        "Content-Security-Policy:CSP:prevents XSS"
        "X-Frame-Options:Clickjacking Protection:prevents iframe embedding"
        "X-Content-Type-Options:MIME Sniffing Protection:prevents MIME confusion"
        "Referrer-Policy:Referrer Policy:controls referrer info leakage"
        "Permissions-Policy:Permissions Policy:controls browser features"
        "X-XSS-Protection:XSS Filter:legacy XSS protection"
        "Cache-Control:Cache Control:prevents sensitive data caching"
    )

    {
        echo "=== SECURITY HEADER AUDIT: $target ==="
        echo ""
        for entry in "${checks[@]}"; do
            local hname desc purpose
            hname=$(echo "$entry" | cut -d: -f1)
            desc=$(echo "$entry"  | cut -d: -f2)
            purpose=$(echo "$entry" | cut -d: -f3-)
            if grep -qi "^${hname}:" "$hfile" 2>/dev/null; then
                local val; val=$(grep -i "^${hname}:" "$hfile" | head -1 | cut -d: -f2- | xargs)
                echo "[PRESENT] $hname: $val"
                HEADERS_STATUS["$hname"]="present"
            else
                echo "[MISSING] $hname — $purpose"
                HEADERS_STATUS["$hname"]="missing"
            fi
        done

        echo ""
        echo "=== SERVER VERSION LEAK ==="
        grep -i "^Server:" "$hfile" 2>/dev/null && \
            echo "WARNING: Server header exposed!" || echo "OK: Server header hidden."
        grep -i "^X-Powered-By:" "$hfile" 2>/dev/null && \
            echo "WARNING: X-Powered-By exposed!" || echo "OK: X-Powered-By hidden."
        grep -i "^X-AspNet-Version:\|^X-AspNetMvc-Version:" "$hfile" 2>/dev/null && \
            echo "WARNING: ASP.NET version exposed!"
    } | tee "$out"

    # Severity flags
    [ "${HEADERS_STATUS[Strict-Transport-Security]}" = "missing" ] && \
        [ "$SSL_AVAILABLE" -eq 1 ] && log_high "HSTS header missing — HTTPS downgrade সম্ভব।"
    [ "${HEADERS_STATUS[Content-Security-Policy]}" = "missing" ] && \
        log_medium "CSP header missing — XSS risk বাড়ে।"
    [ "${HEADERS_STATUS[X-Frame-Options]}" = "missing" ] && \
        log_medium "X-Frame-Options missing — Clickjacking সম্ভব।"
    grep -qi "^Server:.*[0-9]\." "$hfile" 2>/dev/null && \
        log_medium "Server version exposed — পুরো version জানা গেছে।"

    {
        echo "================================================================"
        echo "  Security Headers — বাংলা বিশ্লেষণ"
        echo "================================================================"
        grep "\[MISSING\]" "$out" 2>/dev/null | while read -r l; do
            echo "  🔴 $l"
        done
        grep "\[PRESENT\]" "$out" 2>/dev/null | while read -r l; do
            echo "  ✅ $l"
        done
        echo ""
        echo "💡 Missing header গুলো web server config এ যোগ করুন।"
        echo "   Apache: /etc/apache2/apache2.conf"
        echo "   Nginx:  /etc/nginx/nginx.conf"
        echo "================================================================"
    } > "$OUTPUT_DIR/20_sec_headers_bangla.txt"
    echo -e "${MAGENTA}${BOLD}  ── বাংলা বিশ্লেষণ (Security Headers) ──${NC}"
    cat "$OUTPUT_DIR/20_sec_headers_bangla.txt"
}

# ── Cookie Security Flags ─────────────────────────────────────────
run_cookie_check() {
    local target="$1"
    local out="$OUTPUT_DIR/21_cookies.txt"

    log_info "Cookie security flags check করা হচ্ছে..."
    curl -sf --max-time 15 -c /dev/null -D - "http://$target/" 2>/dev/null | \
        grep -i "^Set-Cookie" | tee "$out"

    if [ -s "$out" ]; then
        local missing_secure=0 missing_httponly=0 missing_samesite=0
        while IFS= read -r cookie; do
            echo "$cookie" | grep -qi "Secure"   || missing_secure=1
            echo "$cookie" | grep -qi "HttpOnly" || missing_httponly=1
            echo "$cookie" | grep -qi "SameSite" || missing_samesite=1
        done < "$out"

        [ "$missing_secure"   -eq 1 ] && log_medium "Cookie — Secure flag missing।"
        [ "$missing_httponly" -eq 1 ] && log_high   "Cookie — HttpOnly flag missing — XSS দিয়ে চুরি সম্ভব!"
        [ "$missing_samesite" -eq 1 ] && log_medium "Cookie — SameSite missing — CSRF সম্ভব।"

        write_bangla "$OUTPUT_DIR/21_cookies_bangla.txt" \
            "  Cookie Security — বাংলা বিশ্লেষণ" \
            "$([ $missing_httponly -eq 1 ] && echo '🟠 HttpOnly missing — JavaScript দিয়ে cookie চুরি সম্ভব!' || echo '✅ HttpOnly set আছে।')" \
            "$([ $missing_secure -eq 1 ] && echo '🟡 Secure missing — HTTP এ cookie যাচ্ছে।' || echo '✅ Secure flag set।')" \
            "$([ $missing_samesite -eq 1 ] && echo '🟡 SameSite missing — CSRF attack সম্ভব।' || echo '✅ SameSite set আছে।')" \
            "" \
            "🔧 Fix: Set-Cookie: name=value; HttpOnly; Secure; SameSite=Strict"
    else
        log_info "Cookie পাওয়া যায়নি।"
    fi
    reg_file "cookies" "$out"
}

# ── OpenSSL Certificate Analysis ─────────────────────────────────
run_openssl_cert() {
    local target="$1"
    local out="$OUTPUT_DIR/22_openssl_cert.txt"
    command -v openssl &>/dev/null || { log_skip "openssl"; return; }
    [ "$SSL_AVAILABLE" -eq 0 ] && return

    {
        echo "=== CERTIFICATE DETAILS ==="
        echo "" | openssl s_client -connect "$target:443" \
            -servername "$target" 2>/dev/null | \
            openssl x509 -noout -text 2>/dev/null

        echo ""
        echo "=== SAN (Subject Alternative Names) ==="
        echo "" | openssl s_client -connect "$target:443" \
            -servername "$target" 2>/dev/null | \
            openssl x509 -noout -ext subjectAltName 2>/dev/null

        echo ""
        echo "=== EXPIRY CHECK ==="
        echo "" | openssl s_client -connect "$target:443" \
            -servername "$target" 2>/dev/null | \
            openssl x509 -noout -dates 2>/dev/null

        echo ""
        echo "=== CIPHER SUITE ==="
        openssl s_client -connect "$target:443" -cipher 'ALL:eNULL' \
            -servername "$target" 2>/dev/null | \
            grep "Cipher is"
    } | tee "$out"

    # Check expiry
    local expiry
    expiry=$(grep "notAfter" "$out" 2>/dev/null | head -1 | cut -d= -f2-)
    if [ -n "$expiry" ]; then
        local exp_ts; exp_ts=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null)
        local now_ts; now_ts=$(date +%s)
        local days_left=$(( (exp_ts - now_ts) / 86400 ))
        if [ "$days_left" -lt 0 ]; then
            log_critical "SSL Certificate মেয়াদ শেষ হয়ে গেছে! ($days_left days ago)"
        elif [ "$days_left" -lt 30 ]; then
            log_high "SSL Certificate মাত্র $days_left দিন বাকি!"
        else
            log_success "SSL Certificate valid। $days_left দিন বাকি।"
        fi
    fi

    # Extract SANs → extra subdomains
    grep -oE '[a-zA-Z0-9\-]+\.[a-zA-Z0-9\.\-]+' "$out" 2>/dev/null | \
        grep -v "^www\." | while read -r s; do
        FOUND_SUBDOMAINS+=("$s")
    done

    write_bangla "$OUTPUT_DIR/22_openssl_cert_bangla.txt" \
        "  OpenSSL Certificate — বাংলা বিশ্লেষণ" \
        "🔐 Certificate details বিশ্লেষণ সম্পন্ন।" \
        "${days_left:+📅 Certificate মেয়াদ: $days_left দিন বাকি।}" \
        "💡 SAN থেকে অতিরিক্ত subdomain বের হতে পারে।" \
        "   Expired cert থাকলে browser warning দেয়।"
}

# ── Robots.txt + Sitemap ──────────────────────────────────────────
run_robots_sitemap() {
    local target="$1"
    local out="$OUTPUT_DIR/23_robots_sitemap.txt"

    {
        echo "=== ROBOTS.TXT ==="
        curl -sf --max-time 10 "http://$target/robots.txt" 2>/dev/null || echo "Not found"
        echo ""
        echo "=== SITEMAP.XML ==="
        curl -sf --max-time 10 "http://$target/sitemap.xml" 2>/dev/null | \
            grep -oE '<loc>[^<]+</loc>' | sed 's/<\/?loc>//g' | head -30 || echo "Not found"
        echo ""
        echo "=== SITEMAP_INDEX.XML ==="
        curl -sf --max-time 10 "http://$target/sitemap_index.xml" 2>/dev/null | \
            grep -oE '<loc>[^<]+</loc>' | sed 's/<\/?loc>//g' | head -10 || echo "Not found"
    } | tee "$out"

    # Flag sensitive paths in robots.txt
    local sensitive
    sensitive=$(grep -iE "^Disallow:.*admin|login|config|backup|db|secret|private|api|internal" \
        "$out" 2>/dev/null)
    [ -n "$sensitive" ] && {
        log_medium "Robots.txt এ sensitive path পাওয়া গেছে!"
        echo "$sensitive" | while read -r l; do
            PHP_FILES+=("http://$target$(echo "$l" | awk '{print $2}')")
        done
    }

    # Extract sitemap URLs for testing
    grep -oE 'https?://[^ <]+' "$out" 2>/dev/null | while read -r url; do
        echo "$url" | grep -qE '\?' && PHP_FILES+=("$url")
    done

    write_bangla "$OUTPUT_DIR/23_robots_bangla.txt" \
        "  Robots.txt / Sitemap — বাংলা বিশ্লেষণ" \
        "$([ -n "$sensitive" ] && echo '🟡 Robots.txt এ sensitive path পাওয়া গেছে!' || echo '✅ Robots.txt এ কোনো sensitive path নেই।')" \
        "💡 Disallow path গুলো attacker কে target area জানিয়ে দেয়।" \
        "   Sitemap থেকে সব endpoint বের করা যায়।"
    reg_file "robots" "$out"
}

# ── MAIN HEADER RUNNER ────────────────────────────────────────────
run_header_analysis() {
    local target="$1"
    [ "$WEB_AVAILABLE" -eq 0 ] && log_warn "Web port নেই — Stage 2 skip।" && return
    show_stage 2 "HEADER & FINGERPRINT ANALYSIS"

    run_header_dump      "$target"
    run_cdn_detect       "$target"
    run_security_headers "$target"
    run_cookie_check     "$target"
    run_openssl_cert     "$target"
    run_robots_sitemap   "$target"

    echo ""
    echo -e "${CYAN}${BOLD}  [*] Header Analysis সিদ্ধান্ত:${NC}"
    [ "$HAS_CDN" -eq 1 ] && log_info "CDN: $CDN_NAME → কিছু scan blocked হতে পারে।"
    [ "$HAS_WAF" -eq 1 ] && log_warn "WAF: $WAF_NAME → Evasion technique প্রয়োজন।"
    echo ""
    save_state
}
