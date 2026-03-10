#!/bin/bash
# ================================================================
#   SAIMUM v3.0 — auth.sh — Stage 6: Authentication Testing
# ================================================================

DEFAULT_USERS="/tmp/saimum_users_$$.txt"
DEFAULT_PASS="/tmp/saimum_pass_$$.txt"

prepare_credentials() {
    cat > "$DEFAULT_USERS" << 'EOF'
admin
root
administrator
user
test
guest
manager
webmaster
operator
support
service
backup
deploy
db
mysql
postgres
ftp
ssh
oracle
ubuntu
EOF

    cat > "$DEFAULT_PASS" << 'EOF'
admin
password
123456
admin123
root
toor
pass
test
guest
qwerty
letmein
welcome
1234
12345678
password123
changeme
default
abc123
111111
admin@123
P@ssword
Password1
Summer2024
Winter2024
company123
EOF
}

_hydra_threads() {
    case "$SCAN_MODE" in
        1) echo "-t 1 -W 3" ;;
        2) echo "-t 4" ;;
        3) echo "-t 16" ;;
    esac
}

run_hydra_ssh() {
    local target="$1"
    local out="$OUTPUT_DIR/48_hydra_ssh.txt"
    command -v hydra &>/dev/null || { log_skip "hydra SSH"; return; }
    [ "$SSH_OPEN" -eq 0 ] && return

    local t; t=$(_hydra_threads)
    run_tool "Hydra SSH" \
        "hydra -L $DEFAULT_USERS -P $DEFAULT_PASS $t ssh://$target -o $out" \
        "$out" "$TIMEOUT_HYDRA"

    grep -qi "\[22\].*login:" "$out" 2>/dev/null && \
        log_critical "SSH Weak Credentials পাওয়া গেছে!"

    write_bangla "$OUTPUT_DIR/48_hydra_ssh_bangla.txt" \
        "  Hydra SSH — বাংলা বিশ্লেষণ" \
        "$(grep -qi '\[22\].*login:' "$out" 2>/dev/null && echo '🔴 CRITICAL: SSH weak credentials!' || echo '✅ SSH common credentials কাজ করেনি।')" \
        "🔧 Fix: SSH key auth ব্যবহার করুন, password auth বন্ধ করুন।"
}

run_hydra_ftp() {
    local target="$1"
    local out="$OUTPUT_DIR/49_hydra_ftp.txt"
    command -v hydra &>/dev/null || { log_skip "hydra FTP"; return; }
    [ "$FTP_OPEN" -eq 0 ] && return

    # Anonymous check first
    local anon="$OUTPUT_DIR/49b_ftp_anon.txt"
    run_tool "nmap FTP-anon" "nmap --script ftp-anon -p 21 $target" "$anon" 30
    grep -qi "Anonymous FTP login allowed" "$anon" 2>/dev/null && \
        log_critical "FTP Anonymous Login Allowed!"

    local t; t=$(_hydra_threads)
    run_tool "Hydra FTP" \
        "hydra -L $DEFAULT_USERS -P $DEFAULT_PASS $t ftp://$target -o $out" \
        "$out" "$TIMEOUT_HYDRA"
    grep -qi "\[21\].*login:" "$out" 2>/dev/null && \
        log_critical "FTP Weak Credentials পাওয়া গেছে!"

    write_bangla "$OUTPUT_DIR/49_hydra_ftp_bangla.txt" \
        "  Hydra FTP — বাংলা বিশ্লেষণ" \
        "$(grep -qi 'Anonymous.*allowed' "$anon" 2>/dev/null && echo '🔴 FTP Anonymous access চালু!' || echo '✅ Anonymous FTP disabled।')" \
        "$(grep -qi '\[21\].*login:' "$out" 2>/dev/null && echo '🔴 FTP weak password!' || echo '✅ FTP credentials কাজ করেনি।')"
}

