import json
import pickle
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MODEL_PATH = ROOT / "models" / "six_gesture_final_model.pkl"
REPORT_PATH = ROOT / "outputs" / "six_gesture_model_report.json"
OUTPUT_PATH = ROOT / "iPhone App" / "Gesture2AudioUser" / "Gesture2AudioUser" / "six_gesture_model.json"


def build_feature_names(channels: list[str], target_frames: int, sequence_frames: int) -> list[str]:
    signal_names = [*channels, "acc_mag", "gyro_mag"]
    feature_names: list[str] = []

    for block_name in ("signal", "delta", "delta2"):
        for stat_name in ("mean", "std", "min", "max"):
            for signal_name in signal_names:
                feature_names.append(f"{block_name}_{signal_name}_{stat_name}")
        for percentile in (10, 25, 50, 75, 90):
            for signal_name in signal_names:
                feature_names.append(f"{block_name}_{signal_name}_p{percentile}")
        for signal_name in signal_names:
            feature_names.append(f"{block_name}_{signal_name}_mean_square")

    for left_index, left_name in enumerate(signal_names):
        for right_name in signal_names[left_index + 1 :]:
            feature_names.append(f"corr_{left_name}_{right_name}")

    for frame_index in range(sequence_frames):
        for channel in channels:
            feature_names.append(f"shape_{frame_index:02d}_{channel}")

    return feature_names


def main() -> None:
    artifact = pickle.loads(MODEL_PATH.read_bytes())
    pipeline = artifact["model"]
    scaler = pipeline.named_steps["standardscaler"]
    selector = pipeline.named_steps["selectkbest"]
    classifier = pipeline.named_steps["logisticregression"]

    selected_indices = selector.get_support(indices=True).astype(int).tolist()
    labels = artifact["labels"]
    channels = artifact["channels"]
    target_frames = int(artifact["target_frames"])
    sequence_frames = int(artifact["sequence_frames"])
    feature_names = build_feature_names(channels, target_frames, sequence_frames)

    report = json.loads(REPORT_PATH.read_text(encoding="utf-8")) if REPORT_PATH.exists() else {}
    selected_report = report.get("results", {}).get(artifact["model_name"], {})

    payload = {
        "schema_version": 1,
        "generated_on": artifact["generated_on"],
        "description": "Six-gesture Apple Watch IMU classifier exported for the iPhone user app.",
        "model_type": artifact["model_name"],
        "labels": labels,
        "display_names": {
            "leaf": "Leaf",
            "tree": "Tree",
            "bird": "Bird",
            "ocean": "Wave",
            "river": "Fish",
            "rain": "Cloud",
        },
        "sound_layers": {
            "leaf": "Rustling leaves",
            "tree": "Forest sound",
            "bird": "Bird chirps",
            "ocean": "Ocean waves",
            "river": "River sound",
            "rain": "Rain sound",
        },
        "training_source": artifact["training_source"],
        "sample_count": int(artifact["training_sample_count"]),
        "feature_count": int(artifact["feature_count"]),
        "selected_feature_count": int(len(selected_indices)),
        "target_frames": target_frames,
        "sequence_frames": sequence_frames,
        "channels": channels,
        "feature_names": feature_names,
        "selected_feature_indices": selected_indices,
        "selected_feature_names": [feature_names[index] for index in selected_indices],
        "scaler": {
            "mean": scaler.mean_.astype(float).tolist(),
            "scale": scaler.scale_.astype(float).tolist(),
        },
        "classifier": {
            "classes": classifier.classes_.astype(int).tolist(),
            "coefficients": classifier.coef_.astype(float).tolist(),
            "intercepts": classifier.intercept_.astype(float).tolist(),
            "regularization_c": float(classifier.C),
        },
        "metrics": {
            "random_holdout": selected_report.get("random_holdout", {}),
            "leave_one_participant_out": selected_report.get("leave_one_participant_out", {}),
        },
    }

    OUTPUT_PATH.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"wrote {OUTPUT_PATH}")
    print(f"labels: {', '.join(labels)}")
    print(f"features: {payload['feature_count']} -> {payload['selected_feature_count']}")


if __name__ == "__main__":
    main()
