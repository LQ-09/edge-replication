import numpy as np
import pandas as pd
from .common import require, identifiers, dates, unique, sessions, verified
from .build_edge import estimate


def clean_crsp(frame, cfg, start, end, audit):
    verified(cfg, ['security_rule','adjustment_convention','source'])
    require(frame, ['permno','date','open','high','low','close','volume','common_stock'], 'CRSP')
    frame = dates(identifiers(frame))
    unique(frame, ['permno','date'], 'CRSP')
    frame = audit.keep(frame, frame.date.between(start, end), 'crsp', 'outside_sample')
    frame = audit.keep(frame, frame.common_stock.astype(str).str.lower().isin(['1','true']), 'crsp', 'not_common_stock')
    frame = audit.keep(frame, frame.date.isin(sessions(start,end)), 'crsp', 'not_exchange_session')
    cols = ['open','high','low','close','volume']
    frame[cols] = frame[cols].apply(pd.to_numeric, errors='coerce')
    valid = np.isfinite(frame[cols]).all(axis=1) & (frame[cols[:4]] > 0).all(axis=1) & (frame.volume >= 0)
    frame = audit.keep(frame, valid, 'crsp', 'invalid_price_or_volume')
    valid = (frame.high >= frame[['open','close']].max(axis=1)) & (frame.low <= frame[['open','close']].min(axis=1))
    frame = audit.keep(frame, valid, 'crsp', 'invalid_ohlc_bounds')
    frame = frame.sort_values(['permno','date'])
    frame['month'] = frame.date.dt.strftime('%Y-%m')
    if 'dollar_volume' in frame:
        frame['dollar_volume'] = pd.to_numeric(frame.dollar_volume, errors='raise')
        if not (np.isfinite(frame.dollar_volume) & frame.dollar_volume.ge(0)).all():
            raise ValueError('Invalid unadjusted dollar volume')
    else:
        frame['dollar_volume'] = frame.close * frame.volume
    frame['daily_range'] = (frame.high-frame.low)/frame.close
    return frame


def monthly_edge(frame, cfg):
    rows=[]
    for (permno,month), group in frame.groupby(['permno','month'], sort=True):
        period=pd.Period(month, freq='M')
        expected=sessions(period.start_time, period.end_time.normalize())
        missing=expected.difference(group.date)
        enough=len(group)>=cfg['min_days'] and len(group)/len(expected)>=cfg['min_coverage']
        # Missing daily bars would turn multi-session jumps into consecutive observations.
        if cfg['require_all_sessions'] and len(missing):
            enough=False
        value=estimate(group, cfg['min_days']) if enough else np.nan
        rows.append(dict(permno=permno, month=month, edge_spread=value, n_ohlc_days=len(group),
                         expected_sessions=len(expected), missing_sessions=len(missing),
                         missing_dates=';'.join(missing.strftime('%Y-%m-%d')),
                         edge_status='ok' if np.isfinite(value) else 'insufficient_coverage_or_undefined'))
    return pd.DataFrame(rows, columns=['permno','month','edge_spread','n_ohlc_days','expected_sessions','missing_sessions','missing_dates','edge_status'])
