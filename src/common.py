"""Validation and audit helpers shared by both private-data pipelines."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
import exchange_calendars as xcals

ROOT = Path(__file__).resolve().parents[1]
CAL = xcals.get_calendar('XNYS')


def require(frame, columns, label):
    missing = set(columns) - set(frame.columns)
    if missing:
        raise ValueError(f'{label}: missing columns {sorted(missing)}')


def verified(cfg, fields):
    if cfg.get('metadata_verified') is not True or any(not cfg.get(k) for k in fields):
        raise ValueError(f'Unverified source metadata; complete {fields} and metadata_verified')


def read(path, mapping=None):
    path = Path(path)
    if not path.is_file():
        raise ValueError(f'Missing input: {path}. Supply a licensed extract; example data are not empirical data.')
    frame = pd.read_parquet(path) if path.suffix == '.parquet' else pd.read_csv(path, dtype=str)
    if mapping:
        if any(v is None for v in mapping.values()) or len(set(mapping.values())) != len(mapping):
            raise ValueError('Column mapping must contain unique, verified source field names')
        require(frame, mapping.values(), str(path))
        frame = frame.rename(columns={v: k for k, v in mapping.items()})
    return frame


def identifiers(frame):
    frame = frame.copy()
    ids = pd.to_numeric(frame.permno, errors='coerce')
    if ids.isna().any() or (~np.isfinite(ids)).any() or (ids <= 0).any() or (ids % 1 != 0).any():
        raise ValueError('permno must be a positive integer; symbol joins must be verified upstream')
    frame['permno'] = ids.astype('int64')
    return frame


def dates(frame, column='date'):
    frame = frame.copy()
    frame[column] = pd.to_datetime(frame[column], format='%Y-%m-%d', errors='raise').dt.normalize()
    return frame


def unique(frame, keys, label):
    if frame.duplicated(keys).any():
        raise ValueError(f'{label}: duplicate {keys}; resolve source ambiguity before analysis')


def sessions(start, end):
    return CAL.sessions_in_range(pd.Timestamp(start), pd.Timestamp(end)).tz_localize(None)


def full_session(day):
    day = pd.Timestamp(day)
    if not CAL.is_session(day):
        return False
    return CAL.session_close(day) - CAL.session_open(day) == pd.Timedelta(hours=6, minutes=30)


class Audit:
    def __init__(self):
        self.counts, self.exclusions = [], []

    def keep(self, frame, mask, stage, reason):
        mask = pd.Series(mask, index=frame.index).fillna(False).astype(bool)
        dropped = frame.loc[~mask].copy()
        self.counts.append(dict(stage=stage, reason=reason, before=len(frame), after=int(mask.sum()), excluded=len(dropped)))
        if len(dropped):
            dropped['exclusion_stage'], dropped['exclusion_reason'] = stage, reason
            self.exclusions.append(dropped)
        return frame.loc[mask].copy()

    def save(self, out):
        pd.DataFrame(self.counts, columns=['stage','reason','before','after','excluded']).to_csv(out/'audit_counts.csv', index=False)
        x = pd.concat(self.exclusions, ignore_index=True) if self.exclusions else pd.DataFrame(columns=['exclusion_stage','exclusion_reason'])
        x.to_csv(out/'exclusions.csv', index=False)


def save(frame, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.suffix == '.parquet':
        frame.to_parquet(path, index=False)
    else:
        frame.to_csv(path, index=False)


def write_json(value, path):
    path.write_text(json.dumps(value, indent=2, allow_nan=False, default=str) + '\n')
