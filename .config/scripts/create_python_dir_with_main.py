import os
import subprocess


def create_project_directory_and_file():
    """
    Asks user for a directory name, creates the directory,
    creates a main.py file inside it, changes to that directory,
    and opens main.py with nvim.
    """
    while True:
        dir_name = input("Enter the name for the new project directory: ").strip()
        if dir_name:
            if any(c in '\n\r\t /\\:*?"<>|' for c in dir_name):
                print(
                    "Directory name contains invalid characters. Please use letters, numbers, underscores, or hyphens."
                )
            else:
                break
        else:
            print("Directory name cannot be empty. Please try again.")

    current_dir = os.getcwd()
    new_dir_path = os.path.join(current_dir, dir_name)

    try:
        os.makedirs(new_dir_path, exist_ok=True)
        print(f"Directory '{new_dir_path}' created successfully (or already exists).")

        main_file_path = os.path.join(new_dir_path, "main.py")

        print(f"File '{main_file_path}' created successfully.")

        os.chdir(new_dir_path)
        print(f"Changed current directory to: {os.getcwd()}")

        print(f"Opening '{main_file_path}' with nvim...")
        subprocess.run(["nvim", "main.py"])

        print("Nvim session finished.")

    except FileExistsError:
        print(f"Error: File '{main_file_path}' already exists and was not overwritten.")
    except FileNotFoundError:
        print(
            "Error: nvim command not found. Make sure Neovim is installed and in your system's PATH."
        )
    except OSError as e:
        print(f"Error during directory or file operation: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")


if __name__ == "__main__":
    create_project_directory_and_file()
