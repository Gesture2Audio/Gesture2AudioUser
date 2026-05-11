import argparse
import json
from pathlib import Path

import numpy as np
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import StratifiedKFold, StratifiedShuffleSplit, cross_val_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC


USER_TO_MODEL_LABEL = {
    "leaf": "leaf",
    "tree": "tree",
    "bird": "bird",
    "wave": "ocean",
    "ocean": "ocean",
    "fish": "river",
    "river": "river",
    "cloud": "rain",
    "rain": "rain",
}

CHANNELS = ("ax", "ay", "az", "gx", "gy", "gz")
TARGET_FRAMES = 151


def normalize_label(label):
    key = label.strip().lower()
    if key not in USER_TO_MODEL_LABEL:
        known = ", ".join(sorted(USER_TO_MODEL_LABEL))
        raise ValueError(f"Unknown gesture '{label}'. Known gestures: {known}")
    return USER_TO_MODEL_LABEL[key]


def load_samples(path, labels):
    data = json.loads(path.read_text(encoding="utf-8"))
    selected = [sample for sample in data["samples"] if sample["label"] in labels]
    if not selected:
        raise ValueError(f"No samples found for labels: {labels}")
    return selected


def fixed_length_sequence(frames):
    values = np.array([[frame[channel] for channel in CHANNELS] for frame in frames], dtype=float)

    if len(values) < TARGET_FRAMES:
        pad = np.repeat(values[-1:], TARGET_FRAMES - len(values), axis=0)
        values = np.vstack([values, pad])

    return values[:TARGET_FRAMES]


def features_for_sample(sample):
    sequence = fixed_length_sequence(sample["frames"])

    accel_mag = np.linalg.norm(sequence[:, :3], axis=1, keepdims=True)
    gyro_mag = np.linalg.norm(sequence[:, 3:], axis=1, keepdims=True)
    delta = np.diff(sequence, axis=0, prepend=sequence[:1])

    sequence_features = np.hstack([sequence, accel_mag, gyro_mag, delta]).reshape(-1)

    summary_parts = []
    for block in (sequence, delta):
        summary_parts.extend(
            [
                block.mean(axis=0),
                block.std(axis=0),
                block.min(axis=0),
                block.max(axis=0),
                np.sqrt((block * block).mean(axis=0)),
            ]
        )

    return np.concatenate([sequence_features, *summary_parts])


def build_dataset(samples):
    x = np.array([features_for_sample(sample) for sample in samples])
    y = np.array([sample["label"] for sample in samples])
    return x, y


def build_model(name, seed):
    if name == "svm":
        return make_pipeline(
            StandardScaler(),
            SVC(kernel="rbf", C=3, gamma="scale", class_weight="balanced", probability=True),
        )

    if name == "random_forest":
        return RandomForestClassifier(
            n_estimators=500,
            random_state=seed,
            class_weight="balanced",
        )

    raise ValueError(f"Unknown model: {name}")


def main():
    parser = argparse.ArgumentParser(description="Train a quick two-gesture IMU classifier.")
    parser.add_argument(
        "--data",
        default="data/training_samples_full.json",
        help="Path to the full training JSON with embedded IMU frames.",
    )
    parser.add_argument(
        "--gestures",
        nargs=2,
        default=("bird", "fish"),
        metavar=("GESTURE_A", "GESTURE_B"),
        help="Two gestures to separate. User-facing names like fish/wave/cloud are accepted.",
    )
    parser.add_argument("--test-size", type=float, default=0.25)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument(
        "--model",
        choices=("random_forest", "svm"),
        default="random_forest",
        help="Classifier to use for the demo.",
    )
    parser.add_argument("--output", default="outputs/binary_gesture_demo.json")
    args = parser.parse_args()

    labels = tuple(normalize_label(gesture) for gesture in args.gestures)
    samples = load_samples(Path(args.data), set(labels))
    x, y = build_dataset(samples)

    split = StratifiedShuffleSplit(n_splits=1, test_size=args.test_size, random_state=args.seed)
    train_index, test_index = next(split.split(x, y))

    model = build_model(args.model, args.seed)
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=args.seed)
    cv_scores = cross_val_score(model, x, y, cv=cv)

    model.fit(x[train_index], y[train_index])
    predictions = model.predict(x[test_index])

    label_order = list(labels)
    report = {
        "data": args.data,
        "requested_gestures": list(args.gestures),
        "model_labels": label_order,
        "sample_counts": {label: int((y == label).sum()) for label in label_order},
        "model": args.model,
        "cross_validation": {
            "folds": 5,
            "scores": [float(score) for score in cv_scores],
            "mean_accuracy": float(cv_scores.mean()),
        },
        "train_samples": int(len(train_index)),
        "test_samples": int(len(test_index)),
        "accuracy": float(accuracy_score(y[test_index], predictions)),
        "confusion_matrix": {
            "labels": label_order,
            "matrix": confusion_matrix(y[test_index], predictions, labels=label_order).tolist(),
        },
        "classification_report": classification_report(
            y[test_index],
            predictions,
            labels=label_order,
            output_dict=True,
            zero_division=0,
        ),
    }

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    print(f"Gestures: {args.gestures[0]} vs {args.gestures[1]}")
    print(f"Model labels: {label_order[0]} vs {label_order[1]}")
    print(f"Classifier: {args.model}")
    print(f"Samples: {report['sample_counts']}")
    print(f"5-fold CV accuracy: {report['cross_validation']['mean_accuracy']:.3f}")
    print(f"Train/test: {report['train_samples']} / {report['test_samples']}")
    print(f"Held-out accuracy: {report['accuracy']:.3f}")
    print("Confusion matrix:")
    print(label_order)
    print(np.array(report["confusion_matrix"]["matrix"]))
    print(f"Saved report: {output_path}")


if __name__ == "__main__":
    main()
