#!/usr/bin/env bash
# Theme Comparison Tool for muOS
#
# This script compares two muOS themes by:
# 1. Analyzing their directory structures to identify files unique to each theme
# 2. Comparing the contents of text files (*.txt, *.ini) that exist in both themes
# 3. Providing visual diff output using git diff
#
# Usage:
#     bash compare_themes.sh <theme1_path> <theme2_path>
#
# Arguments:
#     theme1_path - Path to the root directory of the first theme
#     theme2_path - Path to the root directory of the second theme

# Check if a command is available in the system PATH
is_command_available() {
    command -v "$1" >/dev/null 2>&1
}

# Get all files in a directory recursively
get_all_files() {
    local directory="$1"
    local output_file="$2"
    
    # Clear the output file
    > "$output_file"
    
    # Find all files, excluding .DS_Store, and write to the output file
    find "$directory" -type f -not -name ".DS_Store" | while read -r file; do
        # Get the path relative to the directory
        rel_path="${file#$directory/}"
        echo "$rel_path" >> "$output_file"
    done
    
    # Sort the file for consistent output
    sort "$output_file" -o "$output_file"
}

# Compare directories and identify unique files in each
compare_themes() {
    local theme1_path="$1"
    local theme2_path="$2"
    
    # Validate theme directories exist
    if [ ! -d "$theme1_path" ]; then
        echo "Error: $theme1_path is not a valid directory"
        exit 1
    fi
    
    if [ ! -d "$theme2_path" ]; then
        echo "Error: $theme2_path is not a valid directory"
        exit 1
    fi
    
    # Create temporary files for comparison
    local tmp_dir=$(mktemp -d)
    local theme1_files="$tmp_dir/theme1_files.txt"
    local theme2_files="$tmp_dir/theme2_files.txt"
    local only_in_theme1="$tmp_dir/only_in_theme1.txt"
    local only_in_theme2="$tmp_dir/only_in_theme2.txt"
    
    # Get all files from both themes
    get_all_files "$theme1_path" "$theme1_files"
    get_all_files "$theme2_path" "$theme2_files"
    
    # Find files unique to each theme
    comm -23 "$theme1_files" "$theme2_files" > "$only_in_theme1"
    comm -13 "$theme1_files" "$theme2_files" > "$only_in_theme2"
    
    # Extract theme names from paths for cleaner output
    local theme1_name=$(basename "$(realpath "$theme1_path" 2>/dev/null || echo "$theme1_path")")
    local theme2_name=$(basename "$(realpath "$theme2_path" 2>/dev/null || echo "$theme2_path")")
    
    # Display results
    echo -e "\nComparison Results:\n"
    
    # Count lines in the only_in_theme1 file
    local only_in_theme1_count=$(wc -l < "$only_in_theme1")
    # Trim whitespace from the count
    only_in_theme1_count=$(echo "$only_in_theme1_count" | tr -d '[:space:]')
    
    echo "Files only in $theme1_name ($only_in_theme1_count):"
    if [ "$only_in_theme1_count" -gt 0 ]; then
        while IFS= read -r file_path; do
            echo "  $file_path"
        done < "$only_in_theme1"
    else
        echo "  None"
    fi
    
    # Count lines in the only_in_theme2 file
    local only_in_theme2_count=$(wc -l < "$only_in_theme2")
    # Trim whitespace from the count
    only_in_theme2_count=$(echo "$only_in_theme2_count" | tr -d '[:space:]')
    
    echo -e "\nFiles only in $theme2_name ($only_in_theme2_count):"
    if [ "$only_in_theme2_count" -gt 0 ]; then
        while IFS= read -r file_path; do
            echo "  $file_path"
        done < "$only_in_theme2"
    else
        echo "  None"
    fi
    
    # Clean up temporary files
    rm -rf "$tmp_dir"
}

# Compare the contents of text files that exist in both themes
compare_file_contents() {
    local theme1_path="$1"
    local theme2_path="$2"
    
    # Extract theme names from paths for cleaner output
    local theme1_name=$(basename "$(realpath "$theme1_path" 2>/dev/null || echo "$theme1_path")")
    local theme2_name=$(basename "$(realpath "$theme2_path" 2>/dev/null || echo "$theme2_path")")
    
    # Check if delta is available
    local use_delta=false
    if is_command_available "delta"; then
        use_delta=true
    else
        echo "Notice: The 'delta' command was not found. delta provides enhanced visual diff output."
        echo "delta installation instructions: https://dandavison.github.io/delta/installation.html"
        echo -n "Do you wish to continue with standard diff output? [Y/n]: "
        read -r response
        
        # Exit if user doesn't want to continue with standard diff
        if [ -n "$response" ] && [ "${response,,}" != "y" ]; then
            echo "Comparison aborted."
            return
        fi
        
        # Verify git is available for fallback diffing
        if ! is_command_available "git"; then
            echo "git not found, cannot compare file contents"
            return
        fi
    fi
    
    echo -e "\nComparing text file contents between $theme1_name and $theme2_name:\n"
    
    local found_differences=false
    
    # Find all .txt and .ini files in the first theme and create a portable version
    # that works in both macOS and Linux
    cd "$theme1_path" || exit 1
    local txt_files=$(find . -type f \( -name "*.txt" -o -name "*.ini" \) | sed 's|^\./||')
    cd - > /dev/null || exit 1
    
    # Save txt_files to a temporary file to avoid subshell issues with variable scoping
    local tmp_txt_files=$(mktemp)
    echo "$txt_files" > "$tmp_txt_files"
    
    # Process each file without using a pipe to avoid subshell
    while IFS= read -r rel_path; do
        # Skip empty lines
        [ -z "$rel_path" ] && continue
        
        # Construct the path for the matching file in theme2
        local file2="$theme2_path/$rel_path"
        local file1="$theme1_path/$rel_path"
        
        # Only compare files that exist in both themes
        if [ -f "$file2" ]; then
            local diff_output=""
            if $use_delta; then
                # Use delta for comparison (enhanced visual diff)
                diff_output=$(delta "$file1" "$file2" --file-style=omit --hunk-header-style=omit 2>/dev/null)
            else
                # Fallback to git diff
                diff_output=$(git diff --no-index --color=always -G. "$file1" "$file2" 2>/dev/null)
            fi
            
            # If there's output, print it along with the file paths
            if [ -n "$diff_output" ]; then
                found_differences=true
                echo "$file1 -> $file2:"
                echo "$diff_output"
                echo "--------------------------------------------------------------------------------"
            fi
        fi
    done < "$tmp_txt_files"
    
    # Clean up temporary file
    rm -f "$tmp_txt_files"
    
    if [ "$found_differences" = false ]; then
        echo "No differences found in text files."
    fi
}

# Main function
main() {
    # Check if correct number of arguments are provided
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <theme1_path> <theme2_path>"
        exit 1
    fi
    
    local theme1_path="$1"
    local theme2_path="$2"
    
    # First compare file structure between themes
    compare_themes "$theme1_path" "$theme2_path"
    
    # Then compare contents of text files that exist in both themes
    compare_file_contents "$theme1_path" "$theme2_path"
}

# Call the main function with all arguments
main "$@" 