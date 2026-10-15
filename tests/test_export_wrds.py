import os,re,sys,tempfile,types,unittest,zipfile
from pathlib import Path
from unittest.mock import patch
from src.export_wrds_cloud import export

class CloudExportTests(unittest.TestCase):
    def test_bounded_export_and_session_cleanup(self):
        class FakeSAS:
            ended=False
            calls=[]
            def submit(self,code):
                self.calls.append(code)
                match=re.search("outfile='([^']+)'",code)
                if match:Path(match[1]).write_text('DATE,TIME_M\n2024-01-31,09:30:00.000000001\n')
                return {'LOG':'NOTE: complete'}
            def endsas(self):self.ended=True
        with tempfile.TemporaryDirectory() as tmp:
            old=os.getcwd();os.chdir(tmp)
            try:
                Path('sample_manifest.csv').write_text('permno,date,event_id\n10107,2024-01-31,MSFT_20240130\n')
                Path('events.csv').write_text('event_id\nMSFT_20240130\n')
                sas=FakeSAS()
                with patch.dict(sys.modules,{'saspy':types.SimpleNamespace(SASsession=lambda:sas)}):
                    archive=export(events_path='events.csv')
                    self.assertTrue(sas.ended)
                    with zipfile.ZipFile(archive) as z:self.assertEqual(len(z.namelist()),2)
                    self.assertIn("09:29:55",sas.calls[-1])
                    self.assertIn('time20.9',sas.calls[-1])
                    with self.assertRaises(ValueError):export(events_path='events.csv')
            finally:os.chdir(old)
