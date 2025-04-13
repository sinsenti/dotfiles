import os
import subprocess


def copy_code_to_backup(directory, backup_file, skip_dirs=None):
    """
    Recursively copies all code files from the given directory to the backup file.
    Skips directories specified in the skip_dirs set and their subdirectories.
    """
    # Walk through the directory
    for root, dirs, files in os.walk(directory, topdown=True):
        # Check if the current directory or any of its parents are in the skip_dirs set
        if any(root.startswith(skip_dir) for skip_dir in skip_dirs):
            print(f"Skipping directory (already excluded): {root}")
            dirs.clear()  # Skip all subdirectories of this directory
            continue

        # Prompt the user for each subdirectory
        if root != directory:
            relative_path = os.path.relpath(root, directory)
            include = (
                input(f"\nDo you want to include ./{relative_path}? (y/N): ")
                .strip()
                .lower()
            )
            if include != "y":
                print(f"Excluding directory: {relative_path}")
                skip_dirs.add(root)  # Add the directory to the skip list
                dirs.clear()  # Skip all subdirectories of this directory
                continue

        # Process files in the current directory
        for file in files:
            if file == "backup_code.txt":
                print(f"Skipping file: {file}")
                continue

            # Check if the file has a supported code extension
            file_path = os.path.join(root, file)
            relative_file_path = os.path.relpath(file_path, directory)
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    content = f.read()
                # Write the file's content to the backup file
                backup_file.write(f"--- File: {relative_file_path} ---\n")
                backup_file.write(content)
                backup_file.write("\n\n")  # Add some spacing between files
                print(f"Copied: {relative_file_path}")
            except Exception as e:
                print(f"Error reading {file_path}: {e}")


def main():
    # Define the backup file name
    backup_filename = "backup_code.txt"

    # Get the current working directory
    current_directory = os.getcwd()

    # Initialize a set to keep track of directories to skip
    skip_dirs = set()

    # Open the backup file in write mode
    try:
        with open(backup_filename, "w", encoding="utf-8") as backup_file:
            print(f"Creating backup of code files in '{current_directory}'...")
            copy_code_to_backup(current_directory, backup_file, skip_dirs)
    except Exception as e:
        print(f"Error creating backup file: {e}")
        return

    print(f"\nBackup completed. All code files have been saved to '{backup_filename}'.")

    # Copy backup_file content to clipboard
    try:
        with open(backup_filename, "r", encoding="utf-8") as f:
            content = f.read()
            subprocess.run(["wl-copy"], input=content.encode("utf-8"))
        print("Backup content copied to clipboard.")
    except Exception as e:
        print(f"Error copying to clipboard: {e}")

    # Delete the backup file
    try:
        os.remove(backup_filename)
        print(f"Deleted backup file: {backup_filename}")
    except Exception as e:
        print(f"Error deleting backup file: {e}")


if __name__ == "__main__":
    main()
