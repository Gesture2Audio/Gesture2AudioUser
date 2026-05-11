import argparse
import json
from pathlib import Path
from statistics import mean

import numpy as np
from sklearn.linear_model import LogisticRegressionCV
from sklearn.metrics import accuracy_score, confusion_matrix
from sklearn.model_selection import StratifiedKFold, train_test_split
from sklearn.preprocessing import StandardScaler


TARGET_FRAMES = 151
DOWNSAMPLE_BINS = 32
RAW_CHANNELS = ("ax", "ay", "az", "gx", "gy", "gz", "acc_mag", "gyro_mag")


def magnitude(x: float, y: float, z: float) -> float:
    return float((x * x + y * y + z * z) ** 0.5)


def fixed_length_frames(frames: list[dict], target_frames: int = TARGET_FRAMES) -> list[dict]:
    if not frames:
        return []
    result = list(frames[:target_frames])
    while len(result) < target_frames:
        result.append(dict(result[-1]))
    return result


def sequence_rows(frames: list[dict]) -> np.ndarray:
    fixed = fixed_length_frames(frames)
    rows = []
    for frame in fixed:
        ax = float(frame["ax"])
        ay = float(frame["ay"])
        az = float(frame["az"])
        gx = float(frame["gx"])
        gy = float(frame["gy"])
        gz = float(frame["gz"])
        rows.append([
            ax,
            ay,
            az,
            gx,
            gy,
            gz,
            magnitude(ax, ay, az),
            magnitude(gx, gy, gz),
        ])
    return np.asarray(rows, dtype=np.float64)


def downsample_rows(rows: np.ndarray, bins: int = DOWNSAMPLE_BINS) -> np.ndarray:
    segments = np.array_split(rows, bins, axis=0)
    return np.asarray([segment.mean(axis=0) for segment in segments], dtype=np.float64)


def summary_features(rows: np.ndarray) -> list[float]:
    features: list[float] = []
    for column in range(rows.shape[1]):
        values = rows[:, column]
        abs_values = np.abs(values)
        features.extend(
            [
                float(np.mean(values)),
                float(np.std(values)),
                float(np.min(values)),
                float(np.max(values)),
                float(np.sqrt(np.mean(values * values))),
                float(np.mean(abs_values)),
                float(np.percentile(values, 25)),
                float(np.percentile(values, 50)),
                float(np.percentile(values, 75)),
                float(np.max(abs_values)),
            ]
        )
    return features


def features_for_frames(frames: list[dict]) -> np.ndarray:
    rows = sequence_rows(frames)
    deltas = np.vstack([np.zeros((1, rows.shape[1])), np.diff(rows, axis=0)])
    downsampled = downsample_rows(rows)

    feature_vector = np.concatenate(
        [
            downsampled.reshape(-1),
            np.asarray(summary_features(rows), dtype=np.float64),
            np.asarray(summary_features(deltas), dtype=np.float64),
        ]
    )
    return feature_vector


