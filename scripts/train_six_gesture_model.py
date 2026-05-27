import json
import pickle
from collections import Counter
from pathlib import Path

import numpy as np
from sklearn.decomposition import PCA
from sklearn.ensemble import ExtraTreesClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression, RidgeClassifier
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.feature_selection import SelectKBest, f_classif
from sklearn.preprocessing import StandardScaler
from sklearn.svm import LinearSVC, SVC


ROOT = Path(__file__).resolve().parent.parent
CLEANED_DATASET = ROOT / "data" / "cleaned_training_v2" / "cleaned_training_samples_full.json"
COMBINED_DATASET = ROOT / "data" / "New training set" / "combined_training_samples_full.json"
REPORT_PATH = ROOT / "outputs" / "six_gesture_model_report.json"
MODEL_PATH = ROOT / "models" / "six_gesture_final_model.pkl"

CHANNELS = ["ax", "ay", "az", "gx", "gy", "gz"]
TARGET_FRAMES = 128
SEQUENCE_FRAMES = 64
GENERATED_ON = "2026-05-27"


def load_payload() -> dict:
    source = CLEANED_DATASET if CLEANED_DATASET.exists() else COMBINED_DATASET
    with source.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    payload["_source_path"] = source
    return payload


def sample_to_array(sample: dict) -> np.ndarray:
    arr = np.array(
        [[frame[channel] for channel in CHANNELS] for frame in sample["frames"]],
        dtype=np.float32,
    )
    return arr - arr[:5].mean(axis=0, keepdims=True)


def resample_array(arr: np.ndarray, target: int) -> np.ndarray:
    if len(arr) == target:
        return arr.astype(np.float32)
    old_x = np.linspace(0, 1, len(arr))
    new_x = np.linspace(0, 1, target)
    return np.stack(
        [np.interp(new_x, old_x, arr[:, column]) for column in range(arr.shape[1])],
        axis=1,
    ).astype(np.float32)


def feature_vector(arr: np.ndarray) -> np.ndarray:
    resampled = resample_array(arr, TARGET_FRAMES)
    acc_mag = np.linalg.norm(resampled[:, :3], axis=1, keepdims=True)
    gyro_mag = np.linalg.norm(resampled[:, 3:], axis=1, keepdims=True)
    signals = np.concatenate([resampled, acc_mag, gyro_mag], axis=1)
    delta = np.diff(signals, axis=0)
    delta2 = np.diff(delta, axis=0)

    features = []
    for block in [signals, delta, delta2]:
        features.extend(block.mean(axis=0))
        features.extend(block.std(axis=0))
        features.extend(block.min(axis=0))
        features.extend(block.max(axis=0))
        features.extend(np.percentile(block, [10, 25, 50, 75, 90], axis=0).ravel())
        features.extend((block * block).mean(axis=0))

    corr = np.nan_to_num(np.corrcoef(signals.T))
    features.extend(corr[np.triu_indices(corr.shape[0], 1)])
    features.extend(resample_array(arr, SEQUENCE_FRAMES).ravel())
    return np.array(features, dtype=np.float32)


def build_matrix(payload: dict) -> tuple[np.ndarray, np.ndarray, np.ndarray, list[str]]:
    labels = payload["labels"]
    label_to_index = {label: index for index, label in enumerate(labels)}
    samples = payload["samples"]
    x = np.vstack([feature_vector(sample_to_array(sample)) for sample in samples])
    y = np.array([label_to_index[sample["label"]] for sample in samples])
    participants = np.array([sample["participant"] for sample in samples])
    return x, y, participants, labels


def metrics_dict(y_true: np.ndarray, y_pred: np.ndarray, labels: list[str]) -> dict:
    return {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "macro_f1": float(f1_score(y_true, y_pred, average="macro", zero_division=0)),
        "weighted_f1": float(f1_score(y_true, y_pred, average="weighted", zero_division=0)),
        "macro_precision": float(precision_score(y_true, y_pred, average="macro", zero_division=0)),
        "macro_recall": float(recall_score(y_true, y_pred, average="macro", zero_division=0)),
        "confusion_matrix": confusion_matrix(y_true, y_pred).tolist(),
        "classification_report": classification_report(
            y_true,
            y_pred,
            target_names=labels,
            output_dict=True,
            zero_division=0,
        ),
    }


