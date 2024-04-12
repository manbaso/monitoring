#!/bin/bash

# Apply Terraform changes with auto-approval
terraform apply -auto-approve

# # Refresh Terraform state
terraform refresh

# Clear existing content and prepare hosts file
echo " " > hosts

# Initialize arrays
declare -a public_ips
declare -a names

# Output of the command
output=$(terraform output public_ip)

file_path=hosts

# Read the output line by line and populate arrays
while IFS= read -r line; do
    if [[ $line =~ "public_ip" ]]; then
        public_ip=$(echo "$line" | grep -oP '(?<=public_ip" = ")[^"]+')
        public_ips+=("$public_ip")
    elif [[ $line =~ "Name" ]]; then
        name=$(echo "$line" | grep -oP '(?<=Name" = ")[^"]+')
        names+=("$name")
    fi
done <<< "$output"
# Loop through the IPs and server names and append them to the file
for ((i=0; i<${#public_ips[@]}; i++)); do
    echo "[${names[i]}]" >> "$file_path" # Append server name to file
    echo "${public_ips[i]}" >> "$file_path"       # Append IP address to file
done

echo "public_ips: ${public_ips[@]}"
echo "names: ${names[@]}"


ansible-playbook -i hosts playbook.yml