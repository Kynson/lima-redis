#!/bin/bash

read -p "Enter the Redis version number (without patch version number): " version
read -p "Enter the outfile name: " outfileName

echo "Generating Redis Containerfile for version $version"

echo "Creating temporary directory"

temporaryDirectory="$(mktemp -d)"

temporaryContainerfile="$temporaryDirectory/Containerfile.temp"
baseDockerfile="$temporaryDirectory/Dockerfile"
touch "$temporaryContainerfile"

function insertNewline() {
	cat <<- EOF >> "$temporaryContainerfile"

	EOF
}

function promptWithDefault() {
	# The response is a global variable
	read -p "$1" response
	response="${response:-$2}"
}

echo "Adding copyright notice and LICENSE"

# Append the copyright notice
# Use the real tab character for all HereDocs! (VS Code uses spaces!)
cat <<- EOF > "$temporaryContainerfile"
	Copyright (c) $(date +"%Y") Kynson Szetau. All Rights Reserved.

	This file is a modified version of the official Redis Dockerfile.
	This file is licensed under the MIT License.

EOF

# Append speperator
cat <<- EOF >> "$temporaryContainerfile"
	============== Start of Original LICENSE ==============
EOF

insertNewline

# Append the Docker LICENSE
curl -sS https://raw.githubusercontent.com/docker-library/redis/master/LICENSE >> "$temporaryContainerfile"

insertNewline

# Append speperator
cat <<- EOF >> "$temporaryContainerfile"
	============== End of Original LICENSE ==============
EOF

# Comment out the LICENSE and copyright notice
# , means every line; w writes; q quits ed
ed -s <<- EOF "$temporaryContainerfile"
	,s/^/# /
	w
	q
EOF

insertNewline

echo "Copying Redis Dockerfile"

# Save the original Dockerfile for later use
curl -sS "https://raw.githubusercontent.com/docker-library/redis/master/$version/alpine/Dockerfile" -o "$baseDockerfile"
cat "$temporaryDirectory/Dockerfile" >> "$temporaryContainerfile"

promptWithDefault "Do you want to preview the current generated Containerfile before customization? [Y/n]: " "y"

# promptWithDefault will update the global variable response
if [[ $response = 'y' ]] || [[ $response = 'Y' ]]; then
	less -N "$temporaryContainerfile"
fi

fromCommand="$(grep "FROM alpine.*$" "$baseDockerfile")"
baseImageVersion="$(awk -F ':' '{print $2}' <<< "$fromCommand")"

if [[ $baseImageVersion != 'latest' ]]; then
	echo "$fromCommand => FROM alpine:latest"
	promptWithDefault "Confirm update the FROM command as above? [Y/n]: " "y"

	if [[ $response = 'y' ]] || [[ $response = 'Y' ]]; then
		ed -s <<- EOF "$temporaryContainerfile"
			,s/$fromCommand/FROM alpine:latest/
			w
			q
		EOF
	fi
fi

# Warning: the following may need to update in the future
protectedModeCommandsStart="$(grep -n "disable Redis protected mode" "$temporaryContainerfile" | awk -F ':' '{ print $1 }')"
protectedModeCommandsEnd="$(($protectedModeCommandsStart + 9))"

# This one is saved before removing anything for printing only
setupCommandsStart="$(grep -n "RUN mkdir /data" "$temporaryContainerfile" | awk -F ':' '{ print $1 }')"

promptWithDefault "Confirm remove lines relate to protected mode ($protectedModeCommandsStart - $protectedModeCommandsEnd)? [Y/n]: " "y"
if [[ $response = 'y' ]] || [[ $response = 'Y' ]]; then
	ed -s <<- EOF "$temporaryContainerfile"
		$protectedModeCommandsStart,${protectedModeCommandsEnd}d
		w
		q
	EOF
fi

promptWithDefault "Confirm remove other setup commands ($setupCommandsStart - end)? [Y/n]: " "y"

# Update the line number
setupCommandsStart="$(grep -n "RUN mkdir /data" "$temporaryContainerfile" | awk -F ':' '{ print $1 }')"

if [[ $response = 'y' ]] || [[ $response = 'Y' ]]; then
	ed -s <<- EOF "$temporaryContainerfile"
		$setupCommandsStart,\$d
		w
		q
	EOF
fi

promptWithDefault "Do you want to view the diff of the generated file against the original? [y/N]: " "n"
if [[ $response = 'y' ]] || [[ $response = 'Y' ]]; then
	diff -c "$temporaryContainerfile" "$baseDockerfile"
fi

promptWithDefault "Do you want to preview the generated file? [Y/n]: " "y"
if [[ $response = 'y' ]] || [[ $response = 'Y' ]]; then
	less -N "$temporaryContainerfile"
fi

promptWithDefault "Confirm writing the file to $outfileName ? [Y/n]: " "y"
if [[ $response = 'y' ]] || [[ $response = 'Y' ]]; then
		cp "$temporaryContainerfile" "$outfileName"
	else
		echo "Aborted"
fi

rm -r $temporaryDirectory