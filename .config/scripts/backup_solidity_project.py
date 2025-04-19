import os
import subprocess
import sys

# --- Configuration ---
# List of paths to skip relative to the directory argument
SKIP_LIST = {  # Using a set for faster lookups
    "node_modules",
    ".env",
    "cache",
    "artifacts",
    "typechain",
    "typechain-types",
    "coverage",
    "coverage.json",
    "ignition/deployments/chain-31337",
    ".gitignore",
    "backup_code.txt",  # Added the backup file itself to the skip list
}


# --- Recursive function to copy code files ---
def copy_code_to_backup(directory, backup_file):
    """
    Recursively copies all non-skipped files from the given directory to the backup file stream.
    Skips directories and files specified in the SKIP_LIST.
    """
    abs_skip_dirs = {
        os.path.join(os.path.abspath(directory), skip_path)
        for skip_path in SKIP_LIST
        if not os.path.splitext(skip_path)[1]
    }  # Only add directories

    for root, dirs, files in os.walk(directory, topdown=True):
        # Calculate the relative path of the current directory
        relative_root_path = os.path.relpath(root, directory)

        # Check if the current directory should be skipped
        # We check both the relative path and if it's a subdirectory of a skipped path
        should_skip_dir = False
        if relative_root_path in SKIP_LIST and relative_root_path != ".":
            should_skip_dir = True
        # Also check if the current directory's absolute path starts with a skipped absolute directory path
        elif any(
            os.path.abspath(root).startswith(abs_skip_dir)
            for abs_skip_dir in abs_skip_dirs
        ):
            should_skip_dir = True

        if should_skip_dir:
            if (
                relative_root_path != "."
            ):  # Don't print skipping the starting directory itself
                print(f"Skipping directory: {relative_root_path}")
            dirs.clear()  # Skip all subdirectories of this directory
            continue

        # Process files in the current directory
        for file in files:
            relative_file_path = os.path.join(relative_root_path, file)

            # Check if the file should be skipped
            if relative_file_path in SKIP_LIST:
                print(f"Skipping file: {relative_file_path}")
                continue

            file_path = os.path.join(
                root, file
            )  # Get the full file path here for opening

            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                # Write the file's content to the backup file
                backup_file.write(f"--- File: {relative_file_path} ---\n")
                backup_file.write(content)
                backup_file.write("\n\n")  # Add some spacing between files
                print(f"Copied: {relative_file_path}")
            except Exception as e:
                print(f"Error reading {relative_file_path}: {e}", file=sys.stderr)


# --- Main function ---
def main():
    directory = os.getcwd()
    backup_filename = "backup_code.txt"
    try:
        with open(backup_filename, "w", encoding="utf-8") as backup_file:
            print(f"Creating backup of code files in '{directory}'...")
            # Pass the directory to the function
            copy_code_to_backup(directory, backup_file)
    except Exception as e:
        print(f"Error creating backup file: {e}", file=sys.stderr)
        return  # Exit if backup file creation/writing fails

    print(
        f"\nBackup completed. All included files have been saved to '{backup_filename}'."
    )

    # Copy backup_file content to clipboard
    try:
        with open(backup_filename, "r", encoding="utf-8") as f:
            content = f.read()
            # Use a more portable way to copy to clipboard if wl-copy fails
            try:
                subprocess.run(["wl-copy"], input=content.encode("utf-8"), check=True)
            except Exception as e:
                print(f"Error copying to clipboard with wl-copy: {e}", file=sys.stderr)

        print("Backup content copied to clipboard.")
    except FileNotFoundError:
        print(
            "Backup file not found after creation, cannot copy to clipboard.",
            file=sys.stderr,
        )
    except Exception as e:
        print(f"Error reading backup file for clipboard copy: {e}", file=sys.stderr)

    # Delete the backup file regardless of clipboard copy success or interruption
    try:
        os.remove(backup_filename)
        print(f"Deleted backup file: {backup_filename}")
    except Exception as e:
        print(f"Error deleting backup file: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
