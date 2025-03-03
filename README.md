# NeXnetInt Network Interface Manager 🌐  

**Version:** 1.0.0 | **License:** MIT  

**Description:**  
A powerful utility for managing and switching network interfaces on Linux systems, ensuring optimized connectivity, seamless transitions, and unified traffic routing. NeXnetInt simplifies multi-NIC setups (e.g., Raspberry Pi with a 2.5Gbps NIC and 1Gbps onboard failover), prevents erratic behavior from default network managers, and ensures all system traffic (including Docker, SMB, VPN, DNS, etc.) is bound to the chosen interface to avoid exposure or conflicts.  

---

## 🧠 Why NeXnetInt?  

Managing multiple network interfaces on Linux can be complex, especially on systems like a Raspberry Pi where you might prefer a 2.5Gbps NIC over a 1Gbps onboard NIC, with the latter as a failover. Default network managers (e.g., `NetworkManager`, `netplan`) can behave erratically, causing conflicts that lead to traffic (Docker, SMB, VPN, DNS) splitting across interfaces, potentially exposing your system to ISP tracking or breaking service connectivity.  

NeXnetInt solves this with a single menu-driven interface to:  

- 🛡️ **Prevent Traffic Exposure**: Ensures all system traffic uses the chosen interface, avoiding leaks or splits that could expose your system to ISPs or break services.  
- 🚦 **Gracefully Manage Services**: Stops and restarts services (e.g., Docker, SMB) during NIC switches to maintain connectivity through the correct interface.  
- 🪢 **Flexible NIC Switching**: Switch interfaces temporarily (until reboot) or persistently (boot-level priority via systemd service).  
- 📊 **Simplify Multi-NIC Setups**: Ideal for servers, VPN gateways, or SBCs like Raspberry Pi, ensuring reliable failover and prioritization.  

---

## 🌟 Features  

### Core Capabilities  

| Feature                      | Solves                                                                                           |
|-----------------------------|--------------------------------------------------------------------------------------------------|
| 1-Click NIC Switching        | Swap interfaces without altering persistent configs. Revert anytime.                           |
| Persistent Interface Priority | Ensure a NIC (e.g., 2.5Gbps Ethernet) always takes precedence at boot, with failover to a secondary NIC (e.g., 1Gbps onboard). |
| Carrier Detection            | Automatically falls back to secondary NICs if the primary loses connection.                    |
| Unified Traffic Routing      | Binds all system traffic (Docker, SMB, VPN, DNS) to the chosen interface, preventing leaks.    |
| Non-invasive Design          | Your system default Network Managers are not going to be altered.                              |
| Stale State Cleanup          | Detects and clears invalid configs after reboots or hardware changes.                          |

### Technical Highlights  

✅ **MAC Address Binding** – Rules tied to hardware, not interface names (eth0/wlan0), ensuring reliability across reboots.  
✅ **Metric-Based Routing** – Prioritizes traffic through the chosen interface with dynamic routing adjustments.  
✅ **Systemd Service Integration** – Persistently enforces interface priority across reboots.  
✅ **Detailed Logging** – All actions logged to `/var/log/nexnetint/nexnetint.log` for troubleshooting.  

---

## 📦 Installation  

### 1-Line Install  

Download, extract, install, and clean up NeXnetInt with one command:  

#### Using `wget`:  

```bash
wget https://github.com/Arelius-D/NeXnetInt/releases/download/v1.0.0/NeXnetInt.tar.gz && \
tar -xzvf NeXnetInt.tar.gz && \
cd NeXnetInt && \
sudo chmod +x nexnetint.sh && \
sudo ./nexnetint.sh --initiate && \
cd .. && \
rm -rf NeXnetInt NeXnetInt.tar.gz
```

#### Using `curl`:  

```bash
curl -L https://github.com/Arelius-D/NeXnetInt/releases/download/v1.0.0/NeXnetInt.tar.gz -o NeXnetInt.tar.gz && \
tar -xzvf NeXnetInt.tar.gz && \
cd NeXnetInt && \
sudo chmod +x nexnetint.sh && \
sudo ./nexnetint.sh --initiate && \
cd .. && \
rm -rf NeXnetInt NeXnetInt.tar.gz
```

### After Installation:  

Run NeXnetInt from anywhere using:  

```bash
nexnetint
```

**Note:** NeXnetInt is installed system-wide in `/usr/local/bin/nexnetint`. The command above automatically removes the temporary NeXnetInt/ directory and tarball after installation.  

---

## 🖥️ Usage  

### Start the TUI  

```bash
sudo nexnetint
```

### Menu Workflows  

#### Temporary NIC Switch  

1. Navigate to option 3 in the menu.  
2. Your currently system default interface will be visualized 🌐  
3. Choose an interface that you would like to temporarily switch to (e.g., wlan0).  
4. Interfaces that are uninitiated (e.g., Wi-Fi that has not been configured or administratively blocked) will be excluded.  
5. NeXnetInt stops dependent services (e.g., Docker, SMB, etc.), updates routes, and applies the change.  
   - Prevents data corruption with no chance of IP leaks.  
   - SSH-safe.  
6. Upon revisiting option 3 in the menu during the same session (pre-reboot), you can revert with the 'R' option.  
   - Restores default routing and restarts services for proper functionality.  
7. The system default (pre-temporary switch) will be marked with 🌐, and the temporarily in-use (session default) NIC marked with ⚡.  

> **Note:** The temporary change will be reverted automatically after a system reboot!  

#### Configure & Setup Persistent Interface Priority Rules  

1. Navigate to option 4 in the menu.  
2. Select a primary interface (e.g., eth1) and a secondary interface (e.g., eth0) for failover.  
3. Confirm service installation to enforce this priority at boot.  
4. Reboot to apply the persistent priority.  

---

## 🛡️ Security & Reliability  

### **Traffic Protection**  
- Ensures all traffic is bound to the selected NIC, avoiding unwanted leaks.  
- Dynamically adjusts routing to maintain consistent network flow.  

### **Conflict Detection & Resolution**  
- Identifies and resolves conflicts with `NetworkManager`, `netplan`, or other network managers.  
- Offers a purge option to eliminate problematic managers.  

### **Reliable Routing Enforcement**  
- Implements a `systemd` service for persistent enforcement of interface priority.  
- Prevents network traffic from unintentionally switching interfaces.  

---

## ⭐ Like This Utility?  

🌟 [Star it on GitHub!](https://github.com/Arelius-D/NeXnetInt)  
🔔 **Stay updated**—[Watch for notifications](https://github.com/Arelius-D/NeXnetInt)  
💬 **Share ideas**: [GitHub Discussions](https://github.com/Arelius-D/NeXnetInt/discussions)  
🐞 **Found a bug?** [Report it here](https://github.com/Arelius-D/NeXnetInt/issues)  

💖 **Any form of contributions or donations is immensely appreciated.** [Sponsor here](https://github.com/sponsors/Arelius-D)  
# Credential test comment
