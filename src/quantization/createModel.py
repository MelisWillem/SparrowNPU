import os
import warnings

import numpy as np
import onnx
import torch
import torch.ao.quantization as quantization
import torch.nn as nn
from onnxruntime.quantization import CalibrationDataReader, QuantType, quantize_static


class TinyTransformer(nn.Module):
    def __init__(
        self, num_layers=2, d_model=64, nhead=2, d_ff=128, vocab=256, seq_len=32
    ):
        super().__init__()
        self.tok_emb = nn.Embedding(vocab, d_model)
        self.pos_emb = nn.Parameter(torch.randn(1, seq_len, d_model))
        encoder_layer = nn.TransformerEncoderLayer(
            d_model=d_model,
            nhead=nhead,
            dim_feedforward=d_ff,
            activation="relu",
            batch_first=True,  # Use (B, T, C) format instead of (T, B, C)
            bias=True,
            dropout=0.0,  # Disable dropout for inference
        )
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)
        self.ln_f = nn.LayerNorm(d_model)
        self.head = nn.Linear(d_model, vocab, bias=True)

    def forward(self, x):
        # x: (B, T) token ids
        B, T = x.shape
        x = self.tok_emb(x) + self.pos_emb[:, :T, :]
        x = self.transformer(x)  # (B, T, C)
        x = self.ln_f(x)
        logits = self.head(x)  # (B, T, vocab)
        return logits


# we can't use this pytoch quantization as it doesn't support ONNX export for all operations.
def quantize_model_to_int8(model, calibration_data_filename, dtype=torch.qint8):
    """
    Quantize the model to int8 using static quantization.
    This quantizes both weights and activations to int8.

    Args:
        model: TinyTransformer model (should be in eval mode)
        calibration_data: List of input tensors for calibration
        dtype: torch.qint8 or torch.quint8 (default: torch.qint8)

    Returns:
        Quantized model ready for inference
    """
    model.eval()

    # Set quantization configuration
    # Skip quantization for embeddings (not supported by ONNX export)
    # Embeddings are often kept in float for better accuracy anyway
    model.tok_emb.qconfig = None

    # Use default qconfig for other modules
    model.transformer.qconfig = quantization.get_default_qconfig("fbgemm")
    model.head.qconfig = quantization.get_default_qconfig("fbgemm")

    # Prepare model for quantization (suppress deprecation warnings)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", DeprecationWarning)
        quantization.prepare(model, inplace=True)

    # Calibrate with representative data
    with torch.no_grad():
        calibration_data = load_calibration_data(calibration_data_filename)
        for data in calibration_data:
            _ = model(data)

    # Convert to quantized model (suppress deprecation warnings)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", DeprecationWarning)
        quantized_model = quantization.convert(model, inplace=False)
    return quantized_model


def generate_calibration_data(output_filename):
    """
    Create calibration data.
    """
    # set the seed to a fixed value
    torch.manual_seed(42)
    with open(output_filename, "wb") as f:
        for _ in range(100):
            data = (
                torch.randint(0, 256, (1, 32), dtype=torch.long)
                .numpy()
                .astype(np.int64)
            )
            f.write(data.tobytes())


def load_calibration_data(filename):
    """
    Load calibration data from file.
    Returns a list of tensors.
    """
    calibration_data = []
    with open(filename, "rb") as f:
        for _ in range(100):
            data_bytes = f.read(32 * 8)  # 32 integers * 8 bytes (int64)
            if len(data_bytes) < 32 * 8:
                break
            data = np.frombuffer(data_bytes, dtype=np.int64).reshape(1, 32).copy()
            calibration_data.append(torch.from_numpy(data).long())
    return calibration_data


def calibrate_model_with_random_data(model):
    """
    Calibrate the model with random data.
    """
    with torch.no_grad():
        for _ in range(100):
            data = torch.randint(0, 256, (1, 32), dtype=torch.long)
            _ = model(data)


def quantize_onnx_static(onnx_input_path, onnx_output_path, calibration_data_filename):
    """
    Apply static quantization to an ONNX model using calibration data.

    Args:
        onnx_input_path: Path to unquantized ONNX model
        onnx_output_path: Path to save quantized ONNX model
        calibration_data_filename: Path to calibration data file
    """

    # Load ONNX model to get input name
    onnx_model = onnx.load(onnx_input_path)
    input_name = onnx_model.graph.input[0].name

    # Create calibration data reader
    class DataReader(CalibrationDataReader):
        def __init__(self, calibration_data, input_name):
            self.data = calibration_data
            self.input_name = input_name
            self.index = 0

        def get_next(self):
            if self.index < len(self.data):
                result = {self.input_name: self.data[self.index].numpy()}
                self.index += 1
                return result
            return None

    # Load calibration data
    calibration_data = load_calibration_data(calibration_data_filename)
    data_reader = DataReader(calibration_data, input_name)

    # Apply static quantization
    quantize_static(
        model_input=onnx_input_path,
        model_output=onnx_output_path,
        calibration_data_reader=data_reader,
        # use symmetric quantization
        weight_type=QuantType.QInt8,
        activation_type=QuantType.QInt8,
    )


if __name__ == "__main__":
    # Files are stored in data/models, use use __file__ to navigate
    quant_data_path = os.path.join(
        os.path.dirname(__file__), "..", "..", "data", "quantization"
    )

    onnx_model_path = os.path.join(quant_data_path, "model.onnx")
    calibration_data_path = os.path.join(quant_data_path, "calibration_data.bin")
    quantized_model_path = os.path.join(quant_data_path, "quantized_model.onnx")

    # Set the seed to a fixed value
    model = TinyTransformer()
    model.eval()  # Ensure model is in eval mode (disables dropout)
    print(model)

    # Export unquantized model to ONNX first (quantized models can't be exported)
    dummy_input = torch.randint(0, 256, (1, 32), dtype=torch.long)
    print("\nExporting unquantized model to ONNX...")
    torch.onnx.export(model, dummy_input, onnx_model_path)
    print("Saved: model.onnx")

    # Generate calibration data
    generate_calibration_data(calibration_data_path)

    # Quantize ONNX model with static quantization using onnxruntime
    # We can't use pytorch quantization as it doesn't support ONNX export for all operations.
    quantize_onnx_static(onnx_model_path, quantized_model_path, calibration_data_path)
    print("Saved: quantized_model.onnx (ONNX static quantization)")
