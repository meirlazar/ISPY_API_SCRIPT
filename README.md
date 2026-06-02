# 🕵️‍♂️ Agent DVR API Explorer & CLI Engine
**A powerful, interactive Bash terminal UI for navigating, executing, and batching Agent DVR API Commands locally.**

<img width="1197" height="994" alt="image" src="https://github.com/user-attachments/assets/d3d33c0a-3fc1-4b38-875f-0d97ef0d4529" />

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
### Disclaimer: This is an unofficial project for Ispy aka Agent DVR. 
I have no affilliation with Agent DVR whatsoever.
This was an independent project that I developed out of need for a Menu-driven API interface for Agent DVR and a love for BASH scripting.
Feel free to improve, change, or modify the code as you see fit.
Using this software, means you agree to not hold the developer(s), owner(s)/creator(s), etc. liable for any harm or damage through the use or misuse of this software.
In other words, use at your own risk.
