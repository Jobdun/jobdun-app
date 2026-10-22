#!/usr/bin/env python3
"""Real local Auth/Edge/Storage/PostgREST journey. No hosted URL is accepted.
Requires Pillow; private status.env/users.json created by the isolated local setup.
"""
import io
import json
import sys
import subprocess
import uuid
import urllib.error
import urllib.request
from pathlib import Path
from PIL import Image

local = Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/jobdun-staff-files-local')
env = dict(line.split('=', 1) for line in (local / 'status.env').read_text().splitlines() if '=' in line)
env = {key: value.strip('"') for key, value in env.items()}
base = env['API_URL']
assert base.startswith(('http://127.0.0.1:', 'http://localhost:')), 'Local backend required'
users = json.loads((local / 'users.json').read_text())
checks = 0


def request(path, token=None, payload=None, method=None, content_type='application/json'):
    headers = {'apikey': env['ANON_KEY']}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if payload is not None:
        headers['Content-Type'] = content_type
        if isinstance(payload, dict):
            payload = json.dumps(payload).encode()
    req = urllib.request.Request(base + path, data=payload, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return response.status, response.read(), response.headers
    except urllib.error.HTTPError as error:
        return error.code, error.read(), error.headers


def expect(condition, label):
    global checks
    assert condition, label
    checks += 1
    print('PASS', label)


def rpc(name, token, payload):
    status, body, _ = request('/rest/v1/rpc/' + name, token, payload)
    assert status == 200, (name, status, body.decode())
    return json.loads(body)


def upload(token, thread, tag, name, mime, data):
    boundary = 'attachment-' + uuid.uuid4().hex
    body = b''
    for key, value in [('threadId', thread), ('clientTag', tag)]:
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
    body += f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\nContent-Type: {mime}\r\n\r\n'.encode() + data + f'\r\n--{boundary}--\r\n'.encode()
    return request('/functions/v1/admin-chat-files', token, body, 'POST', 'multipart/form-data; boundary=' + boundary)


tokens = []
for user in users:
    status, body, _ = request('/auth/v1/token?grant_type=password', payload={'email': user['email'], 'password': user['password']})
    assert status == 200, (status, body.decode())
    tokens.append(json.loads(body)['access_token'])
expect(len(tokens) == 3, 'real Auth issues staff sessions')
thread = rpc('admin_chat_open', tokens[0], {'p_peer': users[1]['id']})
fixtures = []
for ext, mime, format_name in [('jpg', 'image/jpeg', 'JPEG'), ('png', 'image/png', 'PNG'), ('webp', 'image/webp', 'WEBP')]:
    output = io.BytesIO()
    Image.new('RGB', (24, 16), (252, 81, 1)).save(output, format=format_name)
    fixtures.append(('sample.' + ext, mime, output.getvalue()))
fixtures += [('sample.pdf', 'application/pdf', b'%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF\n'), ('sample.txt', 'text/plain', b'Fictional local staff attachment.\n')]
for name, mime, data in fixtures:
    tag = str(uuid.uuid4())
    status, body, _ = upload(tokens[0], thread, tag, name, mime, data)
    expect(status == 200, f'{mime} real multipart accepted: {status} {body[:160]!r}')
    attachment = json.loads(body)['data']
    status, retry, _ = upload(tokens[0], thread, tag, name, mime, data)
    expect(status == 200 and json.loads(retry)['data'] == attachment, mime + ' upload retry identity')
    path = '/functions/v1/admin-chat-files?id=' + attachment['id']
    expect(request(path, tokens[1])[0] in (403, 404), mime + ' pending private to owner')
    message = rpc('admin_chat_send_attachment', tokens[0], {'p_thread': thread, 'p_body': '', 'p_client_tag': tag, 'p_attachment': attachment['id']})
    repeat = rpc('admin_chat_send_attachment', tokens[0], {'p_thread': thread, 'p_body': '', 'p_client_tag': tag, 'p_attachment': attachment['id']})
    expect(message == repeat and message['attachment'] == attachment, mime + ' atomic link and message retry')
    status, downloaded, headers = request(path + '&inline=1', tokens[1])
    expect(status == 200 and downloaded == data, mime + ' participant private byte roundtrip')
    expect('no-store' in headers.get('Cache-Control', '') and headers.get('X-Content-Type-Options') == 'nosniff', mime + ' private download headers')
    expect(('inline' if mime.startswith('image/') else 'attachment') in headers.get('Content-Disposition', ''), mime + ' disposition')
    expect(request(path, tokens[2])[0] in (403, 404), mime + ' unrelated staff denied')
    expect(request(path)[0] in (401, 403), mime + ' anonymous denied')
    expect(upload(tokens[0], thread, tag, name, mime, data + b'changed')[0] >= 400, mime + ' changed retry rejected')
for name, mime, data in [('oversize.txt', 'text/plain', b'x' * (3*1024*1024+1)), ('empty.txt', 'text/plain', b''), ('spoof.png', 'image/png', b'not a png'), ('bad.html', 'text/html', b'<html>bad</html>')]:
    expect(upload(tokens[0], thread, str(uuid.uuid4()), name, mime, data)[0] >= 400, name + ' server rejection')
# The exact inclusive limit is independently exercised with a real 3 MiB upload.
limit_tag = str(uuid.uuid4())
status, body, _ = upload(tokens[0], thread, limit_tag, 'limit.txt', 'text/plain', b'x' * (3*1024*1024))
expect(status == 200 and json.loads(body)['data']['size'] == 3145728, 'exact 3 MiB accepted')
limit_attachment = json.loads(body)['data']
# Direct authenticated Storage access must remain service-only.
status, body, _ = request('/storage/v1/object/list/admin-chat-files', tokens[1], {'prefix': '', 'limit': 100})
expect(status in (400, 401, 403) or (status == 200 and json.loads(body) == []), 'direct authenticated Storage listing exposes no objects')

def local_sql(statement):
    subprocess.run(['docker', 'exec', '-e', 'PGPASSWORD=postgres', '-i', 'supabase_db_jobdun-staff-files-local', 'psql', '-X', '-U', 'supabase_admin', '-d', 'postgres', '-q', '-v', 'ON_ERROR_STOP=1'], input=statement, text=True, check=True, capture_output=True)

limit_id = limit_attachment['id']
local_sql("UPDATE public.admin_chat_attachments SET expires_at=clock_timestamp()-interval '1 minute' WHERE id='" + limit_id + "';")
expect(upload(tokens[0], thread, limit_tag, 'limit.txt', 'text/plain', b'x' * (3*1024*1024))[0] == 410, 'expired unused upload retry returns 410')
local_sql("UPDATE public.admin_chat_attachments SET expires_at=clock_timestamp()-interval '1 minute' WHERE id='" + attachment['id'] + "';")
name, mime, data = fixtures[-1]
expect(upload(tokens[0], thread, tag, name, mime, data)[0] == 200, 'finalized identical upload retry survives old expiry')

try:
    local_sql("UPDATE public.admin_platform_settings SET value='true' WHERE key='admin_mfa_required';")
    expect(request(path, tokens[1])[0] in (401, 403, 404), 'fresh access blocks aal1 when MFA required')
finally:
    local_sql("UPDATE public.admin_platform_settings SET value='false' WHERE key='admin_mfa_required';")
try:
    local_sql("UPDATE public.admin_staff SET active=false WHERE user_id='" + users[1]['id'] + "';")
    expect(request(path, tokens[1])[0] in (401, 403, 404), 'fresh access blocks revoked staff session')
    expect(request(path, tokens[0])[0] == 200, 'eligible participant retains finalized history when peer revoked')
finally:
    local_sql("UPDATE public.admin_staff SET active=true WHERE user_id='" + users[1]['id'] + "';")
(local / 'http-evidence.json').write_text(json.dumps({'checks': checks, 'endpoint': base, 'transport': 'real Auth/PostgREST/Edge/Storage', 'result': 'passed'}, indent=2))
print(f'{checks} real HTTP assertions passed')
