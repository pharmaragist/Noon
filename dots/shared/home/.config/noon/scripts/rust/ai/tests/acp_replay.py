import json, os, re, select, subprocess, sys, time

BIN = sys.argv[1]
GOLDEN = sys.argv[2]
env = dict(os.environ)
env['SESSION_DIR'] = '/home/pharmaracist/.local/state/noon/harness'
env['XDG_CONFIG_HOME'] = '/home/pharmaracist/.local/state/noon/harness/config'

p = subprocess.Popen([BIN, 'acp'], env=env, stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
lines = []
buf = b''

def pump(timeout):
    global buf
    end = time.time() + timeout
    while time.time() < end:
        r, _, _ = select.select([p.stdout], [], [], max(0, end - time.time()))
        if not r:
            break
        chunk = os.read(p.stdout.fileno(), 65536)
        if not chunk:
            break
        buf += chunk
        while b'\n' in buf:
            raw, buf = buf.split(b'\n', 1)
            if raw.strip():
                lines.append(json.loads(raw))

pump(30)
assert any(l.get('type') == 'ready' for l in lines), f'no ready: {lines}'
p.stdin.write(b'{"cmd":"list","cwd":"/home/pharmaracist"}\n')
p.stdin.flush()
deadline = time.time() + 45
while time.time() < deadline and not any(l.get('type') == 'sessions' for l in lines):
    pump(2)
p.terminate()
try:
    p.wait(timeout=5)
except subprocess.TimeoutExpired:
    p.kill()
err = p.stderr.read().decode(errors='replace')

def norm(line):
    s = json.dumps(line, sort_keys=True)
    s = re.sub(r'"updatedAt": "[^"]*"', '"updatedAt": "<TS>"', s)
    s = re.sub(r'"sessionId": "ses_[^"]*"', '"sessionId": "<SID>"', s)
    return s

actual = [norm(l) for l in lines]
golden = [norm(json.loads(l)) for l in open(GOLDEN).read().splitlines() if l.strip()]
print('events:', [l.get('type') for l in lines])
print('stderr:', repr(err[:300]))
print('golden lines:', len(golden), 'actual lines:', len(actual))
if actual == golden:
    print('ACP REPLAY: MATCH')
else:
    for i, (a, g) in enumerate(zip(actual, golden)):
        if a != g:
            print('first mismatch line', i)
            print('GOLDEN:', g[:500])
            print('ACTUAL:', a[:500])
            break
    sys.exit(1)
