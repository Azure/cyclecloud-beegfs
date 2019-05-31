import jetpack.config as jpc

mounts = []
a = jpc.get('cyclecloud.mounts')

for key, value in a.iteritems():
    if not value.has_key('disabled') or not value.has_key('mdadm'):
        continue
    if value['disabled'] and value['mdadm']:
        mounts.append(key)

if mounts:
    print(" ".join(mounts))