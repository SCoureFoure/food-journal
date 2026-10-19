# On-device OCR models

Used by receipt scan (`specs/receipt_scan.spec.md`). Run with ONNX Runtime through
`flutter_onnxruntime`; pre/post-processing is plain Dart in `lib/models/receipt_ocr/`.

| File | Upstream model | SHA-256 |
| --- | --- | --- |
| `PP-OCRv6_det_small.onnx` | PaddleOCR `PP-OCRv6_small_det` | `090f04abcd9d9a7498bc4ebf677e4cb9bdce1fe4197ddb7e529f1ef44e1ff94f` |
| `PP-OCRv6_rec_small.onnx` | PaddleOCR `PP-OCRv6_small_rec` | `6f327246b50388f3c176ae304bd95767ea6dc0c9ae92153ef8cbe210b3c14884` |
| `rec_dict.txt` | character list from the recogniser's `character` metadata | — |

License: Apache-2.0 (PaddleOCR). ONNX files as distributed by RapidOCR 3.10.0
(<https://github.com/RapidAI/RapidOCR>, Apache-2.0). Model cards:
<https://huggingface.co/PaddlePaddle/PP-OCRv6_small_det_onnx>,
<https://huggingface.co/PaddlePaddle/PP-OCRv6_small_rec_onnx>.

Chosen by a bake-off on five real receipts: 96.6% of item lines read exactly, 84.6% of
quantity lines. Smaller models lost quantity lines.
