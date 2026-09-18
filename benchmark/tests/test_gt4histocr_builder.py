import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SUBSET_PATH = ROOT / "gt4histocr" / "build_subset.py"
JOIN_PATH = ROOT / "gt4histocr" / "join_predictions.py"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


subset = load_module("gt4_subset", SUBSET_PATH)
joiner = load_module("gt4_join", JOIN_PATH)


class GT4HistOCRUtilitiesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "GT4HistOCR"

        for subcorpus, documents in {
            "dta19": [
                "1882-book-a",
                "1853-book-b",
            ],
            "EarlyModernLatin": [
                "1500-latin-a",
                "1600-latin-b",
            ],
        }.items():
            for document in documents:
                directory = (
                    self.root
                    / subcorpus
                    / document
                )
                directory.mkdir(parents=True)

                for i in range(3):
                    base = f"{i:05d}"
                    (
                        directory
                        / f"{base}.gt.txt"
                    ).write_text(
                        f"text {subcorpus} "
                        f"{document} {i}",
                        encoding="utf-8",
                    )
                    (
                        directory
                        / f"{base}.nrm.png"
                    ).write_bytes(b"fixture")

    def tearDown(self):
        self.tmp.cleanup()

    def test_scan_pairs_preserves_document_and_reference(self):
        rows = subset.scan_pairs(self.root)
        self.assertEqual(len(rows), 12)

        row = next(
            item
            for item in rows
            if item["document_id"] == "1882-book-a"
        )

        self.assertEqual(
            row["subcorpus"],
            "dta19",
        )
        self.assertEqual(
            row["corpus_language"],
            "German",
        )
        self.assertEqual(
            row["year"],
            1882,
        )
        self.assertTrue(
            row["image_path"].endswith(
                ".nrm.png"
            )
        )

    def test_balanced_sample_caps_each_document(self):
        rows = subset.scan_pairs(self.root)

        selected = subset.balanced_sample(
            rows,
            per_subcorpus=4,
            max_per_document=2,
            seed=2027,
        )

        counts = {}
        for row in selected:
            key = (
                row["subcorpus"],
                row["document_id"],
            )
            counts[key] = counts.get(key, 0) + 1

        self.assertEqual(len(selected), 8)
        self.assertTrue(
            all(value <= 2 for value in counts.values())
        )

    def test_join_predictions_requires_complete_ids(self):
        rows = subset.scan_pairs(self.root)
        selected = subset.balanced_sample(
            rows,
            per_subcorpus=2,
            max_per_document=1,
            seed=2027,
        )

        prediction_path = (
            Path(self.tmp.name)
            / "predictions.json"
        )
        predictions = {
            row["line_id"]: row["reference"]
            for row in selected[:-1]
        }
        prediction_path.write_text(
            json.dumps(predictions),
            encoding="utf-8",
        )

        with self.assertRaisesRegex(
            ValueError,
            "missing 1 lines",
        ):
            joiner.join(
                selected,
                [
                    "model="
                    + str(prediction_path)
                ],
                allow_missing=False,
            )

    def test_join_predictions_creates_one_row_per_system(self):
        rows = subset.scan_pairs(self.root)
        selected = subset.balanced_sample(
            rows,
            per_subcorpus=2,
            max_per_document=1,
            seed=2027,
        )

        specs = []
        for name in ("A", "B"):
            path = (
                Path(self.tmp.name)
                / f"{name}.json"
            )
            path.write_text(
                json.dumps({
                    row["line_id"]:
                    name + " " + row["reference"]
                    for row in selected
                }),
                encoding="utf-8",
            )
            specs.append(
                f"{name}={path}"
            )

        joined, systems = joiner.join(
            selected,
            specs,
        )

        self.assertEqual(
            len(joined),
            2 * len(selected),
        )
        self.assertEqual(
            {row["system"] for row in joined},
            {"A", "B"},
        )
        self.assertEqual(
            len(systems),
            2,
        )


if __name__ == "__main__":
    unittest.main()