run_hydra_http() {
    local target="$1"
    local out="$OUTPUT_DIR/50_hydra_http.txt"
    command -v hydra &>/dev/null || { log_skip "hydra HTTP"; return; }
    [ ${#LOGIN_PAGES[@]} -eq 0 ] && { log_info "Login page নেই — HTTP auth skip।"; return; }

    local t; t=$(_hydra_threads)
    run_tool "Hydra HTTP" \
        "hydra -L $DEFAULT_USERS -P $DEFAULT_PASS $target http-form-post '/login:username=^USER^&password=^PASS^:Invalid' $t -o $out" \
        "$out" "$TIMEOUT_HYDRA"

    grep -qi "login:" "$out" 2>/dev/null && \
        log_critical "HTTP Login Weak credentials পাওয়া গেছে!"

    write_bangla "$OUTPUT_DIR/50_hydra_http_bangla.txt" \
        "  Hydra HTTP — বাংলা বিশ্লেষণ" \
        "$(grep -qi 'login:' "$out" 2>/dev/null && echo '🔴 Web login weak password!' || echo '✅ Common credentials কাজ করেনি।')" \
        "🔧 Fix: Account lockout, 2FA, strong password policy।"
}

run_hydra_rdp() {
    local target="$1"
    local out="$OUTPUT_DIR/51_hydra_rdp.txt"
    command -v hydra &>/dev/null || { log_skip "hydra RDP"; return; }
    [ "$RDP_OPEN" -eq 0 ] && return

    local t; t=$(_hydra_threads)
    run_tool "Hydra RDP" \
        "hydra -L $DEFAULT_USERS -P $DEFAULT_PASS $t rdp://$target -o $out" \
        "$out" "$TIMEOUT_HYDRA"

    grep -qi "\[3389\].*login:" "$out" 2>/dev/null && \
        log_critical "RDP Weak Credentials পাওয়া গেছে!"

    write_bangla "$OUTPUT_DIR/51_hydra_rdp_bangla.txt" \
        "  Hydra RDP — বাংলা বিশ্লেষণ" \
        "$(grep -qi '\[3389\].*login:' "$out" 2>/dev/null && echo '🔴 RDP weak credentials!' || echo '✅ RDP credentials কাজ করেনি।')"
}

run_hydra_extra() {
    local target="$1"
    local t; t=$(_hydra_threads)

    # Telnet
    if [ "$TELNET_OPEN" -eq 1 ] && command -v hydra &>/dev/null; then
        local out="$OUTPUT_DIR/52_hydra_telnet.txt"
        run_tool "Hydra Telnet" \
            "hydra -L $DEFAULT_USERS -P $DEFAULT_PASS $t telnet://$target -o $out" \
            "$out" "$TIMEOUT_HYDRA"
        grep -qi "\[23\].*login:" "$out" 2>/dev/null && \
            log_critical "Telnet Weak Credentials পাওয়া গেছে!"
    fi

    # MySQL
    if [ "$MYSQL_OPEN" -eq 1 ] && command -v hydra &>/dev/null; then
        local out="$OUTPUT_DIR/53_hydra_mysql.txt"
        run_tool "Hydra MySQL" \
            "hydra -L $DEFAULT_USERS -P $DEFAULT_PASS $t mysql://$target -o $out" \
            "$out" "$TIMEOUT_HYDRA"
        grep -qi "\[3306\].*login:" "$out" 2>/dev/null && \
            log_critical "MySQL Weak Credentials পাওয়া গেছে!"
    fi

    # SMTP
    if [ "$SMTP_OPEN" -eq 1 ] && command -v hydra &>/dev/null; then
        local out="$OUTPUT_DIR/54_hydra_smtp.txt"
        run_tool "Hydra SMTP" \
            "hydra -L $DEFAULT_USERS -P $DEFAULT_PASS $t smtp://$target -o $out" \
            "$out" "$TIMEOUT_HYDRA"
    fi

    # SMB
    if [ "$SMB_OPEN" -eq 1 ] && command -v hydra &>/dev/null; then
        local out="$OUTPUT_DIR/55_hydra_smb.txt"
        run_tool "Hydra SMB" \
            "hydra -L $DEFAULT_USERS -P $DEFAULT_PASS $t smb://$target -o $out" \
            "$out" "$TIMEOUT_HYDRA"
        grep -qi "\[445\].*login:" "$out" 2>/dev/null && \
            log_critical "SMB Weak Credentials পাওয়া গেছে!"
    fi

    # VNC
    if [ "$VNC_OPEN" -eq 1 ] && command -v hydra &>/dev/null; then
        local out="$OUTPUT_DIR/56_hydra_vnc.txt"
        run_tool "Hydra VNC" \
            "hydra -P $DEFAULT_PASS $t vnc://$target -o $out" \
            "$out" "$TIMEOUT_HYDRA"
    fi

    # PostgreSQL
    if [ "$POSTGRES_OPEN" -eq 1 ] && command -v hydra &>/dev/null; then
        local out="$OUTPUT_DIR/57_hydra_postgres.txt"
        run_tool "Hydra PostgreSQL" \
            "hydra -L $DEFAULT_USERS -P $DEFAULT_PASS $t postgres://$target -o $out" \
            "$out" "$TIMEOUT_HYDRA"
    fi
}

run_medusa() {
    local target="$1"
    local out="$OUTPUT_DIR/58_medusa.txt"
    command -v medusa &>/dev/null || { log_skip "medusa"; return; }
    command -v hydra &>/dev/null && [ "$SCAN_MODE" -ne 3 ] && return

    local proto="ssh"
    [ "$FTP_OPEN"      -eq 1 ] && proto="ftp"
    [ "$MYSQL_OPEN"    -eq 1 ] && proto="mysql"
    [ "$POSTGRES_OPEN" -eq 1 ] && proto="postgres"
    [ "$SMB_OPEN"      -eq 1 ] && proto="smbnt"
    [ "$SSH_OPEN"      -eq 1 ] && proto="ssh"

    run_tool "Medusa" \
        "medusa -h $target -U $DEFAULT_USERS -P $DEFAULT_PASS -M $proto -t 4 -f" \
        "$out" "$TIMEOUT_HYDRA"

    grep -qi "SUCCESS" "$out" 2>/dev/null && \
        log_critical "Medusa — Credentials found! ($proto)"

    write_bangla "$OUTPUT_DIR/58_medusa_bangla.txt" \
        "  Medusa — বাংলা বিশ্লেষণ" \
        "🔐 Protocol tested: $proto" \
        "$(grep -qi 'SUCCESS' "$out" 2>/dev/null && echo '🔴 Weak credentials পাওয়া গেছে!' || echo '✅ Common credentials কাজ করেনি।')"
}

run_john() {
    local out="$OUTPUT_DIR/59_john.txt"
    command -v john &>/dev/null || { log_skip "john"; return; }
    [ ${#FOUND_HASHES[@]} -eq 0 ] && { log_info "Hash নেই — John skip।"; return; }

    local hf="/tmp/saimum_hashes_$$.txt"
    printf '%s\n' "${FOUND_HASHES[@]}" > "$hf"
    run_tool "John the Ripper" "john --wordlist=$DEFAULT_PASS $hf" "$out" 180

    local cracked; cracked=$(john --show "$hf" 2>/dev/null | grep -c ":")
    [ "$cracked" -gt 0 ] && log_critical "John — $cracked টি password crack হয়েছে!"

    write_bangla "$OUTPUT_DIR/59_john_bangla.txt" \
        "  John the Ripper — বাংলা বিশ্লেষণ" \
        "🔐 Hash: ${#FOUND_HASHES[@]} | Cracked: $cracked" \
        "$([ $cracked -gt 0 ] && echo '🔴 CRITICAL: Hash crack সফল!' || echo '✅ Common wordlist দিয়ে crack হয়নি।')" \
        "🔧 Fix: bcrypt বা Argon2 ব্যবহার করুন।"
    rm -f "$hf"
}

run_hashcat() {
    local out="$OUTPUT_DIR/60_hashcat.txt"
    command -v hashcat &>/dev/null || { log_skip "hashcat"; return; }
    [ ${#FOUND_HASHES[@]} -eq 0 ] && { log_info "Hash নেই — Hashcat skip।"; return; }
    [ "$HAS_GPU" -eq 0 ] && { log_info "GPU নেই — John ব্যবহার হয়েছে।"; return; }

    local hf="/tmp/saimum_hashes_$$.txt"
    printf '%s\n' "${FOUND_HASHES[@]}" > "$hf"
    local mode; mode=$(detect_hash_type "${FOUND_HASHES[0]}")

    # Dictionary attack
    run_tool "Hashcat Dictionary" \
        "hashcat -m $mode -a 0 $hf $DEFAULT_PASS --force --quiet" \
        "$out" 180

    # Mask attack (aggressive)
    if [ "$SCAN_MODE" -eq 3 ]; then
        local out_mask="$OUTPUT_DIR/60b_hashcat_mask.txt"
        run_tool "Hashcat Mask" \
            "hashcat -m $mode -a 3 $hf '?u?l?l?l?d?d?d?' --force --quiet" \
            "$out_mask" 300
    fi

    grep -qi "Cracked" "$out" 2>/dev/null && \
        log_critical "Hashcat — Hash crack সফল!"

    write_bangla "$OUTPUT_DIR/60_hashcat_bangla.txt" \
        "  Hashcat — বাংলা বিশ্লেষণ" \
        "⚡ GPU hash crack সম্পন্ন। Mode: $mode" \
        "$(grep -qi 'Cracked' "$out" 2>/dev/null && echo '🔴 CRITICAL: Hash cracked!' || echo '✅ Wordlist দিয়ে crack হয়নি।')"
    rm -f "$hf"
}

run_password_spray() {
    local target="$1"
    [ "$SCAN_MODE" -ne 3 ] && return
    [ "$SSH_OPEN" -eq 0 ] && [ "$SMB_OPEN" -eq 0 ] && return

    log_info "Password spray (rate-limited) শুরু হচ্ছে..."
    local spray_pass=("Summer2024" "Winter2024" "Password1" "Welcome1" "Company123")

    for pass in "${spray_pass[@]}"; do
        log_info "Spray: $pass (1 attempt per user)"
        sleep 30   # Rate limit — lockout এড়ানোর জন্য
        if [ "$SSH_OPEN" -eq 1 ] && command -v hydra &>/dev/null; then
            hydra -L "$DEFAULT_USERS" -p "$pass" -t 1 -W 5 \
                "ssh://$target" >> "$OUTPUT_DIR/61_spray.txt" 2>/dev/null
        fi
    done
    reg_file "spray" "$OUTPUT_DIR/61_spray.txt"
}

run_auth_testing() {
    local target="$1"

    if [ "$SSH_OPEN" -eq 0 ] && [ "$FTP_OPEN" -eq 0 ] && [ "$RDP_OPEN" -eq 0 ] && \
       [ "$TELNET_OPEN" -eq 0 ] && [ "$MYSQL_OPEN" -eq 0 ] && [ "$SMB_OPEN" -eq 0 ] && \
       [ ${#LOGIN_PAGES[@]} -eq 0 ] && [ ${#FOUND_HASHES[@]} -eq 0 ]; then
        log_info "Auth testing এর জন্য কিছু পাওয়া যায়নি — Stage 6 skip।"
        return
    fi

    show_stage 6 "AUTHENTICATION & PASSWORD TESTING"
    prepare_credentials

    echo -e "${CYAN}  [*] Auth testing সিদ্ধান্ত:${NC}"
    [ "$SSH_OPEN"       -eq 1 ] && log_info "SSH → hydra"
    [ "$FTP_OPEN"       -eq 1 ] && log_info "FTP → hydra + anonymous check"
    [ "$RDP_OPEN"       -eq 1 ] && log_info "RDP → hydra"
    [ "$TELNET_OPEN"    -eq 1 ] && log_info "Telnet → hydra"
    [ "$MYSQL_OPEN"     -eq 1 ] && log_info "MySQL → hydra"
    [ "$SMB_OPEN"       -eq 1 ] && log_info "SMB → hydra"
    [ "$VNC_OPEN"       -eq 1 ] && log_info "VNC → hydra"
    [ "$POSTGRES_OPEN"  -eq 1 ] && log_info "PostgreSQL → hydra"
    [ ${#LOGIN_PAGES[@]} -gt 0 ] && log_info "Login page → HTTP brute"
    echo ""

    run_hydra_ssh   "$target"
    run_hydra_ftp   "$target"
    run_hydra_http  "$target"
    run_hydra_rdp   "$target"
    run_hydra_extra "$target"
    run_medusa      "$target"
    run_password_spray "$target"

    if [ ${#FOUND_HASHES[@]} -gt 0 ]; then
        [ "$HAS_GPU" -eq 1 ] && run_hashcat || run_john
    fi

    rm -f "$DEFAULT_USERS" "$DEFAULT_PASS"
    save_state
}
