import sys
import fitz  # PyMuPDF


def fix_character_encoding(text):
    repaired = []
    for char in text:
        code = ord(char)
        # Latin-1 byte range containing corrupted Cyrillic characters
        if code < 256:
            try:
                repaired.append(bytes([code]).decode("cp1251"))
            except UnicodeDecodeError:
                repaired.append(char)
        else:
            # Preserve math symbols and extended Unicode unchanged
            repaired.append(char)
    return "".join(repaired)


def process_pdf(input_pdf, output_txt):
    doc = fitz.open(input_pdf)
    with open(output_txt, "w", encoding="utf-8") as out:
        for page_num in range(len(doc)):
            raw_text = doc[page_num].get_text()
            clean_text = fix_character_encoding(raw_text)
            out.write(f"--- Page {page_num + 1} ---\n")
            out.write(clean_text)
            out.write("\n\n")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 extract_clean_text.py input.pdf [output.txt]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "extracted_text.txt"
    process_pdf(input_file, output_file)
    print(f"Extraction complete! Clean text saved to: {output_file}")
