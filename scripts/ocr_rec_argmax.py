"""Convert the PP-OCRv6 recogniser ONNX so it also emits argmax and max-probability.

Appends ArgMax(axis=2) and ReduceMax(axes=[2]) over the Softmax output and
replaces the graph outputs with (idx int64 [N,T], maxp float [N,T]). Then checks
that the converted model reproduces the source model's argmax and max exactly
on random inputs.

Usage: python scripts/ocr_rec_argmax.py [SRC] [DST]
  SRC default: app/assets/ocr/PP-OCRv6_rec_small.onnx
  DST default: app/assets/ocr/PP-OCRv6_rec_small_argmax.onnx
"""
import sys
import pathlib

import numpy as np
import onnx
import onnx.helper
import onnxruntime as ort

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_SRC = ROOT / "app" / "assets" / "ocr" / "PP-OCRv6_rec_small.onnx"
DEFAULT_DST = ROOT / "app" / "assets" / "ocr" / "PP-OCRv6_rec_small_argmax.onnx"

SHAPES = [(1, 3, 48, 320), (3, 3, 48, 320), (2, 3, 48, 640)]


def convert(src: pathlib.Path, dst: pathlib.Path) -> None:
    m = onnx.load(str(src))
    scores = m.graph.output[0].name
    if len(m.graph.output[0].type.tensor_type.shape.dim) != 3:
        print("ERROR: expected rank-3 output")
        sys.exit(1)

    m.graph.node.append(
        onnx.helper.make_node("ArgMax", [scores], ["idx"], axis=2, keepdims=0)
    )
    m.graph.node.append(
        onnx.helper.make_node("ReduceMax", [scores], ["maxp"], axes=[2], keepdims=0)
    )

    del m.graph.output[:]
    m.graph.output.extend([
        onnx.helper.make_tensor_value_info("idx", onnx.TensorProto.INT64, ["N", "T"]),
        onnx.helper.make_tensor_value_info("maxp", onnx.TensorProto.FLOAT, ["N", "T"]),
    ])

    onnx.checker.check_model(m)
    onnx.save(m, str(dst))


def verify(src: pathlib.Path, dst: pathlib.Path) -> None:
    src_sess = ort.InferenceSession(str(src), providers=["CPUExecutionProvider"])
    dst_sess = ort.InferenceSession(str(dst), providers=["CPUExecutionProvider"])
    rng = np.random.default_rng(0)
    for shape in SHAPES:
        x = rng.uniform(-1.0, 1.0, size=shape).astype(np.float32)
        ref = src_sess.run(None, {"x": x})[0]
        idx, maxp = dst_sess.run(["idx", "maxp"], {"x": x})
        ok = (
            idx.dtype == np.int64
            and np.array_equal(idx, ref.argmax(axis=2))
            and np.allclose(maxp, ref.max(axis=2), rtol=0, atol=1e-6)
        )
        if not ok:
            print(f"MISMATCH {shape}")
            sys.exit(1)
        print(f"OK {shape}")


def main() -> None:
    args = sys.argv[1:]
    src = pathlib.Path(args[0]) if len(args) > 0 else DEFAULT_SRC
    dst = pathlib.Path(args[1]) if len(args) > 1 else DEFAULT_DST
    convert(src, dst)
    verify(src, dst)
    print(f"ALL OK  src={src.stat().st_size} dst={dst.stat().st_size}")
    sys.exit(0)


if __name__ == "__main__":
    main()
