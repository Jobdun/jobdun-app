#!/usr/bin/env python3
"""Check location permission declarations against the actual exported iOS IPA."""
import plistlib
import sys
import zipfile
from pathlib import Path

ipa = Path(sys.argv[1])
with zipfile.ZipFile(ipa) as archive:
    info = plistlib.loads(archive.read('Payload/Runner.app/Info.plist'))
    assert info.get('NSLocationWhenInUseUsageDescription', '').strip(), (
        'Missing foreground location purpose string'
    )
    references = []
    for entry in archive.infolist():
        if entry.is_dir() or not entry.filename.startswith('Payload/Runner.app/'):
            continue
        with archive.open(entry) as stream:
            magic = stream.read(4)
            if magic not in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
                             b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'):
                continue
            if b'requestAlwaysAuthorization\x00' in stream.read():
                references.append(entry.filename)
    if references:
        assert info.get('NSLocationAlwaysAndWhenInUseUsageDescription', '').strip(), (
            'ITMS-90683: always-location API without purpose string: '
            + ', '.join(references)
        )
    assert 'location' not in info.get('UIBackgroundModes', []), (
        'Jobdun must not enable background location updates'
    )
    print(f"PASS: {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}); "
          f'foreground location declared; always-location API references: {len(references)}')
