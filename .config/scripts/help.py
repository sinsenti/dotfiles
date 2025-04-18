import os
import subprocess
import sys

# --- Configuration ---
# List of directories and files to skip relative to the project root
SKIP_LIST = [
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
]


def should_skip(relative_path, backup_filename="backup_code.txt"):
    """
    Checks if a path should be skipped based on the SKIP_LIST.
    Handles both files and directories.
    """
    # Normalize path to use forward slashes and remove leading/trailing slashes for consistent matching
    normalized_path = relative_path.replace("\\", "/").strip("/")

    # Always skip the backup file itself
    if normalized_path == backup_filename:
        return True

    for skip_item in SKIP_LIST:
        normalized_skip_item = skip_item.replace("\\", "/").strip("/")
        # Check if the path is the skip item or starts with the skip item followed by a slash
        if normalized_path == normalized_skip_item or normalized_path.startswith(
            normalized_skip_item + "/"
        ):
            return True
    return False


# --- Recursive function to copy code files ---
def copy_code_to_backup(directory, backup_file_stream, project_root):
    """
    Recursively copies all non-skipped files from the given directory to the backup file stream.
    """
    # Walk through the directory
    # topdown=True allows us to modify the 'dirs' list in place to skip subdirectories
    for root, dirs, files in os.walk(directory, topdown=True):
        # Calculate the relative path of the current directory
        relative_root = os.path.relpath(root, project_root)

        # Check if the current directory should be skipped
        if should_skip(relative_root):
            print(f"Skipping directory: {relative_root}")
            dirs.clear()  # Skip all subdirectories of this directory
            continue

        # Filter out directories that should be skipped from the 'dirs' list
        # This prevents os.walk from entering them
        dirs[:] = [d for d in dirs if not should_skip(os.path.join(relative_root, d))]

        # Process files in the current directory
        for file in files:
            file_path = os.path.join(root, file)
            relative_file_path = os.path.relpath(file_path, project_root)

            # Check if the current file should be skipped
            if should_skip(relative_file_path):
                print(f"Skipping file: {relative_file_path}")
                continue

            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                # Write the file's content to the backup file
                backup_file_stream.write(f"--- File: {relative_file_path} ---\n")
                backup_file_stream.write(content)
                backup_file_stream.write("\n\n")  # Add some spacing between files
                print(f"Copied: {relative_file_path}")
            except Exception as e:
                print(f"Error reading {relative_file_path}: {e}", file=sys.stderr)


# --- Main function ---
def main():
    project_root = os.getcwd()
    backup_filename = "backup_code.txt"
    try:
        with open(backup_filename, "w", encoding="utf-8") as backup_file:
            print(f"Creating backup of code files in '{project_root}'...")
            copy_code_to_backup(project_root, backup_file, project_root)
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
            subprocess.run(["wl-copy"], input=content.encode("utf-8"))
        print("Backup content copied to clipboard.")
    except Exception as e:
        print(f"Error copying to clipboard: {e}")

    # Delete the backup file regardless of clipboard copy success or interruption
    try:
        os.remove(backup_filename)
        print(f"Deleted backup file: {backup_filename}")
    except Exception as e:
        print(f"Error deleting backup file: {e}")


if __name__ == "__main__":
    main()
