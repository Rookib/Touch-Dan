#!/usr/bin/env python3
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[1]
dest=root/'TDNPrefs/Resources/Licenses'
dest.mkdir(exist_ok=True)
for name in ('LICENSE','NOTICE'):
    source=root/name
    if not source.is_file():raise SystemExit('Missing licensing file: '+name)
    shutil.copy2(source,dest/name)
licenses=list((root/'LICENSES').glob('*'))
if not licenses:raise SystemExit('Missing third-party licenses')
for source in licenses:
    if source.is_file():shutil.copy2(source,dest/source.name)
