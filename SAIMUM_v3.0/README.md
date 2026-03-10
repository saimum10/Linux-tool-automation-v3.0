# SAIMUM v3.0 — Web Vulnerability Automation Pipeline

```
  ███████╗ █████╗ ██╗███╗   ███╗██╗   ██╗███╗   ███╗
  ╚════██╝█████╔╝ ██║████╗ ████║██║   ██║████╗ ████║
       ██╝█████╔╝ ██║██╔████╔██║██║   ██║██╔████╔██║
      ██╔╝██╔══╝  ██║██║╚██╔╝██║██║   ██║██║╚██╔╝██║
     ███████╗     ██║██║ ╚═╝ ██║╚██████╔╝██║ ╚═╝ ██║
     ╚══════╝     ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝     ╚═╝
```

> ⚠️ **For authorized penetration testing and educational use only.**

---

## 📁 Structure

```
saimum/
├── main_saimum.sh          ← Entry point
├── Dockerfile
├── modules/
│   ├── utils.sh            ← Engine, menus, logging, state
│   ├── recon.sh            ← Stage 1: Reconnaissance (18 tools)
│   ├── headers.sh          ← Stage 2: Header & Fingerprint (NEW)
│   ├── webscanning.sh      ← Stage 3: Web Scanning
│   ├── directory.sh        ← Stage 4: Directory Discovery
│   ├── injection.sh        ← Stage 5: Injection Testing
│   ├── auth.sh             ← Stage 6: Authentication Testing
│   ├── framework.sh        ← Stage 7: Framework & Exploits
│   ├── ssl.sh              ← Stage 8: SSL/TLS Testing
│   └── report.sh           ← Stage 9: Reporting
└── config/
    └── .saimum.conf.example
```

---

## 🚀 Usage

```bash
chmod +x main_saimum.sh modules/*.sh
./main_saimum.sh
```

### Docker
```bash
docker build -t saimum .
docker run -it --rm saimum
```

---

## ⚙️ Config

```bash
cp config/.saimum.conf.example ~/.saimum.conf
nano ~/.saimum.conf   # API keys, timeouts, paths edit করুন
```

---

## 🗂️ Stage Summary

| # | Stage | Key Tools |
|---|-------|-----------|
| 1 | Reconnaissance | nmap, masscan, subfinder, amass, crt.sh, httpx, gowitness |
| 2 | Header Analysis | curl, openssl, robots.txt, CSP/HSTS/Cookie audit |
| 3 | Web Scanning | nikto, nuclei, wpscan, droopescan, GraphQL, CORS |
| 4 | Directory | gobuster (dir/dns/vhost), ffuf (5 modes), wfuzz, feroxbuster |
| 5 | Injection | sqlmap, dalfox (pipe/blind), SSRF, JWT, XXE, SSTI |
| 6 | Auth | hydra (9 protocols), medusa, john/hashcat, spray |
| 7 | Framework | searchsploit, nuclei CVE, metasploit (6 modules), ZAP |
| 8 | SSL/TLS | sslscan, testssl.sh, sslyze, openssl cipher enum |
| 9 | Report | TXT + HTML + PDF + JSON, Bengali analysis, CVE refs |

---

## 📊 Scan Modes

| Mode | Speed | Noise | Coverage |
|------|-------|-------|----------|
| 🕵️ Stealth | Slow | Minimal | Basic |
| ⚖️ Normal | Medium | Moderate | Standard |
| 🔥 Aggressive | Fast | High | Maximum |

---

## ⏸️ Pause / Resume

```bash
# Pause করতে:
touch /tmp/.saimum_pause

# Resume: script আবার চালু করলেই resume option আসবে
```

---

## 📄 Reports

প্রতিটি scan এ তৈরি হয়:
- `report.txt` — Plain text + বাংলা বিশ্লেষণ
- `report.html` — Dark theme, screenshot embed
- `report.pdf` — Professional PDF (wkhtmltopdf)
- `report.json` — Machine-readable

---

*SAIMUM v3.0 — Authorized use only.*
