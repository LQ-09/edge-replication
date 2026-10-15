"""Run in an authenticated WRDS Jupyter Python session, not on the local laptop.
Requires the WRDS-provided saspy package and institutional TAQ/Compustat access.
Downloads only the committed sample manifest and three intraday windows.
Copy sample_manifest.csv and config/earnings_events.csv to the cloud first.
"""
from pathlib import Path
import zipfile
import pandas as pd


def export(manifest_path='sample_manifest.csv',events_path='config/earnings_events.csv'):
    import saspy
    manifest=pd.read_csv(manifest_path,dtype=str)
    events=pd.read_csv(events_path,dtype=str)
    selected=manifest.merge(events[['event_id']],on='event_id',how='left',validate='many_to_one',indicator=True)
    if selected.empty or not selected['_merge'].eq('both').all():
        raise ValueError('Every selected day must reference a verified event')
    if selected.duplicated(['permno','date']).any():
        raise ValueError('Duplicate stock-day in manifest')
    selected['symbol']=selected.event_id.str.split('_').str[0]
    if not selected.symbol.str.fullmatch('[A-Z]{1,5}').all():
        raise ValueError('Invalid stock symbol')
    selected['day']=pd.to_datetime(selected.date,format='%Y-%m-%d').dt.strftime('%Y%m%d')
    if len(selected)>30:raise ValueError('Review scope before exporting more than 30 stock-days')
    out=Path('edge_project_exports')
    if out.exists():raise ValueError('Export folder exists; retain it and choose a new working directory')
    out.mkdir();sas=saspy.SASsession();logs=[]
    try:
        result=sas.submit("libname ect '/wrds/nyse/sasdata/taqms/ct'; libname enb '/wrds/nyse/sasdata/wrds_taqms_nbbo';")
        logs.append(result['LOG'])
        if 'ERROR:' in result['LOG']:raise RuntimeError(result['LOG'])
        for row in selected.itertuples():
            for kind,table in [('trades',f'ect.ctm_{row.day}'),('nbbo',f'enb.complete_nbbo_{row.day}')]:
                name=out/f'{kind}_{row.symbol}_{row.day}_windows.csv'
                starts=['09:30:00','12:00:00','15:30:00'] if kind=='trades' else ['09:29:55','11:59:55','15:29:55']
                window=' or '.join(f"(time_m >= '{a}'t and time_m < '{b}'t)" for a,b in zip(starts,['10:00:00','12:30:00','16:00:00']))
                code=f"data work.edge_extract; set {table}; where sym_root='{row.symbol}' and sym_suffix=' ' and ({window}); source_row=_n_; format date yymmdd10. time_m time20.9; run; proc export data=work.edge_extract outfile='{name.resolve()}' dbms=csv; run;"
                result=sas.submit(code);logs.append(result['LOG'])
                if 'ERROR:' in result['LOG']:raise RuntimeError(result['LOG'])
                print(name.name,name.stat().st_size,flush=True)
        with zipfile.ZipFile(out/'edge_event_windows.zip','x',zipfile.ZIP_DEFLATED) as z:
            for f in out.glob('*_windows.csv'):z.write(f,f.name)
    finally:
        (out/'extract.log').write_text('\n'.join(logs))
        sas.endsas()
    return out/'edge_event_windows.zip'


if __name__=='__main__':
    print(export())
