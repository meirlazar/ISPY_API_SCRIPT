#!/usr/bin/env bash
# ==============================================================================
# SYNOPSIS
#   Agent DVR API Explorer - UI/UX Upgraded Edition v2.0
# ==============================================================================

VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDS_DIR="${SCRIPT_DIR}/CREDS"
LOGS_DIR="${SCRIPT_DIR}/LOGS"
DATA_DIR="${SCRIPT_DIR}/DATA"

mkdir -p "$CREDS_DIR" "$LOGS_DIR" "$DATA_DIR"

# ================= CONFIGURATION =================
TARGET_HOST="agentdvr-host.home.local:8090"                        # update the target host with either an ip address or hostname and port
BASE_URL="http://${TARGET_HOST}"
SWAGGER_FILE="${DATA_DIR}/swagger.yaml"                # the swagger has been modified to include the locations and groups options or you can use the original one

# ================= COLORS & FORMATTING =================
C_DEF="\033[0m"
C_BLD="\033[1m"
C_DIM="\033[90m"
C_RED="\033[31m"
C_GRN="\033[32m"
C_YLW="\033[33m"
C_BLU="\033[34m"
C_MAG="\033[35m"
C_CYN="\033[36m"
C_WHT="\033[37m"

function draw_banner() {
    clear
    echo -e "${C_CYN}${C_BLD}"
    echo "        ___                   __      ___ _    __ __   __ "
    echo "       /   |  ____  ___  ____/ /_    / __ \ | / / _ \ / / "
    echo "      / /| | / __ \/ _ \/ __   __|  / / / / |/ / , _// /  "
    echo "     / ___ |/ /_/ /  __/ / / / /_  / /_/ /|   / /| |/_/   "
    echo "    /_/  |_|\__, /\___/_/ /_/\__/ /_____/ |__/_/ |_(_)    "
    echo "           /____/                                         "
    echo -e "${C_WHT}      A P I   E X P L O R E R   &   E N G I N E       "
    echo -e "${C_CYN}╭─────────────────────────────────────────────────────────────────────────────╮"
    echo -e "${C_DEF}|                        Target: ${C_WHT}${TARGET_HOST}${C_CYN}                            | "
    echo -e "${C_DEF}|                              Version: ${C_WHT}${VERSION}${C_CYN}                                 | "
    echo -e "╰─────────────────────────────────────────────────────────────────────────────╯${C_DEF}\n"
}

# ================= SECURITY & VAULT =================

function read_secret() {
    local prompt="$1"
    local secret
    read -r -s -p "$prompt: " secret
    echo "$secret"
}

function new_creds() {
    echo -e "\n${C_MAG}${C_BLD}╭── Create Credential Set ──────────────────────────────╮${C_DEF}"
    read -r -p "│ Enter Username (or Set ID): " USERNAME
    if [[ -z "$USERNAME" ]]; then echo -e "│ ${C_RED}Aborted.${C_DEF}"; return; fi
    
    PASSWORD=$(read_secret "│ Enter Password for $USERNAME")
    echo ""
    
    local SAFE_NAME=$(echo "$USERNAME" | tr -cd '[:alnum:]_.-')
    local KEY_PATH="${CREDS_DIR}/${SAFE_NAME}.key"
    local CRED_PATH="${CREDS_DIR}/${SAFE_NAME}.creds"

    openssl rand -hex 32 > "$KEY_PATH"
    echo -n "$PASSWORD" | openssl enc -aes-256-cbc -pbkdf2 -pass "file:$KEY_PATH" -out "$CRED_PATH" 2>/dev/null
    
    echo -e "╰── ${C_GRN}Credentials saved securely for: $USERNAME${C_DEF} ─────────╯"
}

function get_creds() {
    local USERNAME="$1"
    local SAFE_NAME=$(echo "$USERNAME" | tr -cd '[:alnum:]_.-')
    local KEY_PATH="${CREDS_DIR}/${SAFE_NAME}.key"
    local CRED_PATH="${CREDS_DIR}/${SAFE_NAME}.creds"

    if [[ ! -f "$KEY_PATH" || ! -f "$CRED_PATH" ]]; then
        echo -e "${C_RED}ERROR: Credentials missing for $USERNAME${C_DEF}" >&2
        return 1
    fi
    openssl enc -d -aes-256-cbc -pbkdf2 -pass "file:$KEY_PATH" -in "$CRED_PATH" 2>/dev/null
}

