"""Check actual v1.3 Runtime outputs and render report pages for visual review."""
from pathlib import Path
import argparse
import csv
import json
import math
import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageOps


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("current", type=Path)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    status = json.loads((args.current / "paper_study_status.json").read_text(encoding="utf-8"))
    assert status["status"] == "complete" and status["version"] == "1.3"
    assert status["caseCount"] == 36 and status["refinementCount"] == 3
    def read_csv(path):
        with path.open(encoding="utf-8-sig", newline="") as file:
            return list(csv.DictReader(file))
    old = read_csv(args.baseline / "paper_results.csv")
    new = read_csv(args.current / "paper_results.csv")
    assert len(old) == len(new) == 36
    differences, missing = [], 0
    for left, right in zip(old, new):
        assert left.keys() == right.keys() and left["case_id"] == right["case_id"]
        for key in left:
            if key in {"case_id", "elapsed_wall_s"}:
                continue
            try:
                a, b = float(left[key]), float(right[key])
            except ValueError:
                assert left[key] == right[key]
                continue
            if math.isnan(a) and math.isnan(b):
                missing += 1
                continue
            assert math.isfinite(a) and math.isfinite(b)
            differences.append(abs(a - b))
    assert max(differences) == 0
    bad_names = [str(p) for p in args.current.rglob("*") if not p.name.isascii()]
    assert not bad_names, bad_names
    records = {"version": "1.3", "caseCount": 36, "refinementCount": 3,
               "numericValuesCompared": len(differences), "maximumAbsoluteDifference": max(differences),
               "matchingOptionalUnavailableValues": missing, "nonAsciiOutputNames": bad_names,
               "excludedColumns": ["case_id (checked separately)", "elapsed_wall_s"]}
    for lang in ("zh", "en"):
        folder = args.output / f"report_{lang}"
        folder.mkdir()
        pdf = pdfium.PdfDocument(str(args.current / "report" / f"thermal_report_{lang}.pdf"))
        images, lengths = [], []
        for index in range(len(pdf)):
            page = pdf[index]
            text = page.get_textpage()
            lengths.append(len(text.get_text_range().strip()))
            text.close()
            filename = folder / f"page_{index + 1:02}.png"
            page.render(scale=1.5).to_pil().save(filename)
            images.append(filename)
            page.close()
        assert min(lengths) > 0
        records[f"report_{lang}"] = {"pages": len(pdf), "nonemptyPages": True}
        pdf.close()
        for first in range(0, len(images), 9):
            sheet = Image.new("RGB", (1440, 1980), "#e9eded")
            for index, filename in enumerate(images[first:first + 9]):
                with Image.open(filename) as source:
                    thumbnail = ImageOps.contain(source.convert("RGB"), (460, 625))
                x, y = (index % 3) * 480, (index // 3) * 660
                sheet.paste(thumbnail, (x + (480 - thumbnail.width) // 2, y + 24))
                ImageDraw.Draw(sheet).text((x + 10, y + 5), filename.stem, fill="black")
            sheet.save(folder / f"sheet_{first // 9 + 1:02}.jpg")
    (args.output / "checks.json").write_text(json.dumps(records, indent=2), encoding="utf-8")
    print(json.dumps(records, indent=2))


if __name__ == "__main__":
    main()
