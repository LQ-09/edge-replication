"""Validated wrapper around the unchanged author implementation."""
import warnings
import numpy as np
from vendor.python_bidask.edge import edge


def estimate(frame, min_bars=3):
    if len(frame) < max(3, min_bars):
        return np.nan
    x = frame[['open','high','low','close']].to_numpy(dtype=float)
    if not np.isfinite(x).all() or (x <= 0).any():
        raise ValueError('EDGE requires positive finite OHLC; clean and log invalid rows first')
    if (x[:,1] < x[:,[0,3]].max(axis=1)).any() or (x[:,2] > x[:,[0,3]].min(axis=1)).any():
        raise ValueError('Invalid OHLC price bounds')
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', RuntimeWarning)
        signed = edge(*x.T, sign=True)
    return max(0., signed) if np.isfinite(signed) else np.nan
