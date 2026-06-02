# 🕵️‍♂️ Agent DVR API Explorer & CLI Engine
**A powerful, interactive Bash terminal UI for navigating, executing, and batching Agent DVR API Commands locally.**

<img width="1190" height="989" alt="image" src="https://github.com/user-attachments/assets/335df4f8-94ae-4f8b-babf-746915847a0f" />


![Bash](https://img.shields.io/badge/Language-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![OpenSSL](https://img.shields.io/badge/Vault-AES--256-721412?style=for-the-badge&logo=openssl&logoColor=white)
![JQ](https://img.shields.io/badge/Parser-JQ-302683?style=for-the-badge&logo=json&logoColor=white)

This project translates the massive Agent DVR Swagger/OpenAPI specification into an easy-to-use graphical Terminal UI. It natively parses your local `swagger.yaml` to dynamically build executable menus, parameters, and payloads without needing to manually write `curl` commands.

## ✨ Core Features

* 🚀 **Dynamic API Routing:** Instantly scans and renders endpoints from `swagger.yaml`. Color-codes methods (GET, POST, PUT, DELETE) and validates required vs optional parameters before execution.
* 🧠 **Smart Object Picker:** Automatically queries the API to fetch live Object IDs (`oid`), Object Types (`ot`), Groups, and Locations. Let `jq` do the heavy lifting of mapping IDs to Names so you don't have to remember them.
* ⚙️ **Batch Execution Engine:** Select `[ALL]` when picking devices, and the script will automatically iterate your payload against every camera/device on the system and aggregate the JSON responses into a single output file.
* 🔐 **Secure Credential Vault:** Don't leave passwords in plain text. Features a built-in interactive vault that encrypts API credentials using OpenSSL `AES-256-CBC`.
* 📊 **Format-Agnostic Exporter:** Output API responses directly to the terminal screen as auto-formatted tables, prettified JSON, or export directly to CSV and YAML files.

## 🛠️ Prerequisites

To run this utility, ensure your system has the following dependencies installed:

```bash
# Debian / Ubuntu
sudo apt install curl jq openssl python3 python3-yaml

# MacOS
brew install jq openssl python yq
```

🚀 Quick Start
Clone the repository:

Bash
```
git clone https://github.com/meirlazar/ISPY_API_SCRIPT.git
cd ISPY_API_SCRIPT
```
Setup your environment:
Place your latest Agent DVR swagger.yaml inside the DATA/ directory or use the modified or original that I have included.

Configure the target host:
Edit the top of ISPY_API.sh and point it to your local ISPY/Agent DVR server and port (example: 10.10.2.7:8090)

Bash
```
TARGET_HOST="x.x.x.x:8090" # your ip or hostname and port running the agentdvr service 
```
Launch the Explorer:

Bash
```
chmod +x ISPY_API.sh
./ISPY_API.sh
```

📖 How to Use
Create Credentials (Optional): Press 2 from the Main Menu to stash your username and password securely. The script handles the Basic Auth base64 encoding at runtime.

Search Endpoints: Press 1 to launch the wizard. You can type * (or Enter) to see everything, or filter by keywords like record or ptz.

Configure Parameters: The script will list all parameters for the chosen endpoint. Select a number to set its value.

Execute: Press E (or Enter) to run. You will be prompted on how you want to view or export the data.

🤝 Contributing
Pull requests are welcome. For major structural changes, please open an issue first to discuss what you would like to change.

### Disclaimer: This is an unofficial project for Ispy aka Agent DVR. 
I have no affilliation with Agent DVR whatsoever.
This was an independent project that I developed out of need for a Menu-driven API interface for Agent DVR and a love for BASH scripting.
Feel free to improve, change, or modify the code as you see fit.
Using this software, means you agree to not hold the developer(s), owner(s)/creator(s), etc. liable for any harm or damage through the use or misuse of this software.
In other words, use at your own risk.
