"""Download complete Bible translations using meaningless package."""
import json
import os
import sys

from meaningless import JSONDownloader

# Books of the Bible in order
BOOKS = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua",
    "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
    "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
    "Psalm", "Proverbs", "Ecclesiastes", "Song Of Solomon", "Isaiah",
    "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel",
    "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah",
    "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John",
    "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians",
    "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
    "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon",
    "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
    "Jude", "Revelation",
]

BIBLE_DIR = os.path.join(os.path.dirname(__file__), "lib", "Bible")

# Versions to download - popular ones only
VERSIONS = ["KJV", "NKJV", "NIV", "ESV", "NLT", "NASB", "AMP", "CSB", "NLV", "NET", "MEV", "GW", "ISV", "WEB"]

def check_existing(version):
    """Check if a version already has complete data."""
    json_path = os.path.join(BIBLE_DIR, version, f"{version}_bible.json")
    if os.path.exists(json_path):
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            if len(data) >= 60:  # At least 60 books = mostly complete
                return True
    return False

def download_version(version):
    """Download all books for a Bible version."""
    version_dir = os.path.join(BIBLE_DIR, version)
    books_dir = os.path.join(version_dir, f"{version}_books")
    os.makedirs(books_dir, exist_ok=True)
    
    downloader = JSONDownloader(
        translation=version,
        show_passage_numbers=False,
        strip_excess_whitespace=True,
        enable_multiprocessing=True,
    )
    
    for i, book in enumerate(BOOKS):
        book_file = os.path.join(books_dir, f"{book}.json")
        if os.path.exists(book_file):
            # Check if file has actual content
            try:
                with open(book_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    if data and any(k != "Info" for k in data):
                        print(f"  [{i+1}/{len(BOOKS)}] {book} - already exists, skipping")
                        continue
            except (json.JSONDecodeError, IOError):
                pass
        
        print(f"  [{i+1}/{len(BOOKS)}] Downloading {book}...", end="", flush=True)
        max_retries = 3
        for attempt in range(max_retries):
            try:
                downloader.download_book(book, book_file)
                print(" OK")
                break
            except Exception as e:
                if attempt < max_retries - 1:
                    print(f" retry {attempt+2}...", end="", flush=True)
                    import time
                    time.sleep(2)
                else:
                    print(f" FAILED: {e}")

def combine_books(version):
    """Combine individual book JSONs into a single _bible.json."""
    version_dir = os.path.join(BIBLE_DIR, version)
    books_dir = os.path.join(version_dir, f"{version}_books")
    output = os.path.join(version_dir, f"{version}_bible.json")
    
    if not os.path.isdir(books_dir):
        print(f"  No books directory found for {version}")
        return 0
    
    combined = {}
    for fname in os.listdir(books_dir):
        if not fname.endswith('.json'):
            continue
        fpath = os.path.join(books_dir, fname)
        try:
            with open(fpath, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if "Info" in data:
                    del data["Info"]
                for book_name, chapters in data.items():
                    for ch, verses in chapters.items():
                        for vn, vt in verses.items():
                            data[book_name][ch][vn] = vt.strip()
                combined.update(data)
        except (json.JSONDecodeError, IOError) as e:
            print(f"  Error parsing {fname}: {e}")
    
    # Order by canonical book order
    ordered = {b: combined[b] for b in BOOKS if b in combined}
    
    with open(output, 'w', encoding='utf-8') as f:
        json.dump(ordered, f, indent=4)
    
    print(f"  Combined {len(ordered)} books into {version}_bible.json")
    return len(ordered)

def main():
    versions = sys.argv[1:] if len(sys.argv) > 1 else VERSIONS
    
    for version in versions:
        print(f"\n{'='*50}")
        print(f"Processing {version}...")
        print(f"{'='*50}")
        
        if check_existing(version):
            print(f"  {version} already has complete data, skipping download.")
            continue
        
        download_version(version)
        count = combine_books(version)
        
        if count >= 60:
            print(f"  SUCCESS: {version} has {count} books")
        else:
            print(f"  WARNING: {version} only has {count} books (incomplete)")

if __name__ == "__main__":
    main()
