import numpy as np
import pandas as pd
from .common import require, verified, identifiers, dates, unique, sessions


def clean_iid(frame, cfg, start, end, audit):
    verified(cfg, ['field_definition','source','identifier_mapping','units'])
    require(frame, ['permno','date','spread'], 'IID')
    scales={'decimal':1., 'percent':0.01, 'bps':0.0001}
    if cfg['units'] not in scales:
        raise ValueError('IID units must be decimal, percent, or bps')
    if cfg['winsor_scope'] != 'available_sample_by_month':
        raise ValueError('This pilot only supports explicitly disclosed sample-month winsorization')
    frame=dates(identifiers(frame))
    unique(frame,['permno','date'],'IID')
    frame=audit.keep(frame,frame.date.between(start,end),'iid','outside_sample')
    frame=audit.keep(frame,frame.date.isin(sessions(start,end)),'iid','not_exchange_session')
    frame['spread']=pd.to_numeric(frame.spread,errors='coerce') * scales[cfg['units']]
    frame=audit.keep(frame,np.isfinite(frame.spread) & (frame.spread>0),'iid','nonpositive_or_missing_spread')
    frame['month']=frame.date.dt.strftime('%Y-%m')
    frame['winsor_cap']=frame.groupby('month').spread.transform(lambda x:x.quantile(cfg['winsor_quantile'],interpolation='linear'))
    frame['adjusted_spread']=frame[['spread','winsor_cap']].min(axis=1)
    return frame.sort_values(['permno','date'])