def candidate_models() -> dict:
    return {
        "kbest200_logistic_regression": make_pipeline(
            StandardScaler(),
            SelectKBest(f_classif, k=200),
            LogisticRegression(C=0.5, max_iter=3000, class_weight="balanced", random_state=42),
        ),
        "pca_logistic_regression": make_pipeline(
            StandardScaler(),
            PCA(n_components=0.95, random_state=42),
            LogisticRegression(max_iter=3000, class_weight="balanced", random_state=42),
        ),
        "linear_svc": make_pipeline(
            StandardScaler(),
            LinearSVC(C=0.2, class_weight="balanced", max_iter=10000, dual=False),
        ),
        "rbf_svc": make_pipeline(
            StandardScaler(),
            PCA(n_components=0.95, random_state=42),
            SVC(C=3.0, gamma="scale", class_weight="balanced"),
        ),
        "ridge_classifier": make_pipeline(
            StandardScaler(),
            RidgeClassifier(class_weight="balanced"),
        ),
        "extra_trees": ExtraTreesClassifier(
            n_estimators=700,
            max_features="sqrt",
            class_weight="balanced",
            random_state=42,
            n_jobs=-1,
        ),
        "random_forest": RandomForestClassifier(
            n_estimators=700,
            max_features="sqrt",
            class_weight="balanced",
            random_state=42,
            n_jobs=-1,
        ),
    }


def evaluate_model(model, x: np.ndarray, y: np.ndarray, participants: np.ndarray, labels: list[str]) -> dict:
    train_idx, test_idx = train_test_split(
        np.arange(len(y)),
        test_size=0.2,
        random_state=42,
        stratify=y,
    )
    model.fit(x[train_idx], y[train_idx])
    random_pred = model.predict(x[test_idx])

    lopo_true = []
    lopo_pred = []
    by_participant = {}
    for participant in sorted(set(participants)):
        train_mask = participants != participant
        test_mask = participants == participant
        model.fit(x[train_mask], y[train_mask])
        pred = model.predict(x[test_mask])
        by_participant[str(participant)] = {
            "sample_count": int(test_mask.sum()),
            **metrics_dict(y[test_mask], pred, labels),
        }
        lopo_true.extend(y[test_mask])
        lopo_pred.extend(pred)

    return {
        "random_holdout": metrics_dict(y[test_idx], random_pred, labels),
        "leave_one_participant_out": {
            **metrics_dict(np.array(lopo_true), np.array(lopo_pred), labels),
            "by_participant": by_participant,
        },
    }


def main() -> None:
    payload = load_payload()
    x, y, participants, labels = build_matrix(payload)

    results = {}
    for name, model in candidate_models().items():
        print(f"training {name}")
        results[name] = evaluate_model(model, x, y, participants, labels)

    best_name = max(
        results,
        key=lambda name: results[name]["leave_one_participant_out"]["macro_f1"],
    )
    best_model = candidate_models()[best_name]
    best_model.fit(x, y)

    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    with MODEL_PATH.open("wb") as handle:
        pickle.dump(
            {
                "model": best_model,
                "model_name": best_name,
                "labels": labels,
                "channels": CHANNELS,
                "target_frames": TARGET_FRAMES,
                "sequence_frames": SEQUENCE_FRAMES,
                "training_source": payload["_source_path"].relative_to(ROOT).as_posix(),
                "training_sample_count": len(y),
                "feature_count": int(x.shape[1]),
                "generated_on": GENERATED_ON,
            },
            handle,
        )

    report = {
        "schema_version": "1.0",
        "generated_on": GENERATED_ON,
        "training_source": payload["_source_path"].relative_to(ROOT).as_posix(),
        "sample_count": len(y),
        "feature_count": int(x.shape[1]),
        "labels": labels,
        "label_counts": {label: int(count) for label, count in sorted(Counter([labels[index] for index in y]).items())},
        "participant_counts": {name: int(count) for name, count in sorted(Counter(participants).items())},
        "selected_model": best_name,
        "selection_metric": "leave_one_participant_out.macro_f1",
        "model_output": MODEL_PATH.relative_to(ROOT).as_posix(),
        "results": results,
    }

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2), encoding="utf-8")

    best = results[best_name]
    print(f"selected {best_name}")
    print(f"random accuracy {best['random_holdout']['accuracy']:.4f}")
    print(f"random macro_f1 {best['random_holdout']['macro_f1']:.4f}")
    print(f"lopo accuracy {best['leave_one_participant_out']['accuracy']:.4f}")
    print(f"lopo macro_f1 {best['leave_one_participant_out']['macro_f1']:.4f}")
    print(f"wrote {REPORT_PATH.relative_to(ROOT).as_posix()}")
    print(f"wrote {MODEL_PATH.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
