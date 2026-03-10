FROM kalilinux/kali-rolling:latest
LABEL maintainer="SAIMUM v3.0"
LABEL description="Web Vulnerability Automation Pipeline"

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Core tools
RUN apt-get update && apt-get install -y \
    nmap masscan whois dnsrecon tshark traceroute \
    nikto whatweb wafw00f curl wget git python3 python3-pip \
    hydra medusa john hashcat hashid \
    sslscan testssl.sh sslyze openssl \
    wkhtmltopdf sqlite3 dirb wfuzz gobuster \
    feroxbuster subfinder amass \
    && rm -rf /var/lib/apt/lists/*

# Go-based tools
RUN go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest 2>/dev/null || true && \
    go install github.com/tomnomnom/waybackurls@latest 2>/dev/null || true && \
    go install github.com/lc/gau/v2/cmd/gau@latest 2>/dev/null || true && \
    go install github.com/sensepost/gowitness@latest 2>/dev/null || true && \
    go install github.com/projectdiscovery/httpx/cmd/httpx@latest 2>/dev/null || true && \
    go install github.com/ffuf/ffuf/v2@latest 2>/dev/null || true && \
    go install github.com/hahwul/dalfox/v2@latest 2>/dev/null || true

# Python tools
RUN pip3 install --break-system-packages \
    paramspider arjun corscanner droopescan \
    xsstrike sslyze wpscan 2>/dev/null || true

# Install theHarvester
RUN git clone https://github.com/laramies/theHarvester.git /opt/theHarvester && \
    pip3 install --break-system-packages -r /opt/theHarvester/requirements.txt && \
    ln -s /opt/theHarvester/theHarvester.py /usr/local/bin/theHarvester

WORKDIR /saimum
COPY . /saimum/
RUN chmod +x /saimum/main_saimum.sh /saimum/modules/*.sh

# Update nuclei templates
RUN nuclei -update-templates 2>/dev/null || true

ENTRYPOINT ["/saimum/main_saimum.sh"]
