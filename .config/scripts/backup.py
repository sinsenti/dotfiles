import os
import shutil


def backup_file_preserving_path(source_path_with_tilde, destination_root_with_tilde):
    source_file_expanded = os.path.expanduser(source_path_with_tilde)
    destination_root_expanded = os.path.expanduser(destination_root_with_tilde)
    home_dir = os.path.expanduser("~")

    print(f"Attempting to backup: {source_file_expanded}")
    print(f"To backup root directory: {destination_root_expanded}")
    if not os.path.exists(source_file_expanded):
        print(f"Error: Source file not found at {source_file_expanded}")
        return
    if not os.path.isfile(source_file_expanded):
        print(f"Error: Source is not a file at {source_file_expanded}. Cannot copy.")
        return

    try:
        relative_path_from_home = os.path.relpath(source_file_expanded, home_dir)
        print(f"Relative path from home: {relative_path_from_home}")
    except ValueError:
        print(
            f"Error: Source file {source_file_expanded} is not within the home directory {home_dir}."
        )
        print("Cannot preserve relative path relative to home.")
        return
    destination_file_expanded = os.path.join(
        destination_root_expanded, relative_path_from_home
    )
    print(f"Target destination path: {destination_file_expanded}")
    destination_dir = os.path.dirname(destination_file_expanded)
    try:
        os.makedirs(destination_dir, exist_ok=True)
        print(f"Ensured destination directory structure exists: {destination_dir}")
    except OSError as e:
        print(f"Error creating destination directory {destination_dir}: {e}")
        return
    try:
        shutil.copy2(source_file_expanded, destination_file_expanded)
        print(
            f"Successfully copied {source_file_expanded} to {destination_file_expanded}"
        )
    except IOError as e:
        print(
            f"Error copying file {source_file_expanded} to {destination_file_expanded}: {e}"
        )
    except Exception as e:
        print(f"An unexpected error occurred during file copy: {e}")


source_items_to_backup = [
    "/home/sinsenti/.mozilla/firefox/ggfthikr.arkenfox/user.js",
    "/home/sinsenti/.mozilla/firefox/ggfthikr.arkenfox/chrome/userChrome.css",
    "/home/sinsenti/.config/kitty/kitty.conf",
    "/home/sinsenti/.config/hypr/configs/Keybinds.conf",
]
backup_target_root = "~/git/backup"
for source_file_to_backup in source_items_to_backup:
    backup_file_preserving_path(source_file_to_backup, backup_target_root)
print("\n--- Backup process finished ---")
