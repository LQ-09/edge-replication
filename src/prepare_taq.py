"""Normalize WRDS raw trades and Complete NBBO window exports without rounding time."""
import argparse
from pathlib import Path
import pandas as pd
from .common import ROOT, require, unique, Audit, write_json


def normalize(frame, kind, mapping, audit):
    require(frame,['DATE','TIME_M','SYM_ROOT','SYM_SUFFIX'],kind)
    frame=audit.keep(frame,frame.SYM_SUFFIX.fillna('').str.strip().eq(''),kind,'nonblank_suffix')
    frame=frame.rename(columns={'DATE':'date','SYM_ROOT':'symbol'})
    frame=frame.merge(mapping,on=['date','symbol'],how='left',validate='many_to_one',indicator=True)
    if not frame._merge.eq('both').all():
        raise ValueError('Unmapped TAQ symbol/date; verify the CRSP daily security headers')
    frame['timestamp']=pd.to_datetime(frame.date+' '+frame.TIME_M.str.strip(),
        format='%Y-%m-%d %H:%M:%S.%f',errors='raise').dt.tz_localize('America/New_York')
    if kind=='trades':
        columns={'TR_SEQNUM':'sequence','PRICE':'price','SIZE':'size','TR_SCOND':'condition','TR_CORR':'correction'}
    else:
        columns={'source_row':'sequence','BEST_BID':'bid','BEST_ASK':'ask',
                 'Best_BidSizeShares':'bid_size','Best_AskSizeShares':'ask_size','QU_COND':'condition'}
    require(frame,columns,kind)
    frame=frame.rename(columns=columns)
    frame['condition']=frame.condition.fillna('').str.replace(' ','',regex=False)
    if kind=='quotes':
        # Complete NBBO lacks exchange sequence numbers; never guess order of timestamp ties.
        tied=frame.duplicated(['permno','timestamp'],keep=False)
        frame.loc[tied,'condition']='AMBIGUOUS_TIMESTAMP'
        audit.keep(frame,~tied,kind,'timestamp_tie_retained_as_invalid_barrier')
    return frame[['permno','timestamp',*columns.values()]]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--directory',required=True)
    p.add_argument('--crsp',default='data/prepared/crsp.csv')
    p.add_argument('--output',default='data/prepared_taq')
    args=p.parse_args();out=(ROOT/args.output).resolve()
    if not out.is_relative_to((ROOT/'data').resolve()) or out.exists():
        raise ValueError('Choose a new output directory beneath data/')
    mapping=pd.read_csv(ROOT/args.crsp,dtype=str)[['permno','date','symbol']]
    unique(mapping,['symbol','date'],'CRSP symbol mapping')
    audit=Audit();sources={};out.mkdir(parents=True)
    from .pipeline import file_hash
    for kind,prefix in [('trades','trades'),('quotes','nbbo')]:
        files=sorted((ROOT/args.directory).glob(f'{prefix}_*_windows.csv'))
        if not files:raise ValueError(f'No {kind} files')
        frames=[]
        for f in files:
            raw=pd.read_csv(f,dtype=str)
            sources[f.name]={'rows':len(raw),'sha256':file_hash(f)}
            frames.append(normalize(raw,kind,mapping,audit))
        frame=pd.concat(frames,ignore_index=True)
        unique(frame,['permno','timestamp','sequence'],kind)
        frame.to_parquet(out/f'{kind}.parquet',index=False)
    audit.save(out);write_json(sources,out/'source_manifest.json')


if __name__=='__main__':
    main()
