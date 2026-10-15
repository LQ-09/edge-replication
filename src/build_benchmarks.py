import numpy as np
import pandas as pd


def monthly_benchmark(frame,cfg):
    rows=[]
    for (permno,month),g in frame.groupby(['permno','month'],sort=True):
        value=np.sqrt(np.mean(g.adjusted_spread**2)) if len(g)>=cfg['min_days'] else np.nan
        rows.append(dict(permno=permno,month=month,hf_benchmark=value,n_benchmark_days=len(g)))
    return pd.DataFrame(rows,columns=['permno','month','hf_benchmark','n_benchmark_days'])
