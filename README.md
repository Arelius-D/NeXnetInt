# 🌐 NeXnetInt - Network Interface Manager  
**Version:** 1.0.0 | **License:** MIT  

**Description:**  
Utility for managing and switching network interfaces on Debian-based Linux systems. It ensures optimized connectivity, seamless transitions, and unified traffic routing. By simplifying multi-NIC setups, it prevents erratic behavior from default network managers and binds all system traffic to the chosen interface, avoiding exposure or conflicts.  

## 🧠 Why NeXnetInt?  

Managing multiple network interfaces on Linux can be complex, especially on systems like a Raspberry Pi where you might prefer an external 2.5Gbps NIC over a 1Gbps onboard NIC. Default network managers (e.g., `NetworkManager`, `netplan`, `systemd-networkd`) can behave erratically if not configured meticulously, causing conflicts that split system traffic (including Docker, SMB, VPN, DNS, etc.) across interfaces or lead to IP leakage, exposing your system to ISP tracking and breaking service connectivity. **NeXnetInt** approaches every obstacle dynamically and provides a solution wrapped up in a single minimalistic TUI, eliminating all guesswork.  

## 🌟 Features  

- 🛡️ **Secure Traffic Routing**: Ensures all traffic is securely bound to the chosen interface, preventing leaks and disruptions.
- 🪢 **Flexible NIC Switching**: Switch interfaces temporarily (until reboot) or persistently (boot-level priority via `systemd service`).  
- 🚦 **Gracefully Manage Services**: Stops and restarts services (e.g., Docker, SMB) during NIC switches to maintain connectivity through the correct interface.  
- 📊 **Simplify Multi-NIC Setups**: Ideal for servers, VPN gateways, or SBCs like Raspberry Pi, Orange Pi, etc., ensuring reliable failover and prioritization.  
- 🤝 **Streamlined Automation**: Eliminates the need for manual modifications while ensuring a pristine networking setup with robust failover.  

### Core Capabilities  

| Feature                       | Solves                                                                                            |
|-------------------------------|---------------------------------------------------------------------------------------------------|
| 1-Click NIC Switching         | Swap interfaces without altering persistent configs. Revert anytime.                             |
| Persistent Interface Priority | Ensure a NIC (e.g., 2.5Gbps Ethernet) always takes precedence at boot, with failover to a secondary NIC (e.g., 1Gbps onboard). |
| Carrier Detection             | Automatically falls back to secondary NICs if the primary loses connection.                      |
| Unified Traffic Routing       | Binds all system traffic to the chosen interface, preventing unintentional switching and leaks.      |
| Non-invasive Design           | Your system’s default Network Managers are not altered.                                          |
| Stale State Cleanup           | Detects and clears invalid configs after reboots or hardware changes.                            |

### Technical Highlights  

✅ **MAC Address Binding** – Binds rules to MAC addresses rather than interface names (e.g., eth0, wlan0), ensuring reliability across reboots.  
✅ **Metric-Based Routing** – Prioritizes traffic through the chosen interface with dynamic routing adjustments.  
✅ **Systemd Service Integration** – Persistently enforces interface priority across reboots.  
✅ **Detailed Logging** – All actions logged to `/var/log/nexnetint/nexnetint.log` for troubleshooting.  



## 📦 Installation  
Download, extract, install and clean up with one command:  

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

## 🖥️ Usage 

Run **NeXnetInt** from anywhere using:  

```bash
nexnetint
```
- **Temporary NIC Switching**  Switch interfaces on the fly via the TUI.
	- 🌐 indicates the default interface, ⚡ the temporary one.
	- Changes revert on reboot or manually in the TUI.
- **Persistent Interface Priority**  Set boot-level NIC priorities with failover.
	- Configure via TUI or command line.
	- Uses a systemd service for persistence.

- ##### For command-line enthusiasts:
	- Install Service `nexnetint --install`
	- Purge Service `nexnetint --purge`

## ⭐ Like This Utility?  

🌟 [Star it on GitHub!](https://github.com/Arelius-D/NeXnetInt)  
🔔 **Stay updated**—[Watch for notifications](https://github.com/Arelius-D/NeXnetInt)  
💬 **Share ideas**: [GitHub Discussions](https://github.com/Arelius-D/NeXnetInt/discussions)  
🐞 **Found a bug?** [Report it here](https://github.com/Arelius-D/NeXnetInt/issues)  

💖 **Any form of contributions or donations is immensely appreciated.** [Sponsor here](https://github.com/sponsors/Arelius-D) 