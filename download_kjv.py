"""
Download KJV Bible from public domain GitHub source and convert to app format.
Source: https://github.com/aruljohn/Bible-kjv (KJV is public domain)
App format: { "Book Name": { "chapter_num": { "verse_num": "text" } } }
"""
import json
import os
import urllib.request

BOOKS = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua", "Judges", "Ruth",
    "1 Samuel", "2 Samuel", "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles",
    "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs", "Ecclesiastes",
    "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
    "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
    "Zephaniah", "Haggai", "Zechariah", "Malachi",
    "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
    "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians",  
    "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy",
    "Titus", "Philemon", "Hebrews", "James", "1 Peter", "2 Peter",
    "1 John", "2 John", "3 John", "Jude", "Revelation"
]

BASE_URL = "https://raw.githubusercontent.com/aruljohn/Bible-kjv/master/"

def download_and_convert():
    combined = {}
    for i, book in enumerate(BOOKS):
        url_name = book.replace(" ", "")
        url = f"{BASE_URL}{url_name}.json"
        print(f"[{i+1}/{len(BOOKS)}] Downloading {book}...", end=" ", flush=True)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode("utf-8"))

            # Convert from GitHub format to app format
            book_data = {}
            for chapter in data.get("chapters", []):
                ch_num = str(chapter["chapter"])
                verses = {}
                for verse in chapter.get("verses", []):
                    verses[str(verse["verse"])] = verse["text"].strip()
                book_data[ch_num] = verses

            # Use "Psalm" as key (matching other versions) but source uses "Psalms"
            key = "Psalm" if book == "Psalms" else book
            combined[key] = book_data
            print(f"OK ({len(book_data)} chapters)")
        except Exception as e:
            print(f"FAILED: {e}")

    out_dir = os.path.join("lib", "Bible", "KJV")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "KJV_bible.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(combined, f, indent=4, ensure_ascii=False)
    print(f"\nSaved to {out_path} ({len(combined)} books)")

if __name__ == "__main__":
    download_and_convert()
