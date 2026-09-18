import csv
import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
GENERATOR_PATH = (
    ROOT
    / "generate_docworkflow_configs.py"
)

spec = importlib.util.spec_from_file_location(
    "policy_config_generator",
    GENERATOR_PATH,
)
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)


class PolicyConfigGeneratorTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.prompts = self.root / "prompts"
        self.prompts.mkdir()

        (
            self.prompts
            / "neutral.txt"
        ).write_text(
            "Transcribe the line.\n"
            "Output ONLY the transcription.\n",
            encoding="utf-8",
        )

        self.systems = (
            self.root
            / "systems.csv"
        )
        with self.systems.open(
            "w",
            encoding="utf-8",
            newline="",
        ) as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=[
                    "system",
                    "model",
                    "model_family",
                    "prompt_policy",
                    "prompt_condition",
                    "model_id",
                    "revision",
                    "prompt_file",
                ],
            )
            writer.writeheader()
            writer.writerow({
                "system": "medusa_neutral",
                "model": "MEDUSA",
                "model_family": "specialized_vlm",
                "prompt_policy": "neutral",
                "prompt_condition": "neutral",
                "model_id": "ENC-PSL/Medusa0.1Line-4B",
                "revision": "abc",
                "prompt_file": "prompts/neutral.txt",
            })
            writer.writerow({
                "system": "kraken",
                "model": "Kraken",
                "model_family": "conventional",
                "prompt_policy": "fixed",
                "prompt_condition": "fixed",
                "model_id": "kraken-model",
                "revision": "abc",
                "prompt_file": "",
            })

    def tearDown(self):
        self.tmp.cleanup()

    def test_generator_skips_fixed_and_embeds_prompt(self):
        output = (
            self.root
            / "configs"
        )

        written = generator.generate(
            systems_path=self.systems,
            repo_root=self.root,
            data_root="/data/test",
            output=output,
        )

        self.assertEqual(
            len(written),
            1,
        )

        config = written[0].read_text(
            encoding="utf-8"
        )

        self.assertIn(
            'model_name: "ENC-PSL/Medusa0.1Line-4B"',
            config,
        )
        self.assertIn(
            'model_class: "AutoModelForImageTextToText"',
            config,
        )
        self.assertIn(
            "Transcribe the line.",
            config,
        )
        self.assertIn(
            'test: "/data/test"',
            config,
        )
        self.assertFalse(
            (output / "kraken.yml").exists()
        )


if __name__ == "__main__":
    unittest.main()
