#!/bin/bash
set -e

# Determine the repository root, assuming install.sh is in the root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARAMS_FILE="${REPO_ROOT}/params/foundry.params"
TEMP_PARAMS_FILE="${PARAMS_FILE}.tmp"

echo "==================================================="
echo " Harper Kernel Foundry: Interactive Setup"
echo "==================================================="
echo ""

if [ ! -f "$PARAMS_FILE" ]; then
    echo "❌ Error: $PARAMS_FILE not found. Please ensure the repository is complete."
    exit 1
fi

# --- Dynamic Parameter Loading and Prompting ---

declare -A current_values # Stores current values of all simple variables
declare -A new_values     # Stores user-provided or default new values for prompted variables
declare -A prompt_descriptions # Stores descriptions for variables to be prompted

param_lines=() # Array to hold all lines of the params file, preserving order
current_description="" # Stores the description from the last # @PROMPT comment

echo "📖 Analyzing $PARAMS_FILE for configurable parameters..."

while IFS= read -r line || [[ -n "$line" ]]; do
    param_lines+=("$line")

    # Check for prompt description
    if [[ "$line" =~ ^#\ @PROMPT\ \"(.*)\"$ ]]; then
        current_description="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^#\ @NO_PROMPT ]]; then
        current_description="" # Reset description if explicitly marked as no-prompt
    elif [[ "$line" =~ ^([A-Z_]+)=\"(.*)\"$ ]]; then # Match VAR="VALUE"
        var_name="${BASH_REMATCH[1]}"
        var_value="${BASH_REMATCH[2]}"
        current_values["$var_name"]="$var_value"
        if [[ -n "$current_description" ]]; then
            prompt_descriptions["$var_name"]="$current_description"
            current_description="" # Reset after associating with a variable
        fi
    elif [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]]; then # Match VAR=VALUE (without quotes, handles arrays like VAR=(val1 val2))
        var_name="${BASH_REMATCH[1]}"
        var_value="${BASH_REMATCH[2]}"
        # Only store simple key-value pairs in current_values for prompting.
        # Array-like values will be preserved by printing the original line.
        if [[ ! "$var_value" =~ ^\(.*\) ]]; then # If it's not an array-like value
            current_values["$var_name"]="$var_value"
        fi
        if [[ -n "$current_description" ]]; then
            prompt_descriptions["$var_name"]="$current_description"
            current_description="" # Reset after associating with a variable
        fi
    fi
done < "$PARAMS_FILE"

# --- Prompting Function ---
prompt_for_variable() {
    local var_name="$1"
    local current_value="$2"
    local description="$3"
    local input_value

    echo ""
    echo "---------------------------------------------------"
    echo "$description"
    echo "Current value: '$current_value'"
    read -rp "Enter new value (or press Enter to keep current): " input_value
    if [ -z "$input_value" ]; then
        echo "Keeping default: '$current_value'"
        echo "$current_value" # Return current_value
    else
        echo "New value set: '$input_value'"
        echo "$input_value" # Return input_value
    fi
}

# --- Interactive Prompts ---
echo ""
echo "Please provide the following paths. These are critical for the build system"
echo "to correctly locate your repository and store build artifacts. Defaults are"
echo "based on your current 'params/foundry.params' file."

for var_name in "${!prompt_descriptions[@]}"; do
    current_val="${current_values[$var_name]}"
    description="${prompt_descriptions[$var_name]}"
    new_val=$(prompt_for_variable "$var_name" "$current_val" "$description")
    new_values["$var_name"]="$new_val"
done

echo ""
echo "---------------------------------------------------"
echo "QA Parameters: Not prompting for most QA parameters as per default recommendations."
echo "BYPASS_QA will be explicitly set to 'false' to ensure QA is active by default."
echo "---------------------------------------------------"
new_values["BYPASS_QA"]="false" # Explicitly set as per requirement

# --- Generate New params/foundry.params ---
echo ""
echo "✍️  Updating $PARAMS_FILE with new configuration..."

# Read the original file, make replacements, and write to a temporary file
for line in "${param_lines[@]}"; do
    # Preserve comments and blank lines
    if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
        echo "$line"
        continue
    fi

    # Extract variable name from the line
    var_name=$(echo "$line" | cut -d'=' -f1 | xargs)

    if [[ "$line" =~ ^([A-Z_]+)= ]]; then
        var_name="${BASH_REMATCH[1]}"
        if [[ -n "${new_values[$var_name]}" ]]; then
            printf "%s=\"%s\"\n" "$var_name" "${new_values[$var_name]}"
        else
            echo "$line" # Keep original line for non-prompted variables (including arrays)
        fi
    else
        echo "$line" # Keep comments, blank lines, etc.
    fi
done > "$TEMP_PARAMS_FILE"

# Replace original file with the new one
mv "$TEMP_PARAMS_FILE" "$PARAMS_FILE"
echo "✅ Configuration updated successfully in $PARAMS_FILE."
echo "You can now run ./start_build.sh to begin the build process."
echo "==================================================="
