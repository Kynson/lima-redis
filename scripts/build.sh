#!/bin/bash

# This script build this project by replacing secret variables (with __S_ prefix and ends with __)
# with their values stored on GitHub

targetFiles=("redis-init.sh" "redis-users.acl")

# $1 is the target file
# $2 is the string to be replaced
# $3 is the replacement string
function replace() {
  ed -s <<- EOF "$1"
    ,s;$2;$3;g
    w
    q
	EOF
}

# Get all secret variables and put them into an array
secretVariables=()
while read secret; do
  secretVariables+=("$secret")
done < <(grep '__S_*' <(env))

for file in "${targetFiles[@]}"; do
  for secret in "${secretVariables[@]}"; do
    secretName="$(cut -d '=' -f 1 <<< "$secret")"
    value="$(cut -d '=' -f 2 <<< "$secret")"

    if grep "$secretName" "$file" > /dev/null; then
      echo "Replacing $secretName in $file"

      replace "$file" "$secretName" "$value"
    fi
  done
done

echo "Build is completed"