# ================= LOCAL SWAGGER PARSING =================

function load_local_swagger() {
    if [[ ! -f "$SWAGGER_FILE" ]]; then
        echo -e "${C_RED}ERROR: Swagger file not found at $SWAGGER_FILE${C_DEF}" >&2
        return 1
    fi
    if command -v python3 &>/dev/null && python3 -c "import yaml" &>/dev/null; then
        python3 -c 'import yaml, json, sys; json.dump(yaml.safe_load(sys.stdin), sys.stdout)' < "$SWAGGER_FILE"
    elif command -v yq &>/dev/null; then
        yq eval -o=j "$SWAGGER_FILE"
    else
        echo -e "${C_RED}ERROR: Cannot parse YAML. Install 'python3' and 'pyyaml' OR 'yq'.${C_DEF}" >&2
        return 1
    fi
}

# ================= SMART OBJECT PICKER =================

function select_agent_object() {
    local TARGET_PARAM="$1"
    local CMD_URI="${BASE_URL}/command.cgi?cmd=getobjects"
    echo -e "\n${C_CYN}${C_BLD}[Smart Picker]${C_DEF} Fetching active ${TARGET_PARAM}s..."

    local RESULT=$(curl -s -X GET "$CMD_URI" -H "Accept: application/json" ${AUTH_HEADER:+-H "$AUTH_HEADER"})

    if grep -iEq "^groups?$" <<< "${TARGET_PARAM,,}"; then
        mapfile -t AVAILABLE_ITEMS < <(echo "$RESULT" | jq -r '.objectList[]? | select(.groups != null and .groups != "") | .groups' | sort -u)
    elif grep -iEq "^locations?$" <<< "${TARGET_PARAM,,}"; then
        mapfile -t AVAILABLE_ITEMS < <(echo "$RESULT" | jq -r '.locations[]?.name | select(. != null and . != "")' | sort -u)
    elif grep -iEq "^(oid|ot)$" <<< "${TARGET_PARAM,,}"; then
        local JQ_FILTER='.objectList[]? | select(.typeID == 1 or .typeID == 2) | "\(.id) [Type:\(.typeID)] \(.name) (Alerts: \(.data.alertsActive | if .==true then "On" else "Off" end), Detect: \(.data.detectorActive | if .==true then "On" else "Off" end))"'
        mapfile -t OBJ_ARRAY < <(echo "$RESULT" | jq -r "$JQ_FILTER" | tr -d '"')
        AVAILABLE_ITEMS=("${OBJ_ARRAY[@]}")
    fi

    if [[ ${#AVAILABLE_ITEMS[@]} -eq 0 ]]; then
        echo -e "  ${C_YLW}No items found.${C_DEF}"
        read -r -p "Enter manual value for $TARGET_PARAM: " MAN_VAL
        if [[ -n "$MAN_VAL" ]]; then PARAM_VALUES["$TARGET_PARAM"]="$MAN_VAL"; fi
        return
    fi

    echo -e "\n${C_MAG}${C_BLD}╭── AVAILABLE ${TARGET_PARAM^^}S ────────────────────────────────────╮${C_DEF}"
    for i in "${!AVAILABLE_ITEMS[@]}"; do  
        echo -e "│ ${C_GRN}${C_BLD}$((i+1)))${C_DEF} ${AVAILABLE_ITEMS[$i]}"
    done
    echo -e "├────────────────────────────────────────────────────┤"
    echo -e "│ ${C_GRN}${C_BLD}0 or A)${C_DEF} [ALL] (Apply to all targets in batch)        │"
    echo -e "╰────────────────────────────────────────────────────╯"

    read -r -p "Select ${TARGET_PARAM} (comma-separated for multi) or Enter for ALL: " GRP_SEL

    if [[ -z "$GRP_SEL" || "$GRP_SEL" == "0" || "${GRP_SEL^^}" == "ALL" || "${GRP_SEL^^}" == "A" ]]; then
        PARAM_VALUES["$TARGET_PARAM"]="ALL"
        if grep -iEq "^(oid|ot)$" <<< "${TARGET_PARAM,,}"; then
            echo -e "  ${C_GRN}>> Auto-selected ALL Devices for Batch Execution${C_DEF}"
            if printf "%s\n" "${PARAMS_ARRAY[@]}" | grep -q "^oid|"; then PARAM_VALUES["oid"]="ALL"; fi
            if printf "%s\n" "${PARAMS_ARRAY[@]}" | grep -q "^ot|"; then PARAM_VALUES["ot"]="ALL"; fi
        else
            echo -e "  ${C_GRN}>> Auto-selected ALL${C_DEF}"
        fi
        sleep 1
        return
    fi

    IFS=',' read -ra SEL_ARRAY <<< "$GRP_SEL"
    local FINAL_VALUES=() FINAL_OIDS=() FINAL_OTS=()

    for idx in "${SEL_ARRAY[@]}"; do
        idx="${idx// /}"
        if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx > 0 && idx <= ${#AVAILABLE_ITEMS[@]} )); then
            local SELECTED_STR="${AVAILABLE_ITEMS[$((idx-1))]}"
            if grep -iEq "^(oid|ot)$" <<< "${TARGET_PARAM,,}"; then
                FINAL_OIDS+=("$(echo "$SELECTED_STR" | awk '{print $1}')")
                FINAL_OTS+=("$(echo "$SELECTED_STR" | awk -F'\\[Type:' '{print $2}' | awk -F'\\]' '{print $1}')")
            else
                FINAL_VALUES+=("$SELECTED_STR")
            fi
        else
            grep -iEq "^(oid|ot)$" <<< "${TARGET_PARAM,,}" && FINAL_OIDS+=("$idx") || FINAL_VALUES+=("$idx")
        fi
    done

    if grep -iEq "^(oid|ot)$" <<< "${TARGET_PARAM,,}"; then
        local JOINED_OIDS=$(IFS=','; echo "${FINAL_OIDS[*]}")
        local JOINED_OTS=$(IFS=','; echo "${FINAL_OTS[*]}")
        echo -e "  ${C_GRN}>> Auto-selected OID(s): $JOINED_OIDS${C_DEF}"
        
        if [[ "$TARGET_PARAM" == "oid" ]]; then
            PARAM_VALUES["oid"]="$JOINED_OIDS"
            if printf "%s\n" "${PARAMS_ARRAY[@]}" | grep -q "^ot|"; then
                 PARAM_VALUES["ot"]="$JOINED_OTS"
                 echo -e "  ${C_GRN} ↳ Auto-assigned matching 'ot': $JOINED_OTS${C_DEF}"
            fi
        else
            PARAM_VALUES["ot"]="$JOINED_OTS"
            if printf "%s\n" "${PARAMS_ARRAY[@]}" | grep -q "^oid|"; then
                 PARAM_VALUES["oid"]="$JOINED_OIDS"
                 echo -e "  ${C_GRN} ↳ Auto-assigned matching 'oid': $JOINED_OIDS${C_DEF}"
            fi
        fi
    else
        local JOINED_VALS=$(IFS=','; echo "${FINAL_VALUES[*]}")
        PARAM_VALUES["$TARGET_PARAM"]="$JOINED_VALS"
        echo -e "  ${C_GRN}>> Auto-selected: $JOINED_VALS${C_DEF}"
    fi
    sleep 1
}

# ================= OUTPUT ENGINE (LOOPING) =================

function render_output() {
    local RESULT="$1"
    local EP_PATH="$2"
    
    while true; do
        echo -e "\n${C_CYN}${C_BLD}╭── OUTPUT OPTIONS ─────────────────────────────────────────────────────────────────────────╮${C_DEF}"
        echo -e "│ ${C_WHT}1)${C_DEF} Screen: Auto-Formatted Table                                                           │"
        echo -e "│ ${C_WHT}2)${C_DEF} Screen: Prettified JSON                                                                │"
        echo -e "│ ${C_WHT}3)${C_DEF} Screen: YAML format                                                                    │"
        echo -e "│ ${C_WHT}4)${C_DEF} Screen: Raw API Response                                                               │"
        echo -e "│ ${C_WHT}5)${C_DEF} Export: JSON File                                                                      │"
        echo -e "│ ${C_WHT}6)${C_DEF} Export: YAML File                                                                      │"
        echo -e "│ ${C_WHT}7)${C_DEF} Export: CSV File (Choose delimiter)                                                    │"
        echo -e "├───────────────────────────────────────────────────────────────────────────────────────────┤"
        echo -e "│ ${C_YLW}${C_BLD}B)${C_DEF} Go Back        ${C_RED}${C_BLD}M)${C_DEF} Main Menu                                                            │"
        echo -e "╰───────────────────────────────────────────────────────────────────────────────────────────╯"
        read -r -p "Choose format [1-7, B, M]: " OUT_CHOICE
        OUT_CHOICE=${OUT_CHOICE:='M'}
        
        local SAFE_NAME=$(echo "${EP_PATH##*/}" | tr -cd '[:alnum:]_')
        local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

        case "${OUT_CHOICE^^}" in
            1)
                echo -e "\n${C_GRN}${C_BLD}[ TABLE OUTPUT ]${C_DEF}\n${C_DIM}─────────────────────────────────────────────────────────────────${C_DEF}"
                echo "$RESULT" | jq -r '(if type == "array" then . elif type == "object" and .items then .items else [.] end) | (.[0] | keys_unsorted) as $keys | $keys, map([.[ $keys[] ] | tostring])[] | @tsv' 2>/dev/null | column -t -s $'\t' || echo -e "${C_RED}Failed to render table.\n${C_DEF}$RESULT"
                ;;
            2)
                echo -e "\n${C_GRN}${C_BLD}[ PRETTIFIED JSON ]${C_DEF}\n${C_DIM}─────────────────────────────────────────────────────────────────${C_DEF}"
                echo "$RESULT" | jq . || echo "$RESULT"
                ;;
            5)
                local OUT_FILE="${LOGS_DIR}/Export_${SAFE_NAME}_${TIMESTAMP}.json"
                echo "$RESULT" | jq . > "$OUT_FILE" 2>/dev/null || echo "$RESULT" > "$OUT_FILE"
                echo -e "${C_GRN}Saved JSON to $OUT_FILE${C_DEF}"
                ;;
            B) return 0 ;;
            M) return 1 ;;
            *) echo -e "${C_RED}Invalid selection.${C_DEF}" ;;
        esac
    done
}

