import csv
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "cmmhwr"
    / "build_analysis_table.py"
)

SPEC = importlib.util.spec_from_file_location(
    "build_analysis_table",
    MODULE_PATH,
)
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)


ALTO = """<?xml version="1.0" encoding="UTF-8"?>
<alto xmlns="http://www.loc.gov/standards/alto/ns-v4#">
  <Layout>
    <Page WIDTH="100" HEIGHT="100">
      <PrintSpace>
        <TextBlock>
          <TextLine ID="l1" HPOS="10" VPOS="20" WIDTH="60" HEIGHT="10">
            <String CONTENT="In"/>
            <String CONTENT="principio"/>
          </TextLine>
          <TextLine ID="l2">
            <Shape>
              <Polygon POINTS="5,40 80,40 80,55 5,55"/>
            </Shape>
            <String CONTENT="erat"/>
            <String CONTENT="verbum"/>
          </TextLine>
        </TextBlock>
      </PrintSpace>
    </Page>
  </Layout>
</alto>
"""


class CMMHWRBuilderTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.gt = self.root / "gt" / "doc1"
        self.gt.mkdir(parents=True)
        (self.gt / "page1.xml").write_text(
            ALTO,
            encoding="utf-8",
        )
        # The builder only needs the path to exist; it does not decode images.
        (self.gt / "page1.png").write_bytes(b"fixture")

        self.a = self.root / "a.json"
        self.b = self.root / "b.json"

        self.a.write_text(
            json.dumps(
                {
                    "l1": "In principlo",
                    "l2": "erat verbum",
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
        self.b.write_text(
            json.dumps(
                {
                    "l1": "In principio",
                    "l2": "erat uerbum",
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )

    def tearDown(self):
        self.tmp.cleanup()

    def test_ground_truth_extracts_text_geometry_and_image(self):
        rows = builder.read_ground_truth(
            self.root / "gt",
            image_root=None,
        )

        self.assertEqual(len(rows), 2)
        by_id = {row["line_id"]: row for row in rows}

        self.assertEqual(
            by_id["l1"]["reference"],
            "In principio",
        )
        self.assertEqual(by_id["l1"]["hpos"], 10)
        self.assertEqual(by_id["l1"]["image_path"], "doc1/page1.png")

        self.assertEqual(
            by_id["l2"]["polygon"],
            "5,40 80,40 80,55 5,55",
        )
        self.assertEqual(by_id["l2"]["hpos"], 5)
        self.assertEqual(by_id["l2"]["vpos"], 40)
        self.assertEqual(by_id["l2"]["width"], 75)
        self.assertEqual(by_id["l2"]["height"], 15)

    def test_build_table_is_strictly_paired(self):
        gt_rows = builder.read_ground_truth(
            self.root / "gt",
            image_root=None,
        )

        rows, systems = builder.build_table(
            gt_rows=gt_rows,
            system_specs=[
                f"A={self.a}",
                f"B={self.b}",
            ],
            benchmark="cmmhwr26",
            metadata={},
            metadata_columns=[],
            allow_missing=False,
        )

        self.assertEqual(len(rows), 4)
        self.assertEqual(
            {row["system"] for row in rows},
            {"A", "B"},
        )
        self.assertEqual(
            {row["line_id"] for row in rows},
            {"l1", "l2"},
        )
        self.assertEqual(len(systems), 2)

    def test_missing_predictions_fail_by_default(self):
        incomplete = self.root / "incomplete.json"
        incomplete.write_text(
            json.dumps({"l1": "In principio"}),
            encoding="utf-8",
        )

        gt_rows = builder.read_ground_truth(
            self.root / "gt",
            image_root=None,
        )

        with self.assertRaisesRegex(
            ValueError,
            "missing 1 ground-truth line",
        ):
            builder.build_table(
                gt_rows=gt_rows,
                system_specs=[f"A={incomplete}"],
                benchmark="cmmhwr26",
                metadata={},
                metadata_columns=[],
                allow_missing=False,
            )

    def test_unknown_prediction_ids_fail(self):
        bad = self.root / "bad.json"
        bad.write_text(
            json.dumps(
                {
                    "l1": "In principio",
                    "l2": "erat verbum",
                    "not-in-gt": "extra",
                }
            ),
            encoding="utf-8",
        )

        gt_rows = builder.read_ground_truth(
            self.root / "gt",
            image_root=None,
        )

        with self.assertRaisesRegex(
            ValueError,
            "prediction IDs are absent from ground truth",
        ):
            builder.build_table(
                gt_rows=gt_rows,
                system_specs=[f"A={bad}"],
                benchmark="cmmhwr26",
                metadata={},
                metadata_columns=[],
                allow_missing=False,
            )


if __name__ == "__main__":
    unittest.main()
