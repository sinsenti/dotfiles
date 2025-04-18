import os
import subprocess
import sys

# --- Configuration ---
BACKUP_FILENAME = 'solidity_project_backup.txt'
# List of directories and files to skip relative to the project root
SKIP_LIST = [
    'node_modules',
    '.env',
    'cache',
    'artifacts',
    'typechain',
    'typechain-types',
    'coverage',
    'coverage.json',
    'ignition/deployments/chain-31337',
]

def should_skip(relative_path):
    """
    Checks if a path should be skipped based on the SKIP_LIST.
    Handles both files and directories.
    """
    # Normalize path to use forward slashes and remove leading/trailing slashes for consistent matching
    normalized_path = relative_path.replace('\\', '/').strip('/')

    # Always skip the backup file itself
    if normalized_path == BACKUP_FILENAME:
        return True

    for skip_item in SKIP_LIST:
        normalized_skip_item = skip_item.replace('\\', '/').strip('/')
        # Check if the path is the skip item or starts with the skip item followed by a slash
        if normalized_path == normalized_skip_item or normalized_path.startswith(normalized_skip_item + '/'):
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
    # Get the current working directory (project root)
    project_root = os.getcwd()

    # Open the backup file in write mode (creates the file if it doesn't exist)
    backup_file_stream = None
    try:
        backup_file_stream = open(BACKUP_FILENAME, "w", encoding="utf-8")
        print(f"Creating backup of code files in '{project_root}'...")
        copy_code_to_backup(project_root, backup_file_stream, project_root)
    except Exception as e:
        print(f"Error creating backup file: {e}", file=sys.stderr)
        return # Exit if backup file creation/writing fails
    finally:
        if backup_file_stream:
            backup_file_stream.close()  # Close the file stream

    print(f"\nBackup completed. All included files have been saved to '{BACKUP_FILENAME}'.")

    # Copy backup_file content to clipboard
    try:
        with open(BACKUP_FILENAME, "r", encoding="utf-8") as f:
            backup_content = f.read()

        copy_command = None
        clipboard_tool = None

        # Prioritize wl-copy for Wayland
        try:
            subprocess.run(['which', 'wl-copy'], check=True, capture_output=True, text=True)
            copy_command = 'wl-copy'
            clipboard_tool = 'wl-copy'
        except (subprocess.CalledProcessError, FileNotFoundError):
             # Fallback for X11
            try:
                subprocess.run(['which', 'xclip'], check=True, capture_output=True, text=True)
                copy_command = 'xclip -selection clipboard'
                clipboard_tool = 'xclip'
            except (subprocess.CalledProcessError, FileNotFoundError):
                 # Fallback for macOS
                if sys.platform == 'darwin':
                    copy_command = 'pbcopy'
                    clipboard_tool = 'pbcopy'
                 # Fallback for Windows
                elif sys.platform == 'win32':
                    copy_command = 'clip'
                    clipboard_tool = 'clip'
                else:
                    print("Clipboard command not found (requires wl-copy, xclip, pbcopy, or clip). Skipping clipboard copy.", file=sys.stderr)


        if copy_command:
            try:
                # Use subprocess.run to execute the clipboard command and pass content via stdin
                # Added KeyboardInterrupt handling here
                try:
                    process = subprocess.run(copy_command.split(), input=backup_content.encode('utf-8'), check=True, capture_output=True)
                    print(f"Backup content copied to clipboard using {clipboard_tool}.")
                except KeyboardInterrupt:
                    print("\nClipboard copy interrupted by user.", file=sys.stderr)
                    # Do not re-raise, allow the script to continue to deletion
                except subprocess.CalledProcessError as e:
                    print(f"Error executing clipboard command '{copy_command}': {e}", file=sys.stderr)
                except FileNotFoundError:
                    # This specific FileNotFoundError is for the clipboard command itself not being found
                    print(f"Clipboard command '{copy_command}' not found.", file=sys.stderr)
                except Exception as e:
                    print(f"An unexpected error occurred during clipboard copy: {e}", file=sys.stderr)

    # These except blocks catch errors when opening/reading the backup file
    except FileNotFoundError:
         print(f"Backup file '{BACKUP_FILENAME}' not found for clipboard copy.", file=sys.stderr)
    except Exception as e:
        print(f"Error reading backup file for clipboard copy: {e}", file=sys.stderr)

    # Delete the backup file regardless of clipboard copy success or interruption
    try:
        os.remove(BACKUP_FILENAME)
        print(f"Deleted backup file: {BACKUP_FILENAME}")
    except FileNotFoundError:
        print(f"Backup file '{BACKUP_FILENAME}' not found for deletion (already gone?).", file=sys.stderr)
    except Exception as e:
        print(f"Error deleting backup file: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