# ================= DYNAMIC EXPLORER =================

function dynamic_explorer() {
    local SCHEMA=$(load_local_swagger)
    if [[ -z "$SCHEMA" ]]; then return; fi

    draw_banner
    read -r -p "Enter username to execute as (leave blank for unauth): " EXEC_USER
    local AUTH_HEADER=""
    
    if [[ -n "$EXEC_USER" ]]; then
        local PASSWORD=$(get_creds "$EXEC_USER")
        if [[ $? -ne 0 ]]; then return; fi
        AUTH_HEADER="Authorization: Basic $(echo -n "${EXEC_USER}:${PASSWORD}" | base64)"
    fi

    echo ""
    read -r -p "Search keyword for endpoints (e.g., 'schedule', '*' for all): " KEYWORD
    
    local JQ_FILTER='.paths | to_entries[] | .key as $path | .value | to_entries[] | "\($path)|\(.key|ascii_upcase)|\(.value.summary // "No summary")"'
   
       if [[ "$KEYWORD" == "*" ]]; then local MATCHES=$(echo "$SCHEMA" | jq -r "$JQ_FILTER");  else
        local MATCHES=$(echo "$SCHEMA" | jq -r "$JQ_FILTER" | grep -i "$KEYWORD");  fi
   

    if [[ -z "$MATCHES" ]]; then echo -e "${C_YLW}No matching endpoints found.${C_DEF}"; sleep 2; return; fi

    mapfile -t ENDPOINT_ARRAY <<< "$MATCHES"
    
    # --- LEVEL 1: ENDPOINT SELECTION LOOP ---
    while true; do
        draw_banner
        echo -e "${C_CYN}${C_BLD}╭── MATCHING ENDPOINTS ──────────────────────────────────────────────────────────────────────────────────────────────╮${C_DEF}"
        printf "│ ${C_WHT}${C_BLD}%-3s${C_DEF} │ ${C_WHT}${C_BLD}%-4s${C_DEF} │ ${C_WHT}${C_BLD}%-33s${C_DEF} │ ${C_WHT}${C_BLD}%-66s${C_DEF}│\n" "ID" "TYPE" "ENDPOINT PATH" "SUMMARY"
        echo -e "├─────┼──────┼────────────────────────────────────────┼──────────────────────────────────────────────────────────────┤"
        
        local i=1
        for item in "${ENDPOINT_ARRAY[@]}"; do
            IFS='|' read -r EP_PATH EP_METHOD EP_SUMMARY <<< "$item"
            
            # Using %b in printf to safely evaluate the color variables
            local M_COLOR="${C_GRN}"
            case "$EP_METHOD" in
                POST) M_COLOR="${C_BLU}" ;; PUT) M_COLOR="${C_YLW}" ;; DELETE) M_COLOR="${C_RED}" ;; PATCH) M_COLOR="${C_MAG}" ;;
            esac
            printf "│ ${C_CYN}${C_BLD}%-3s${C_DEF} │ %b%-4s${C_DEF} │ ${C_WHT}%-33s${C_DEF} │ ${C_DIM}%-65s${C_DEF} │\n" "$i" "$M_COLOR" "$EP_METHOD" "$EP_PATH" "${EP_SUMMARY:0:65}"
            ((i++))
        done
        echo -e "╰─────┴──────┴────────────────────────────────────────┴──────────────────────────────────────────────────────────────╯"
        
        read -r -p "Select Endpoint ID [1-$((i-1))] or 'Q' to quit: " SEL_IDX
        if [[ "${SEL_IDX^^}" == "Q" ]]; then return; fi 
        
        if [[ "$SEL_IDX" =~ ^[0-9]+$ ]] && (( SEL_IDX > 0 && SEL_IDX < i )); then
            IFS='|' read -r EP_PATH EP_METHOD EP_SUMMARY <<< "${ENDPOINT_ARRAY[$((SEL_IDX-1))]}"
        else
            echo -e "${C_RED}Invalid ID. Please try again.${C_DEF}"; sleep 1; continue
        fi
        
        local JQ_PARAM_FILTER=".paths[\"$EP_PATH\"][\"$(echo "$EP_METHOD" | tr '[:upper:]' '[:lower:]')\"].parameters[]? | \"\(.name)|\(.required)|\(.description)\""
        mapfile -t PARAMS_ARRAY < <(echo "$SCHEMA" | jq -r "$JQ_PARAM_FILTER" 2>/dev/null)
        
        declare -A PARAM_VALUES
        local CUSTOM_FILTERS=()
        
        # --- LEVEL 2: PARAMETER CONFIGURATION LOOP ---
        while true; do
            draw_banner
            echo -e "${C_GRN}${C_BLD}>> Target:${C_DEF} ${C_WHT}$EP_METHOD $EP_PATH${C_DEF} ${C_DIM}($EP_SUMMARY)${C_DEF}\n"
            echo -e "${C_MAG}${C_BLD}╭── CONFIGURE PARAMETERS ──────────────────────────────────────╮${C_DEF}"
            local idx=1
            
            for param in "${PARAMS_ARRAY[@]}"; do
                [[ -z "$param" ]] && continue
                IFS='|' read -r P_NAME P_REQ P_DESC <<< "$param"
                
                local REQ_STR="${C_DIM}[OPTIONAL]${C_DEF}"
                if [[ "$P_REQ" == "true" ]]; then REQ_STR="${C_RED}${C_BLD}[REQUIRED]${C_DEF}"; fi
                
                local VAL_STR="${C_DIM}(Not Set)${C_DEF}"
                if [[ -n "${PARAM_VALUES[$P_NAME]}" ]]; then VAL_STR="${C_GRN}${C_BLD}${PARAM_VALUES[$P_NAME]}${C_DEF}"; fi

                printf "│ ${C_WHT}${C_BLD}%-2s)${C_DEF} %-16s %b => %b\n" "$idx" "$P_NAME" "$REQ_STR" "$VAL_STR"
                printf "│     ${C_DIM}↳ %-56s${C_DEF}\n" "${P_DESC:0:56}"
                ((idx++))
            done
            
            for custom in "${CUSTOM_FILTERS[@]}"; do
                printf "│ ${C_WHT}${C_BLD} -)${C_DEF} ${C_BLU}[CUSTOM]${C_DEF} %b\n" "$custom"
            done
            
            echo -e "├──────────────────────────────────────────────────────────────┤"
            echo -e "│ ${C_CYN}${C_BLD}E) Execute  ${C_YLW}C) Add Custom  ${C_WHT}B) Back  ${C_RED}M) Main Menu${C_DEF}             │"
            echo -e "╰──────────────────────────────────────────────────────────────╯"
            read -r -p "Select parameter to edit [1-$((idx-1))], or Action [E,C,B,M]: " OPT_CHOICE
            OPT_CHOICE=${OPT_CHOICE:='E'}
            
            if [[ "${OPT_CHOICE^^}" == "M" ]]; then return; elif [[ "${OPT_CHOICE^^}" == "B" ]]; then break; fi
            
            if [[ "${OPT_CHOICE^^}" == "C" ]]; then
                read -r -p "Enter custom parameter (key=value): " CUSTOM_VAL
                if [[ "$CUSTOM_VAL" == *"="* ]]; then CUSTOM_FILTERS+=("$CUSTOM_VAL"); fi
                
            elif [[ "$OPT_CHOICE" =~ ^[0-9]+$ ]] && (( OPT_CHOICE > 0 && OPT_CHOICE < idx )); then
                IFS='|' read -r P_NAME P_REQ P_DESC <<< "${PARAMS_ARRAY[$((OPT_CHOICE-1))]}"
                if grep -iqE "^oid|^ot|^group|^location" < <(echo "$P_NAME"); then
                    select_agent_object "$P_NAME"
                else
                    read -r -p "Enter new value for $P_NAME (blank to clear): " NEW_VAL
                    if [[ -n "$NEW_VAL" ]]; then PARAM_VALUES["$P_NAME"]="$(echo -n "$NEW_VAL" | jq -s -R -r @uri)"; else unset PARAM_VALUES["$P_NAME"]; fi
                fi
                
            elif [[ "${OPT_CHOICE^^}" == "E" ]]; then
                # EXECUTION BLOCK (Supports Batch ALL or Single)
                local ALL_RESULTS=()
                local EXEC_LOOP=("SINGLE")
                
                if [[ "${PARAM_VALUES["oid"]}" == "ALL" || "${PARAM_VALUES["ot"]}" == "ALL" ]]; then
                    if [[ ${#OBJ_ARRAY[@]} -eq 0 ]]; then echo -e "${C_RED}ERROR: No objects in memory.${C_DEF}"; sleep 2; continue; fi
                    EXEC_LOOP=("${OBJ_ARRAY[@]}")
                    echo -e "\n${C_MAG}${C_BLD}=== EXECUTING BATCH FOR ${#EXEC_LOOP[@]} TARGETS ===${C_DEF}"
                fi

                for obj in "${EXEC_LOOP[@]}"; do
                    local QUERY_STRING=""
                    local FIRST_PARAM=true

                    if [[ "$obj" != "SINGLE" ]]; then
                        local O_ID=$(echo "$obj" | awk '{print $1}')
                        local O_TYPE=$(echo "$obj" | awk -F'\\[Type:' '{print $2}' | awk -F'\\]' '{print $1}')
                        [[ "${PARAM_VALUES["oid"]}" == "ALL" ]] && PARAM_VALUES["oid"]="$O_ID"
                        [[ "${PARAM_VALUES["ot"]}" == "ALL" ]] && PARAM_VALUES["ot"]="$O_TYPE"
                        echo -e "${C_DIM} -> Executing for OID ${C_WHT}$O_ID${C_DIM} (Type: ${C_WHT}$O_TYPE${C_DIM})...${C_DEF}"
                    fi

                    for param in "${PARAMS_ARRAY[@]}"; do
                        [[ -z "$param" ]] && continue
                        IFS='|' read -r P_NAME P_REQ P_DESC <<< "$param"
                        if [[ -n "${PARAM_VALUES[$P_NAME]}" ]]; then
                            local VAL="${PARAM_VALUES[$P_NAME]}"
                            [[ "$VAL" == "ALL" && ! "$P_NAME" =~ ^(oid|ot)$ ]] && VAL=""
                            if $FIRST_PARAM; then QUERY_STRING="?${P_NAME}=${VAL}"; FIRST_PARAM=false; else QUERY_STRING="${QUERY_STRING}&${P_NAME}=${VAL}"; fi
                        elif [[ "$P_REQ" == "true" ]]; then
                            echo -e "${C_RED}Error: Required param '$P_NAME' missing.${C_DEF}"; sleep 2; continue 3
                        fi
                    done
                    
                    for custom in "${CUSTOM_FILTERS[@]}"; do
                        if $FIRST_PARAM; then QUERY_STRING="?${custom}"; FIRST_PARAM=false; else QUERY_STRING="${QUERY_STRING}&${custom}"; fi
                    done

                    local EXEC_URI="${BASE_URL}${EP_PATH}${QUERY_STRING}"
                    [[ "$obj" == "SINGLE" ]] && echo -e "\n${C_BLU}${C_BLD} EXECUTING > ${C_WHT}$EP_METHOD ${C_CYN}$EXEC_URI${C_DEF}"

                    local CURL_CMD=("curl" "-s" "-X" "$EP_METHOD" "$EXEC_URI" "-H" "Accept: application/json")
                    [[ -n "$AUTH_HEADER" ]] && CURL_CMD+=("-H" "$AUTH_HEADER")

                    local RESULT=$("${CURL_CMD[@]}")
                    
                    if [[ "$obj" != "SINGLE" ]]; then
                        if echo "$RESULT" | jq -e . >/dev/null 2>&1; then ALL_RESULTS+=("$RESULT"); else
                            local ESCAPED_RES=$(echo "$RESULT" | jq -R -s '.')
                            ALL_RESULTS+=("{\"oid\": \"$O_ID\", \"raw_response\": $ESCAPED_RES}")
                        fi
                        [[ -n "${PARAM_VALUES["oid"]}" ]] && PARAM_VALUES["oid"]="ALL"
                        [[ -n "${PARAM_VALUES["ot"]}" ]] && PARAM_VALUES["ot"]="ALL"
                    fi
                done
                
                [[ "$obj" != "SINGLE" ]] && RESULT=$(printf '%s\n' "${ALL_RESULTS[@]}" | jq -s '.')
                
                render_output "$RESULT" "$EP_PATH"
                if [[ $? -eq 1 ]]; then return; fi
            fi
        done
    done
}

# ================= UI / MENU =================

function show_menu() {
    while true; do
        draw_banner
        echo -e "  ${C_YLW}${C_BLD}(1)${C_DEF} - ${C_WHT}[EXPLORE]${C_DEF} Launch API Wizard"
        echo -e "  ${C_MAG}${C_BLD}(2)${C_DEF} - ${C_WHT}[CREDS]${C_DEF}   Manage Credentials"
        echo -e "  ${C_RED}${C_BLD}(0)${C_DEF} - ${C_WHT}[SYSTEM]${C_DEF}  Exit\n"
        read -r -p "  Select By Number: " CHOICE
        CHOICE=${CHOICE:='1'}
        
        case "$CHOICE" in
            1) dynamic_explorer ;;
            2) new_creds ; sleep 2 ;;
            0) echo -e "${C_GRN}Goodbye!${C_DEF}"; exit 0 ;;
        esac
    done
}

show_menu