def load_samples(path: Path) -> list[dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    samples = payload["samples"]
    return [sample for sample in samples if sample["label"] in {"bird", "river"}]


def build_dataset(samples: list[dict]) -> tuple[np.ndarray, np.ndarray, list[str]]:
    features = [features_for_frames(sample["frames"]) for sample in samples]
    labels = np.asarray([sample["label"] for sample in samples])
    participants = [sample.get("participant", "unknown") for sample in samples]
    return np.vstack(features), labels, participants


def leave_one_participant_out(
    x: np.ndarray, y: np.ndarray, participants: list[str], scaler: StandardScaler, classifier: LogisticRegressionCV
) -> list[dict]:
    reports = []
    unique_participants = sorted(set(participants))
    for held_out in unique_participants:
        train_idx = [i for i, name in enumerate(participants) if name != held_out]
        test_idx = [i for i, name in enumerate(participants) if name == held_out]
        if not train_idx or not test_idx:
            continue

        local_scaler = StandardScaler()
        x_train = local_scaler.fit_transform(x[train_idx])
        x_test = local_scaler.transform(x[test_idx])

        local_model = LogisticRegressionCV(
            Cs=[0.01, 0.1, 1.0, 10.0, 100.0],
            cv=3,
            max_iter=4000,
            penalty="l2",
            solver="lbfgs",
            scoring="accuracy",
            random_state=42,
        )
        local_model.fit(x_train, y[train_idx])
        predictions = local_model.predict(x_test)
        reports.append(
            {
                "held_out_participant": held_out,
                "accuracy": float(accuracy_score(y[test_idx], predictions)),
                "sample_count": int(len(test_idx)),
            }
        )
    return reports


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="data/training_samples_full.json")
    parser.add_argument("--output", default="iPhone App/Gesture2AudioUser/Gesture2AudioUser/bird_river_model.json")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    samples = load_samples(input_path)
    x, y, participants = build_dataset(samples)

    x_train, x_test, y_train, y_test = train_test_split(
        x, y, test_size=0.25, stratify=y, random_state=42
    )

    scaler = StandardScaler()
    x_train_scaled = scaler.fit_transform(x_train)
    x_test_scaled = scaler.transform(x_test)
    x_all_scaled = scaler.transform(x)

    classifier = LogisticRegressionCV(
        Cs=[0.01, 0.1, 1.0, 10.0, 100.0],
        cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=42),
        max_iter=4000,
        penalty="l2",
        solver="lbfgs",
        scoring="accuracy",
        random_state=42,
    )
    classifier.fit(x_train_scaled, y_train)

    holdout_predictions = classifier.predict(x_test_scaled)
    holdout_accuracy = accuracy_score(y_test, holdout_predictions)

    cv_model = LogisticRegressionCV(
        Cs=[0.01, 0.1, 1.0, 10.0, 100.0],
        cv=StratifiedKFold(n_splits=5, shuffle=True, random_state=42),
        max_iter=4000,
        penalty="l2",
        solver="lbfgs",
        scoring="accuracy",
        random_state=42,
    )
    cv_model.fit(x_all_scaled, y)
    cv_scores = cv_model.scores_["river"]
    best_c_index = int(np.where(cv_model.Cs_ == cv_model.C_[0])[0][0])
    mean_cv_accuracy = float(mean(cv_scores[:, best_c_index].tolist()))

    participant_reports = leave_one_participant_out(x, y, participants, scaler, classifier)

    class_order = classifier.classes_.tolist()
    positive_label = class_order[1]
    negative_label = class_order[0]
    confusion = confusion_matrix(y_test, holdout_predictions, labels=class_order).tolist()

    feature_names: list[str] = []
    for bin_index in range(DOWNSAMPLE_BINS):
        for channel in RAW_CHANNELS:
            feature_names.append(f"bin_{bin_index:02d}_{channel}")
    for prefix in ("raw", "delta"):
        for channel in RAW_CHANNELS:
            for stat_name in (
                "mean",
                "std",
                "min",
                "max",
                "rms",
                "abs_mean",
                "p25",
                "p50",
                "p75",
                "max_abs",
            ):
                feature_names.append(f"{prefix}_{channel}_{stat_name}")

    output = {
        "schema_version": 1,
        "generated_on": "2026-05-11",
        "description": "Bird vs river gesture classifier trained from cleaned Apple Watch IMU data.",
        "model_type": "logistic_regression",
        "labels": class_order,
        "display_names": {
            negative_label: "Bird",
            positive_label: "Fish",
        },
        "training_source": str(input_path).replace("\\", "/"),
        "sample_count": int(len(samples)),
        "feature_count": int(x.shape[1]),
        "target_frames": TARGET_FRAMES,
        "downsample_bins": DOWNSAMPLE_BINS,
        "channels": list(RAW_CHANNELS),
        "feature_names": feature_names,
        "scaler": {
            "mean": scaler.mean_.tolist(),
            "scale": scaler.scale_.tolist(),
        },
        "classifier": {
            "positive_label": positive_label,
            "coefficients": classifier.coef_[0].tolist(),
            "intercept": float(classifier.intercept_[0]),
            "selected_c": float(classifier.C_[0]),
        },
        "metrics": {
            "holdout_accuracy": float(holdout_accuracy),
            "holdout_confusion_matrix": {
                "labels": class_order,
                "matrix": confusion,
            },
            "five_fold_cv_accuracy": mean_cv_accuracy,
            "leave_one_participant_out": participant_reports,
        },
    }

    output_path.write_text(json.dumps(output, indent=2), encoding="utf-8")

    print(f"wrote {output_path}")
    print(f"samples: {len(samples)}")
    print(f"features: {x.shape[1]}")
    print(f"5-fold cv accuracy: {mean_cv_accuracy:.3f}")
    print(f"holdout accuracy: {holdout_accuracy:.3f}")
    print(f"holdout labels: {class_order}")
    print(f"holdout confusion matrix: {confusion}")
    for report in participant_reports:
        print(
            "participant split:",
            report["held_out_participant"],
            f"{report['accuracy']:.3f}",
            f"n={report['sample_count']}",
        )


if __name__ == "__main__":
    main()
